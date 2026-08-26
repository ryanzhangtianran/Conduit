import 'package:easy_localization/easy_localization.dart';
import 'package:drift/drift.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'shared/presentation/app_scaffold.dart';
import 'servers/server_providers.dart';
import 'servers/app_theme_preferences.dart';
import 'servers/metrics_refresh_preferences.dart';
import 'servers/terminal_adapter_preferences.dart';
import 'servers/startup_connection_preferences.dart';
import 'servers/transfer_conflict_preferences.dart';
import 'servers/privacy_preferences.dart';
import 'servers/ssh_key_preferences.dart';
import 'servers/local_machine_preferences.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Each selected vault uses its own SQLite file and executor. Drift's debug
  // warning is type-based, so it cannot distinguish these independent files.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  final preferences = await Future.wait([
    TerminalAdapterPreferences.load(),
    StartupConnectionPreferences.load(),
    MetricsRefreshPreferences.load(),
    AppThemePreferences.load(),
    PrivacyPreferences.load(),
    LocalMachinePreferences.load(),
    TransferConflictPreferences.load(),
    SshKeyPreferences.load(),
  ]);
  final terminalAdapterPreferences =
      preferences[0] as TerminalAdapterPreferences;
  final startupConnectionPreferences =
      preferences[1] as StartupConnectionPreferences;
  final metricsRefreshPreferences = preferences[2] as MetricsRefreshPreferences;
  final appThemePreferences = preferences[3] as AppThemePreferences;
  final privacyPreferences = preferences[4] as PrivacyPreferences;
  final localMachinePreferences = preferences[5] as LocalMachinePreferences;
  final transferConflictPreferences =
      preferences[6] as TransferConflictPreferences;
  final sshKeyPreferences = preferences[7] as SshKeyPreferences;

  await migrateLegacyVault(defaultName: 'Primary Vault');

  if (DesktopWindowFrame.isPlatformDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setOpacity(await loadConduitWindowOpacity());
    const windowOptions = WindowOptions(
      size: Size(1280, 824),
      // The desktop layout is designed for the launch size; shrinking below
      // it breaks page layouts, so the window cannot go smaller.
      minimumSize: Size(1280, 824),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        terminalAdapterPreferencesProvider.overrideWithValue(
          terminalAdapterPreferences,
        ),
        startupConnectionSettingsProvider.overrideWithValue(
          startupConnectionPreferences,
        ),
        metricsRefreshSettingsProvider.overrideWithValue(
          metricsRefreshPreferences,
        ),
        appThemeSettingsProvider.overrideWithValue(appThemePreferences),
        privacySettingsProvider.overrideWithValue(privacyPreferences),
        localMachineSettingsProvider.overrideWithValue(localMachinePreferences),
        transferConflictSettingsProvider.overrideWithValue(
          transferConflictPreferences,
        ),
        sshKeySettingsProvider.overrideWithValue(sshKeyPreferences),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        useFallbackTranslations: true,
        child: const ConduitApp(),
      ),
    ),
  );
}
