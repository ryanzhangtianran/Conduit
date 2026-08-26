import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_fonts/system_fonts.dart';
import 'package:async/async.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'app_theme_preferences.dart';
import 'ghostty_terminal_session_adapter.dart';
import 'local_connection_manager.dart';
import 'local_machine_preferences.dart';
import 'port_forward_supervisor.dart';
import 'metrics_refresh_preferences.dart';
import 'port_forwarding_models.dart';
import 'privacy_preferences.dart';
import 'ssh_config_sync.dart';
import 'ssh_key_preferences.dart';
import 'ssh_key_service.dart';
import 'server_repository.dart';
import 'server_metrics_refresh_scheduler.dart';
import 'ssh_connection_manager.dart';
import 'server_models.dart';
import 'terminal_session_adapter.dart';
import 'terminal_adapter_preferences.dart';
import 'terminal_color_scheme.dart';
import 'startup_connection_preferences.dart';
import 'transfer_conflict_preferences.dart';
import 'vault_service.dart';
import 'vault_file_storage.dart';
import 'package:conduit/shared/services/secure_storage.dart';

/// The current vault's label (or file name), sanitized for use in exported
/// file names. Falls back to "vault" when no vault is active or the label is
/// empty.
String exportFileNamePrefix(WidgetRef ref) {
  final path = ref.read(activeVaultFileProvider);
  final label = path == null
      ? null
      : ref.read(vaultLabelsProvider)[path] ??
            ref.read(vaultFileStorageProvider).fileName(path);
  final sanitized = (label ?? 'vault')
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return sanitized.isEmpty ? 'vault' : sanitized;
}

/// Local timestamp for exported file names, e.g. `20260806-143000`.
String exportTimestamp() =>
    DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());

final vaultFileStorageProvider = Provider<VaultFileStorage>(
  (ref) => VaultFileStorage(),
);

final databaseProvider = Provider.autoDispose<AppDatabase>((ref) {
  final database = AppDatabase(filePath: ref.watch(activeVaultFileProvider));
  ref.onDispose(database.close);
  return database;
});

const _activeVaultFilePreference = 'active_vault_file';
const _vaultFilesPreference = 'vault_files';
const _vaultLabelsPreference = 'vault_labels';

/// Converts old path-based keychain/cloud identities to the stable identity
/// used by the current vault file.
Future<void> _relocateVaultIdentity({
  required String oldReference,
  required String currentPath,
  required VaultFileStorage storage,
}) async {
  final oldId = oldReference;
  final newId = storage.vaultId(currentPath);
  if (oldId == newId) return;
  await VaultService.relocateStoredKeys(oldVaultId: oldId, newVaultId: newId);
}

Future<List<String>> _persistentVaultPaths(
  VaultFileStorage storage,
  Iterable<String> paths,
) async {
  final result = <String>[];
  for (final path in paths) {
    final persisted = await storage.persistentPath(path);
    if (!result.contains(persisted)) result.add(persisted);
  }
  return result;
}

/// Moves the pre-multi-vault app database into a managed vault location once.
/// Platforms that support external vaults use the user-visible Documents
/// location so existing data is also available to synchronization tools;
/// restricted platforms keep the migrated vault in private application-support
/// storage.
Future<void> migrateLegacyVault({required String defaultName}) async {
  final preferences = await SharedPreferences.getInstance();
  final documents = await getApplicationDocumentsDirectory();
  final legacy = File(
    '${documents.path}${Platform.pathSeparator}maid_kit.sqlite',
  );
  if (!await legacy.exists()) return;

  final database = AppDatabase(filePath: legacy.path);
  final hasVault = await database.select(database.vaultMetadata).get();
  await database.close();
  if (hasVault.isEmpty) return;

  final storage = VaultFileStorage();
  final managedPath = await storage.moveVault(
    legacy.path,
    directoryPath: externalVaultsSupported ? documents.path : null,
    name: defaultName,
  );
  final persistedPath = await storage.persistentPath(managedPath);
  final stableId = storage.vaultId(managedPath);

  final secureStorage = appSecureStorage;
  for (final prefix in [
    'maidkit_cloud_sync',
    'maidkit_vault_data_key',
    'maidkit_vault_sync_passphrase',
  ]) {
    final oldKey = '${prefix}_${base64UrlEncode(utf8.encode('maid_kit'))}';
    final newKey = '${prefix}_${base64UrlEncode(utf8.encode(stableId))}';
    try {
      final value = await secureStorage.read(key: oldKey);
      if (value != null) {
        await secureStorage.write(key: newKey, value: value);
        await secureStorage.delete(key: oldKey);
      }
    } catch (_) {
      // Keychain migration is best-effort; the sync passphrase also lives in
      // the vault metadata and biometric unlock can be re-enabled with it.
    }
  }

  final storedFiles =
      preferences.getStringList(_vaultFilesPreference) ?? const [];
  await preferences.setStringList(_vaultFilesPreference, [
    persistedPath,
    ...storedFiles.where((path) => path != persistedPath),
  ]);
  final active = preferences.getString(_activeVaultFilePreference);
  if (active == null || active.isEmpty) {
    await preferences.setString(_activeVaultFilePreference, persistedPath);
  }
  final rawLabels = preferences.getString(_vaultLabelsPreference);
  final labels = <String, String>{};
  if (rawLabels != null) {
    try {
      final values = Map<String, dynamic>.from(jsonDecode(rawLabels) as Map);
      labels.addAll(
        values.map((key, value) => MapEntry(key, value.toString())),
      );
    } catch (_) {
      // Ignore malformed labels and fall back to a clean map.
    }
  }
  labels[persistedPath] = defaultName;
  await preferences.setString(_vaultLabelsPreference, jsonEncode(labels));

  for (final suffix in ['', '-wal', '-shm']) {
    final file = File('${legacy.path}$suffix');
    if (await file.exists()) await file.delete();
  }
}

final vaultLabelsProvider =
    NotifierProvider<VaultLabelsNotifier, Map<String, String>>(
      VaultLabelsNotifier.new,
    );

class VaultLabelsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    _restore();
    return const {};
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_vaultLabelsPreference);
    if (raw == null) return;
    try {
      final values = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final storage = ref.read(vaultFileStorageProvider);
      final restored = <String, String>{};
      for (final entry in values.entries) {
        final path = await storage.resolvePersistedPath(entry.key);
        if (path != null) restored[path] = entry.value.toString();
      }
      state = restored;
      final persisted = <String, String>{};
      for (final entry in restored.entries) {
        persisted[await storage.persistentPath(entry.key)] = entry.value;
      }
      await preferences.setString(
        _vaultLabelsPreference,
        jsonEncode(persisted),
      );
    } catch (_) {
      await preferences.remove(_vaultLabelsPreference);
    }
  }

  Future<void> _persist() async {
    final storage = ref.read(vaultFileStorageProvider);
    final persisted = <String, String>{};
    for (final entry in state.entries) {
      persisted[await storage.persistentPath(entry.key)] = entry.value;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_vaultLabelsPreference, jsonEncode(persisted));
  }

  Future<void> rename(String vaultId, String name) async {
    final normalized = name.trim();
    final updated = {...state};
    if (normalized.isEmpty) {
      updated.remove(vaultId);
    } else {
      updated[vaultId] = normalized;
    }
    state = updated;
    await _persist();
  }

  Future<void> remove(String vaultId) async {
    state = {...state}..remove(vaultId);
    await _persist();
  }
}

/// The database file backing the currently selected vault. A null value keeps
/// using the original Conduit database so existing users migrate seamlessly.
final activeVaultFileProvider =
    NotifierProvider<ActiveVaultFileNotifier, String?>(
      ActiveVaultFileNotifier.new,
    );

class ActiveVaultFileNotifier extends Notifier<String?> {
  @override
  String? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final reference = preferences.getString(_activeVaultFilePreference);
    if (reference == null || reference.isEmpty) return;

    final storage = ref.read(vaultFileStorageProvider);
    final path = await storage.resolvePersistedPath(reference);
    if (path == null) {
      await preferences.remove(_activeVaultFilePreference);
      return;
    }
    await _relocateVaultIdentity(
      oldReference: reference,
      currentPath: path,
      storage: storage,
    );
    await ref.read(vaultFilesProvider.notifier).remember(path);
    state = path;
    await preferences.setString(
      _activeVaultFilePreference,
      await storage.persistentPath(path),
    );
  }

  Future<void> select(String? path) async {
    if (path != null) {
      final storage = ref.read(vaultFileStorageProvider);
      if (!externalVaultsSupported && await storage.isExternalPath(path)) {
        throw FileSystemException(
          'External managed vaults are not supported on this platform.',
          path,
        );
      }
      await ref.read(vaultFilesProvider.notifier).remember(path);
    }
    state = path;
    final preferences = await SharedPreferences.getInstance();
    if (path == null) {
      await preferences.remove(_activeVaultFilePreference);
    } else {
      final storage = ref.read(vaultFileStorageProvider);
      await preferences.setString(
        _activeVaultFilePreference,
        await storage.persistentPath(path),
      );
    }
  }
}

/// Vault database files known to Conduit. The original app database is a
/// separate built-in option and is therefore not included in this list.
final vaultFilesProvider = NotifierProvider<VaultFilesNotifier, List<String>>(
  VaultFilesNotifier.new,
);
final vaultExternalPathProvider = FutureProvider.family<bool, String>((
  ref,
  path,
) {
  return ref.read(vaultFileStorageProvider).isExternalPath(path);
});

class VaultFilesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _restore();
    return const [];
  }

  Future<void> _persist() async {
    final storage = ref.read(vaultFileStorageProvider);
    final persisted = await _persistentVaultPaths(storage, state);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_vaultFilesPreference, persisted);
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_vaultFilesPreference) ?? const [];
    final managedPaths = <String>[];
    final storage = ref.read(vaultFileStorageProvider);
    for (final reference in stored) {
      final path = await storage.resolvePersistedPath(reference);
      if (path != null && !managedPaths.contains(path)) {
        await _relocateVaultIdentity(
          oldReference: reference,
          currentPath: path,
          storage: storage,
        );
        managedPaths.add(path);
      }
    }
    for (final path in await storage.managedVaultPaths()) {
      if (!managedPaths.contains(path)) managedPaths.add(path);
    }
    state = [
      ...managedPaths,
      ...state.where((path) => !managedPaths.contains(path)),
    ];
    await _persist();
  }

  Future<void> remember(String path) async {
    state = [path, ...state.where((value) => value != path)];
    await _persist();
  }

  Future<void> forget(String path) async {
    state = state.where((value) => value != path).toList();
    await _persist();
  }
}

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(
    ref.watch(databaseProvider),
    ref.watch(vaultServiceProvider),
  );
});

final vaultServiceProvider = Provider<VaultService>((ref) {
  final path = ref.watch(activeVaultFileProvider);
  final storage = ref.read(vaultFileStorageProvider);
  return VaultService(
    ref.watch(databaseProvider),
    vaultId: path == null ? 'maid_kit' : storage.vaultId(path),
  );
});

final vaultOpenTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

final vaultExistsProvider = FutureProvider<bool>((ref) {
  return ref
      .watch(vaultServiceProvider)
      .hasVault()
      .timeout(ref.watch(vaultOpenTimeoutProvider));
}, retry: (_, _) => null);

final biometricUnlockEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(vaultServiceProvider).isBiometricUnlockEnabled();
});

/// Display order of the six main workspace tabs, as route indexes 0-5.
/// The user rearranges the navigation rail by dragging; settings stays put.
final navigationOrderProvider =
    NotifierProvider<NavigationOrderNotifier, List<int>>(
      NavigationOrderNotifier.new,
    );

class NavigationOrderNotifier extends Notifier<List<int>> {
  static const _preferenceKey = 'workspace_tab_order';
  static const _defaultOrder = [0, 1, 2, 3, 4, 5];

  @override
  List<int> build() {
    _restore();
    return _defaultOrder;
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_preferenceKey);
    if (stored == null) return;
    final order = [for (final value in stored) int.tryParse(value) ?? -1];
    // Only accept a full permutation; anything else keeps the default.
    if (order.length == _defaultOrder.length &&
        order.toSet().containsAll(_defaultOrder)) {
      state = order;
    }
  }

  Future<void> move(int from, int to) async {
    final order = [...state];
    order.insert(to, order.removeAt(from));
    state = order;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_preferenceKey, [
      for (final index in order) '$index',
    ]);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  // The appearance settings page was removed; the app follows the system.
  @override
  ThemeMode build() => ThemeMode.system;
}

final appThemeSettingsProvider = Provider<AppThemeSettings>(
  (ref) => InMemoryAppThemeSettings(),
);

final appSeedColorProvider = NotifierProvider<AppSeedColorNotifier, Color>(
  AppSeedColorNotifier.new,
);

class AppSeedColorNotifier extends Notifier<Color> {
  @override
  Color build() => ref.read(appThemeSettingsProvider).seedColor;

  Future<void> setSeedColor(Color color) async {
    await ref.read(appThemeSettingsProvider).saveSeedColor(color);
    state = color;
  }
}

final terminalAdapterPreferencesProvider = Provider<TerminalAdapterSettings>(
  (ref) => InMemoryTerminalAdapterSettings(),
);

final startupConnectionSettingsProvider = Provider<StartupConnectionSettings>(
  (ref) => InMemoryStartupConnectionSettings(),
);

final metricsRefreshSettingsProvider = Provider<MetricsRefreshSettings>(
  (ref) => InMemoryMetricsRefreshSettings(),
);

final sshKeySettingsProvider = Provider<SshKeySettings>(
  (ref) => InMemorySshKeySettings(),
);

/// Where generated SSH keys are stored locally and installed on servers.
final sshKeyStorageConfigProvider =
    NotifierProvider<SshKeyStorageConfigNotifier, SshKeyStorageConfig>(
      SshKeyStorageConfigNotifier.new,
    );

class SshKeyStorageConfigNotifier extends Notifier<SshKeyStorageConfig> {
  @override
  SshKeyStorageConfig build() => ref.read(sshKeySettingsProvider).config;

  Future<void> save(SshKeyStorageConfig config) async {
    await ref.read(sshKeySettingsProvider).saveConfig(config);
    state = config;
  }
}

final sshKeyServiceProvider = Provider<SshKeyService>(
  (ref) => const SshKeyService(),
);

/// Host entries parsed from the local OpenSSH client config. Invalidate after
/// writing to the file so the list reloads.
final sshConfigHostsProvider = FutureProvider.autoDispose<List<SshConfigHost>>((
  ref,
) {
  final config = ref.watch(sshKeyStorageConfigProvider);
  return readSshConfigHosts(configPath: config.sshConfigPath);
});

final privacySettingsProvider = Provider<PrivacySettings>(
  (ref) => InMemoryPrivacySettings(),
);

final hideServerAddressesProvider =
    NotifierProvider<HideServerAddressesNotifier, bool>(
      HideServerAddressesNotifier.new,
    );

class HideServerAddressesNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(privacySettingsProvider).hideServerAddresses;

  Future<void> setEnabled(bool value) async {
    await ref.read(privacySettingsProvider).saveHideServerAddresses(value);
    state = value;
  }
}

/// Starts saved forwards on connect and keeps the supervised ones alive.
final portForwardSupervisorProvider = Provider<PortForwardSupervisor>(
  (ref) => ref.watch(_connectionStackProvider).supervisor,
);

final localMachineSettingsProvider = Provider<LocalMachineSettings>(
  (ref) => InMemoryLocalMachineSettings(),
);

final localMachineEnabledProvider =
    NotifierProvider<LocalMachineEnabledNotifier, bool>(
      LocalMachineEnabledNotifier.new,
    );

class LocalMachineEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(localMachineSettingsProvider).localMachineEnabled;

  Future<void> setEnabled(bool value) async {
    await ref.read(localMachineSettingsProvider).saveLocalMachineEnabled(value);
    state = value;
    // Collect stats as soon as the toggle turns on rather than waiting for
    // the next scheduled tick (up to the background refresh interval).
    if (value && localMachineSupported) {
      unawaited(ref.read(localConnectionManagerProvider).refreshNow());
    }
  }
}

final transferConflictSettingsProvider = Provider<TransferConflictSettings>(
  (ref) => InMemoryTransferConflictSettings(),
);

final transferConflictModeProvider =
    NotifierProvider<TransferConflictModeNotifier, TransferConflictMode>(
      TransferConflictModeNotifier.new,
    );

class TransferConflictModeNotifier extends Notifier<TransferConflictMode> {
  @override
  TransferConflictMode build() =>
      ref.read(transferConflictSettingsProvider).conflictMode;

  Future<void> setMode(TransferConflictMode value) async {
    await ref.read(transferConflictSettingsProvider).saveConflictMode(value);
    state = value;
  }
}

final serverMetricsRefreshIntervalProvider =
    NotifierProvider<ServerMetricsRefreshIntervalNotifier, Duration>(
      ServerMetricsRefreshIntervalNotifier.new,
    );

class ServerMetricsRefreshIntervalNotifier extends Notifier<Duration> {
  @override
  Duration build() =>
      ref.read(metricsRefreshSettingsProvider).backgroundInterval;

  Future<void> setInterval(Duration value) async {
    await ref
        .read(metricsRefreshSettingsProvider)
        .saveBackgroundInterval(value);
    state = value;
  }
}

final focusedServerRefreshIntervalProvider =
    NotifierProvider<FocusedServerRefreshIntervalNotifier, Duration>(
      FocusedServerRefreshIntervalNotifier.new,
    );

class FocusedServerRefreshIntervalNotifier extends Notifier<Duration> {
  @override
  Duration build() => ref.read(metricsRefreshSettingsProvider).focusedInterval;

  Future<void> setInterval(Duration value) async {
    await ref.read(metricsRefreshSettingsProvider).saveFocusedInterval(value);
    state = value;
  }
}

final focusedServerIdProvider = NotifierProvider<FocusedServerNotifier, int?>(
  FocusedServerNotifier.new,
);

class FocusedServerNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void focus(int serverId) => state = serverId;

  void clear(int serverId) {
    if (state == serverId) state = null;
  }
}

final connectOnStartupProvider =
    NotifierProvider<ConnectOnStartupNotifier, bool>(
      ConnectOnStartupNotifier.new,
    );

class ConnectOnStartupNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(startupConnectionSettingsProvider).connectOnStartup;

  Future<void> setEnabled(bool value) async {
    await ref
        .read(startupConnectionSettingsProvider)
        .saveConnectOnStartup(value);
    state = value;
  }
}

final cursorAnimationEnabledProvider =
    NotifierProvider<CursorAnimationEnabledNotifier, bool>(
      CursorAnimationEnabledNotifier.new,
    );

class CursorAnimationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(terminalAdapterPreferencesProvider).cursorAnimationEnabled;

  Future<void> setEnabled(bool enabled) async {
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveCursorAnimationEnabled(enabled);
    state = enabled;
  }
}

final terminalFontSizeProvider =
    NotifierProvider<TerminalFontSizeNotifier, double>(
      TerminalFontSizeNotifier.new,
    );

class TerminalFontSizeNotifier extends Notifier<double> {
  @override
  double build() => sanitizeTerminalFontSize(
    ref.read(terminalAdapterPreferencesProvider).terminalFontSize,
  );

  Future<void> setFontSize(double size) async {
    final value = sanitizeTerminalFontSize(size);
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveTerminalFontSize(value);
    state = value;
  }
}

final terminalLineHeightProvider =
    NotifierProvider<TerminalLineHeightNotifier, double>(
      TerminalLineHeightNotifier.new,
    );

class TerminalLineHeightNotifier extends Notifier<double> {
  @override
  double build() => sanitizeTerminalLineHeight(
    ref.read(terminalAdapterPreferencesProvider).terminalLineHeight,
  );

  Future<void> setLineHeight(double lineHeight) async {
    final value = sanitizeTerminalLineHeight(lineHeight);
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveTerminalLineHeight(value);
    state = value;
  }
}

final terminalFontFamilyProvider =
    NotifierProvider<TerminalFontFamilyNotifier, String>(
      TerminalFontFamilyNotifier.new,
    );

class TerminalFontFamilyNotifier extends Notifier<String> {
  @override
  String build() {
    final value = TerminalFonts.sanitize(
      ref.read(terminalAdapterPreferencesProvider).terminalFontFamily,
    );
    unawaited(_loadFont(value));
    return value;
  }

  Future<void> setFontFamily(String family) async {
    final value = TerminalFonts.sanitize(family);
    await _loadFont(value);
    await ref
        .read(terminalAdapterPreferencesProvider)
        .saveTerminalFontFamily(value);
    state = value;
  }

  Future<void> _loadFont(String family) async {
    try {
      await SystemFonts().loadFont(family);
    } on Object {
      // Font not available on this system; rendering falls back.
    }
  }
}

final availableTerminalFontsProvider = FutureProvider<List<TerminalFontOption>>(
  (ref) async {
    final options = TerminalFonts.dedupe(SystemFonts().getFontList());
    final defaultOption = TerminalFontOption(
      label: TerminalFonts.defaultFamily,
      family: TerminalFonts.defaultFamily,
    );
    if (!options.any(
      (option) => option.family == TerminalFonts.defaultFamily,
    )) {
      options.insert(0, defaultOption);
    }
    final persisted = ref.read(terminalFontFamilyProvider);
    if (!options.any((option) => option.family == persisted)) {
      options.insert(
        0,
        TerminalFontOption(label: persisted, family: persisted),
      );
    }
    return List.unmodifiable(options);
  },
);

final monospaceTerminalFontsOnlyProvider =
    NotifierProvider<MonospaceTerminalFontsOnlyNotifier, bool>(
      MonospaceTerminalFontsOnlyNotifier.new,
    );

class MonospaceTerminalFontsOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setEnabled(bool enabled) => state = enabled;
}

final platformBrightnessProvider =
    NotifierProvider<PlatformBrightnessNotifier, Brightness>(
      PlatformBrightnessNotifier.new,
    );

class PlatformBrightnessNotifier extends Notifier<Brightness> {
  @override
  Brightness build() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    dispatcher.onPlatformBrightnessChanged = () {
      state = dispatcher.platformBrightness;
    };
    ref.onDispose(() => dispatcher.onPlatformBrightnessChanged = null);
    return dispatcher.platformBrightness;
  }
}

/// The brightness the app actually renders in, honoring the theme mode and
/// falling back to the OS setting for `ThemeMode.system`.
final appBrightnessProvider = Provider<Brightness>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == ThemeMode.light) return Brightness.light;
  if (mode == ThemeMode.dark) return Brightness.dark;
  return ref.watch(platformBrightnessProvider);
});

final terminalLightThemeProvider =
    NotifierProvider<TerminalLightThemeNotifier, TerminalColorScheme>(
      TerminalLightThemeNotifier.new,
    );

class TerminalLightThemeNotifier extends Notifier<TerminalColorScheme> {
  @override
  TerminalColorScheme build() =>
      ref.read(terminalAdapterPreferencesProvider).lightTheme;

  Future<void> save(TerminalColorScheme theme) async {
    await ref.read(terminalAdapterPreferencesProvider).saveLightTheme(theme);
    state = theme;
  }
}

final terminalDarkThemeProvider =
    NotifierProvider<TerminalDarkThemeNotifier, TerminalColorScheme>(
      TerminalDarkThemeNotifier.new,
    );

class TerminalDarkThemeNotifier extends Notifier<TerminalColorScheme> {
  @override
  TerminalColorScheme build() =>
      ref.read(terminalAdapterPreferencesProvider).darkTheme;

  Future<void> save(TerminalColorScheme theme) async {
    await ref.read(terminalAdapterPreferencesProvider).saveDarkTheme(theme);
    state = theme;
  }
}

/// The terminal palette that matches the current app brightness.
final terminalColorSchemeProvider = Provider<TerminalColorScheme>((ref) {
  final brightness = ref.watch(appBrightnessProvider);
  return brightness == Brightness.light
      ? ref.watch(terminalLightThemeProvider)
      : ref.watch(terminalDarkThemeProvider);
});

/// The Ghostty (libghostty-vt) renderer is the app's only terminal renderer;
/// new terminals pick up the current appearance settings at creation.
final terminalSessionAdapterFactoryProvider =
    Provider<TerminalSessionAdapterFactory>((ref) {
      return GhosttyTerminalSessionAdapterFactory(
        cursorAnimationEnabled: ref.watch(cursorAnimationEnabledProvider),
        colorScheme: ref.watch(terminalColorSchemeProvider),
        transparentBackground: ref.watch(transparentTerminalBackgroundProvider),
        fontFamily: ref.watch(terminalFontFamilyProvider),
        fontSize: ref.watch(terminalFontSizeProvider),
        lineHeight: ref.watch(terminalLineHeightProvider),
      );
    });

/// Builds the manager and its port-forward supervisor together: the connect
/// hook references the supervisor instance directly, because wiring the two
/// through each other's providers is a circular dependency Riverpod rejects.
final _connectionStackProvider =
    Provider<
      ({SshConnectionManager manager, PortForwardSupervisor supervisor})
    >((ref) {
      late final PortForwardSupervisor supervisor;
      final manager = SshConnectionManager(
        () => ref.read(terminalSessionAdapterFactoryProvider),
        onConnected: (server) => unawaited(supervisor.onConnected(server)),
      );
      supervisor = PortForwardSupervisor(
        manager,
        (serverId) => ref
            .read(serverRepositoryProvider)
            .portForwardConfigsForServer(serverId),
      );
      ref.onDispose(supervisor.dispose);
      ref.onDispose(manager.dispose);
      return (manager: manager, supervisor: supervisor);
    });

final connectionManagerProvider = Provider<SshConnectionManager>(
  (ref) => ref.watch(_connectionStackProvider).manager,
);

/// The virtual "this computer" server shown on the dashboard when local
/// machine management is enabled. It is deliberately not persisted: it has no
/// credentials, must not leak into cloud sync, and can never collide with a
/// stored row (its id is 0).
final localMachineServerProvider = Provider<Server>((ref) {
  String hostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'localhost';
    }
  }

  return Server(
    id: localMachineServerId,
    name: hostname(),
    host: '127.0.0.1',
    port: 22,
    username: Platform.environment['USER'] ?? '',
    collectStats: true,
    collectSystemInfo: true,
    connectionType: ServerConnectionType.local.name,
  );
});

final localConnectionManagerProvider = Provider<LocalConnectionManager>((ref) {
  final manager = LocalConnectionManager(
    () => ref.read(terminalSessionAdapterFactoryProvider),
    isEnabled: () =>
        localMachineSupported && ref.read(localMachineEnabledProvider),
    interval: () => ref.read(serverMetricsRefreshIntervalProvider),
    serverName: () => ref.read(localMachineServerProvider).name,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final sessionsProvider = StreamProvider<List<SshSessionInfo>>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  final local = ref.watch(localConnectionManagerProvider);
  return _watchSessions(manager, local);
});

final portForwardsProvider = StreamProvider<List<ActivePortForward>>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return _watchPortForwards(manager);
});

Stream<List<ActivePortForward>> _watchPortForwards(
  SshConnectionManager manager,
) async* {
  yield manager.currentPortForwards;
  yield* manager.portForwards;
}

/// Once-a-second traffic readings for active forwards, keyed by forward id.
/// Only ticks while the port forwarding page is watching it.
final portForwardMetricsProvider =
    StreamProvider.autoDispose<Map<String, PortForwardMetrics>>((ref) async* {
      final manager = ref.watch(connectionManagerProvider);
      yield manager.portForwardMetrics();
      yield* Stream.periodic(
        const Duration(seconds: 1),
        (_) => manager.portForwardMetrics(),
      );
    });

/// The server currently shown on the Monitor page. Falls back to the first
/// server when unset or when the selection was deleted.
final monitorSelectedServerIdProvider =
    NotifierProvider<MonitorSelectedServerNotifier, int?>(
      MonitorSelectedServerNotifier.new,
    );

class MonitorSelectedServerNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int serverId) => state = serverId;
}

/// Saved port-forwarding presets for one server, oldest first.
final portForwardConfigsProvider =
    StreamProvider.family<List<PortForwardConfig>, int>((ref, serverId) {
      return ref
          .watch(serverRepositoryProvider)
          .watchPortForwardConfigs(serverId);
    });

/// Saved port-forwarding presets across every server, oldest first.
final allPortForwardConfigsProvider = StreamProvider<List<PortForwardConfig>>((
  ref,
) {
  return ref.watch(serverRepositoryProvider).watchAllPortForwardConfigs();
});

Stream<List<SshSessionInfo>> _watchSessions(
  SshConnectionManager manager,
  LocalConnectionManager local,
) async* {
  yield [...manager.current, ...local.current];
  yield* StreamGroup.merge([manager.sessions, local.sessions]);
}

final serversProvider = StreamProvider<List<Server>>((ref) {
  final stored = ref.watch(serverRepositoryProvider).watchAll();
  if (!localMachineSupported) return stored;
  if (!ref.watch(localMachineEnabledProvider)) return stored;
  final local = ref.watch(localMachineServerProvider);
  return stored.map((servers) => [local, ...servers]);
});

final serverMetricsRefreshSchedulerProvider =
    Provider<ServerMetricsRefreshScheduler>((ref) {
      final scheduler = ServerMetricsRefreshScheduler(
        ref.watch(connectionManagerProvider),
      );
      final interval = ref.watch(serverMetricsRefreshIntervalProvider);
      final focusedServerId = ref.watch(focusedServerIdProvider);
      final servers =
          ref.watch(serversProvider).asData?.value ?? const <Server>[];
      final sessions =
          ref.watch(sessionsProvider).asData?.value ?? const <SshSessionInfo>[];
      scheduler.update(
        interval: interval,
        servers: servers,
        sessions: sessions,
        focusedServerId: focusedServerId,
      );
      ref.onDispose(scheduler.dispose);
      return scheduler;
    });
