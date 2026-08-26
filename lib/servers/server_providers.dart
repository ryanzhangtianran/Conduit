import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_fonts/system_fonts.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/services/preference_store.dart';
import 'package:conduit/shared/services/update_service.dart';
import 'ghostty_terminal_session_adapter.dart';
import 'port_forward_supervisor.dart';
import 'port_forwarding_models.dart';
import 'ssh_config_sync.dart';
import 'ssh_key_preferences.dart';
import 'ssh_key_service.dart';
import 'server_connection_actions.dart' show sshAuthFailureMessage;
import 'server_repository.dart';
import 'server_metrics_refresh_scheduler.dart';
import 'ssh_connection_manager.dart';
import 'server_models.dart';
import 'terminal_session_adapter.dart';
import 'terminal_appearance_preferences.dart';
import 'terminal_color_scheme.dart';
import 'transfer_conflict_preferences.dart';
import 'vault_service.dart';
import 'vault_file_storage.dart';

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
      if (await storage.isExternalPath(path)) {
        throw FileSystemException(
          'Vaults outside the application-support directory are not supported.',
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
    vaultId: path == null ? 'conduit' : storage.vaultId(path),
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

class NavigationOrderNotifier extends PreferenceNotifier<List<int>> {
  @override
  String get key => 'workspace_tab_order';
  @override
  List<int> get defaultValue => const [0, 1, 2, 3, 4, 5];
  @override
  Object encode(List<int> value) => [for (final index in value) '$index'];

  /// Only a full permutation of the default is accepted; anything else
  /// (an older layout with fewer tabs) falls back to the default.
  @override
  List<int>? decode(Object raw) {
    if (raw is! List<String>) return null;
    final order = [for (final value in raw) int.tryParse(value) ?? -1];
    final expected = defaultValue;
    return order.length == expected.length &&
            order.toSet().containsAll(expected)
        ? order
        : null;
  }

  Future<void> move(int from, int to) {
    final order = [...state];
    order.insert(to, order.removeAt(from));
    return set(order);
  }
}

/// Startup snapshot of the terminal appearance settings; `main` overrides it
/// with the loaded preferences.
final terminalAppearancePreferencesProvider =
    Provider<TerminalAppearancePreferences>(
      (ref) => const TerminalAppearancePreferences(),
    );

/// Where generated SSH keys are stored locally and installed on servers.
/// Stored as one preference per field so older installs keep their values.
final sshKeyStorageConfigProvider =
    NotifierProvider<SshKeyStorageConfigNotifier, SshKeyStorageConfig>(
      SshKeyStorageConfigNotifier.new,
    );

class SshKeyStorageConfigNotifier extends Notifier<SshKeyStorageConfig> {
  static const _localPrivateKey = 'ssh_key_local_private_dir';
  static const _remoteAuthorizedKeysKey = 'ssh_key_remote_authorized_keys';
  static const _defaultTypeKey = 'ssh_key_default_type';
  static const _configPathKey = 'ssh_key_config_path';

  @override
  SshKeyStorageConfig build() {
    final store = ref.watch(preferenceStoreProvider);
    const defaults = SshKeyStorageConfig();
    return SshKeyStorageConfig(
      localPrivateKeyDirectory:
          store.read<String>(_localPrivateKey) ??
          defaults.localPrivateKeyDirectory,
      remoteAuthorizedKeysPath:
          store.read<String>(_remoteAuthorizedKeysKey) ??
          defaults.remoteAuthorizedKeysPath,
      defaultKeyType:
          SshKeyType.values.asNameMap()[store.read<String>(_defaultTypeKey)] ??
          defaults.defaultKeyType,
      sshConfigPath:
          store.read<String>(_configPathKey) ?? defaults.sshConfigPath,
    );
  }

  Future<void> save(SshKeyStorageConfig config) async {
    state = config;
    final store = ref.read(preferenceStoreProvider);
    await Future.wait([
      store.write(_localPrivateKey, config.localPrivateKeyDirectory),
      store.write(_remoteAuthorizedKeysKey, config.remoteAuthorizedKeysPath),
      store.write(_defaultTypeKey, config.defaultKeyType.name),
      store.write(_configPathKey, config.sshConfigPath),
    ]);
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

/// Starts saved forwards on connect and keeps the supervised ones alive. It
/// depends on the manager (never the reverse) and follows the vault's servers
/// and presets live, so it is rebuilt when the vault changes.
final portForwardSupervisorProvider = Provider<PortForwardSupervisor>((ref) {
  final repository = ref.watch(serverRepositoryProvider);
  final supervisor = PortForwardSupervisor(
    ref.watch(connectionManagerProvider),
    servers: repository.watchAll(),
    configs: repository.watchAllPortForwardConfigs(),
  );
  ref.onDispose(supervisor.dispose);
  return supervisor;
});

/// How file transfers handle a destination entry that already exists.
final transferConflictModeProvider =
    NotifierProvider<TransferConflictModeNotifier, TransferConflictMode>(
      TransferConflictModeNotifier.new,
    );

class TransferConflictModeNotifier
    extends PreferenceNotifier<TransferConflictMode> {
  @override
  String get key => 'transfer_conflict_mode';
  @override
  TransferConflictMode get defaultValue => TransferConflictMode.rename;
  @override
  Object encode(TransferConflictMode value) => value.name;
  @override
  TransferConflictMode? decode(Object raw) =>
      TransferConflictMode.values.asNameMap()[raw];
}

/// A refresh interval stored as whole seconds.
abstract class _IntervalPreferenceNotifier
    extends PreferenceNotifier<Duration> {
  @override
  Object encode(Duration value) => value.inSeconds;
  @override
  Duration? decode(Object raw) => raw is int ? Duration(seconds: raw) : null;
}

/// How often connected background servers refresh their statistics.
final serverMetricsRefreshIntervalProvider =
    NotifierProvider<ServerMetricsRefreshIntervalNotifier, Duration>(
      ServerMetricsRefreshIntervalNotifier.new,
    );

class ServerMetricsRefreshIntervalNotifier extends _IntervalPreferenceNotifier {
  @override
  String get key => 'background_metrics_refresh_interval_seconds';
  @override
  Duration get defaultValue => const Duration(seconds: 30);
}

/// How often the server shown on the Monitor page refreshes.
final focusedServerRefreshIntervalProvider =
    NotifierProvider<FocusedServerRefreshIntervalNotifier, Duration>(
      FocusedServerRefreshIntervalNotifier.new,
    );

class FocusedServerRefreshIntervalNotifier extends _IntervalPreferenceNotifier {
  @override
  String get key => 'focused_detail_refresh_interval_seconds';
  @override
  Duration get defaultValue => const Duration(seconds: 3);
}

final focusedServerIdProvider = NotifierProvider<FocusedServerNotifier, int?>(
  FocusedServerNotifier.new,
);

class FocusedServerNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void focus(int serverId) {
    if (ref.mounted) state = serverId;
  }

  /// Both transitions arrive a microtask late from the focused page's
  /// provider lifecycle, so they may land after the container is gone.
  void clear(int serverId) {
    if (ref.mounted && state == serverId) state = null;
  }
}

/// Whether saved servers connect automatically when the app starts.
final connectOnStartupProvider =
    NotifierProvider<ConnectOnStartupNotifier, bool>(
      ConnectOnStartupNotifier.new,
    );

class ConnectOnStartupNotifier extends PreferenceNotifier<bool> {
  @override
  String get key => 'connect_on_startup';
  @override
  bool get defaultValue => false;
  @override
  Object encode(bool value) => value;
  @override
  bool? decode(Object raw) => raw is bool ? raw : null;
}

/// Whether Conduit looks for a new GitHub release shortly after launch.
final autoCheckUpdatesProvider =
    NotifierProvider<AutoCheckUpdatesNotifier, bool>(
      AutoCheckUpdatesNotifier.new,
    );

class AutoCheckUpdatesNotifier extends PreferenceNotifier<bool> {
  @override
  String get key => 'autoCheckUpdates';
  @override
  bool get defaultValue => true;
  @override
  Object encode(bool value) => value;
  @override
  bool? decode(Object raw) => raw is bool ? raw : null;
}

/// What the updater knows: the last check's outcome, whether a check is
/// running, and the progress of an install in flight.
class AvailableUpdateState {
  const AvailableUpdateState({
    this.result,
    this.checking = false,
    this.installing = false,
    this.downloaded = 0,
    this.downloadTotal = 0,
    this.installError,
  });

  final UpdateCheckResult? result;
  final bool checking;
  final bool installing;
  final int downloaded;
  final int downloadTotal;
  final Object? installError;

  /// The newer release when the last check found one.
  UpdateInfo? get update => switch (result) {
    UpdateAvailable(:final update) => update,
    _ => null,
  };

  AvailableUpdateState copyWith({
    UpdateCheckResult? result,
    bool? checking,
    bool? installing,
    int? downloaded,
    int? downloadTotal,
    Object? installError,
    bool clearInstallError = false,
  }) => AvailableUpdateState(
    result: result ?? this.result,
    checking: checking ?? this.checking,
    installing: installing ?? this.installing,
    downloaded: downloaded ?? this.downloaded,
    downloadTotal: downloadTotal ?? this.downloadTotal,
    installError: clearInstallError ? null : installError ?? this.installError,
  );
}

/// The update check shared by the About page and the launch-time hook.
final availableUpdateProvider =
    NotifierProvider<AvailableUpdateNotifier, AvailableUpdateState>(
      AvailableUpdateNotifier.new,
    );

class AvailableUpdateNotifier extends Notifier<AvailableUpdateState> {
  static const lastCheckKey = 'lastUpdateCheckAt';

  /// Launch-time checks are skipped when one ran more recently than this.
  static const startupCheckInterval = Duration(hours: 6);

  var _startupCheckDone = false;

  @override
  AvailableUpdateState build() => const AvailableUpdateState();

  /// Asks GitHub for the latest release; the outcome lands in [state] and
  /// the time of the check is remembered for the launch-time throttle.
  Future<UpdateCheckResult?> check() async {
    if (state.checking) return null;
    state = state.copyWith(checking: true);
    final result = await ref.read(updateServiceProvider).check();
    await ref
        .read(preferenceStoreProvider)
        .write(lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    if (!ref.mounted) return result;
    state = state.copyWith(checking: false, result: result);
    return result;
  }

  /// The once-per-launch check: skipped when the preference is off or a
  /// check ran within [startupCheckInterval]. Returns the newer release
  /// when there is one so the caller can announce it.
  Future<UpdateInfo?> checkOnStartup() async {
    if (_startupCheckDone) return null;
    _startupCheckDone = true;
    if (!ref.read(autoCheckUpdatesProvider)) return null;
    final last = ref.read(preferenceStoreProvider).read<int>(lastCheckKey);
    if (last != null) {
      final elapsed = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(last),
      );
      if (elapsed < startupCheckInterval) return null;
    }
    return switch (await check()) {
      UpdateAvailable(:final update) => update,
      _ => null,
    };
  }

  /// Downloads [update], spawns the installer and then quits through
  /// [quit] so the installer can replace the bundle. A failed download is
  /// reported in [AvailableUpdateState.installError] and nothing quits.
  Future<void> install(
    UpdateInfo update, {
    required Future<void> Function() quit,
  }) async {
    if (state.installing) return;
    state = state.copyWith(
      installing: true,
      downloaded: 0,
      downloadTotal: update.size ?? 0,
      clearInstallError: true,
    );
    try {
      await ref
          .read(updateServiceProvider)
          .downloadAndInstall(
            update,
            onProgress: (received, total) {
              if (!ref.mounted) return;
              state = state.copyWith(
                downloaded: received,
                downloadTotal: total > 0 ? total : null,
              );
            },
          );
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(installing: false, installError: e);
      }
      return;
    }
    await quit();
  }
}

final cursorAnimationEnabledProvider =
    NotifierProvider<CursorAnimationEnabledNotifier, bool>(
      CursorAnimationEnabledNotifier.new,
    );

class CursorAnimationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(terminalAppearancePreferencesProvider).cursorAnimationEnabled;

  Future<void> setEnabled(bool enabled) async {
    await ref
        .read(terminalAppearancePreferencesProvider)
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
    ref.read(terminalAppearancePreferencesProvider).terminalFontSize,
  );

  Future<void> setFontSize(double size) async {
    final value = sanitizeTerminalFontSize(size);
    await ref
        .read(terminalAppearancePreferencesProvider)
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
    ref.read(terminalAppearancePreferencesProvider).terminalLineHeight,
  );

  Future<void> setLineHeight(double lineHeight) async {
    final value = sanitizeTerminalLineHeight(lineHeight);
    await ref
        .read(terminalAppearancePreferencesProvider)
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
      ref.read(terminalAppearancePreferencesProvider).terminalFontFamily,
    );
    unawaited(_loadFont(value));
    return value;
  }

  Future<void> setFontFamily(String family) async {
    final value = TerminalFonts.sanitize(family);
    await _loadFont(value);
    await ref
        .read(terminalAppearancePreferencesProvider)
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

/// The brightness the app renders in; the app always follows the OS setting.
final appBrightnessProvider = Provider<Brightness>(
  (ref) => ref.watch(platformBrightnessProvider),
);

final terminalLightThemeProvider =
    NotifierProvider<TerminalLightThemeNotifier, TerminalColorScheme>(
      TerminalLightThemeNotifier.new,
    );

class TerminalLightThemeNotifier extends Notifier<TerminalColorScheme> {
  @override
  TerminalColorScheme build() =>
      ref.read(terminalAppearancePreferencesProvider).lightTheme;

  Future<void> save(TerminalColorScheme theme) async {
    await ref.read(terminalAppearancePreferencesProvider).saveLightTheme(theme);
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
      ref.read(terminalAppearancePreferencesProvider).darkTheme;

  Future<void> save(TerminalColorScheme theme) async {
    await ref.read(terminalAppearancePreferencesProvider).saveDarkTheme(theme);
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

/// The Ghostty (libghostty-vt) renderer is the app's only terminal renderer.
/// Its views follow the appearance providers live, so this factory carries
/// no settings. Tests override it to substitute a fake adapter.
final terminalSessionAdapterFactoryProvider =
    Provider<TerminalSessionAdapterFactory>(
      (ref) => const GhosttyTerminalSessionAdapterFactory(),
    );

/// The app-wide SSH connection manager. It knows nothing about the
/// supervisor; interested parties subscribe to its streams instead.
final connectionManagerProvider = Provider<SshConnectionManager>((ref) {
  final manager = SshConnectionManager(
    describeAuthFailure: sshAuthFailureMessage,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final sessionsProvider = StreamProvider<List<SshSessionInfo>>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return _watchSessions(manager);
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

/// Saved port-forwarding presets across every server, oldest first.
final allPortForwardConfigsProvider = StreamProvider<List<PortForwardConfig>>((
  ref,
) {
  return ref.watch(serverRepositoryProvider).watchAllPortForwardConfigs();
});

Stream<List<SshSessionInfo>> _watchSessions(
  SshConnectionManager manager,
) async* {
  yield manager.current;
  yield* manager.sessions;
}

final serversProvider = StreamProvider<List<Server>>(
  (ref) => ref.watch(serverRepositoryProvider).watchAll(),
);

/// App-lifetime connection services, watched once by the root widget.
///
/// The refresh scheduler is created once and fed through listeners rather
/// than rebuilt on every emission, so its periodic timer survives session
/// and server changes. The same hook keeps the port-forward supervisor alive
/// and drops a deleted server's session state.
final serverMetricsRefreshSchedulerProvider =
    Provider<ServerMetricsRefreshScheduler>((ref) {
      final manager = ref.watch(connectionManagerProvider);
      final scheduler = ServerMetricsRefreshScheduler(manager);
      ref.onDispose(scheduler.dispose);
      ref.listen(portForwardSupervisorProvider, (_, _) {});

      void sync() {
        scheduler.update(
          interval: ref.read(serverMetricsRefreshIntervalProvider),
          servers: ref.read(serversProvider).asData?.value ?? const <Server>[],
          sessions:
              ref.read(sessionsProvider).asData?.value ??
              const <SshSessionInfo>[],
          focusedServerId: ref.read(focusedServerIdProvider),
        );
      }

      ref.listen(serverMetricsRefreshIntervalProvider, (_, _) => sync());
      ref.listen(focusedServerIdProvider, (_, _) => sync());
      ref.listen(sessionsProvider, (_, _) => sync());
      ref.listen(serversProvider, (previous, next) {
        // A server missing from two consecutive snapshots of the same vault
        // was deleted. Switching vaults passes through a loading state, so
        // those connections are left alone.
        final before = previous?.asData?.value;
        final after = next.asData?.value;
        if (before != null && after != null) {
          final remaining = {for (final server in after) server.id};
          for (final server in before) {
            if (!remaining.contains(server.id)) {
              unawaited(manager.forgetServer(server.id));
            }
          }
        }
        sync();
      });
      sync();
      return scheduler;
    });
