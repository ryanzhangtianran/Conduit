import 'package:easy_localization/easy_localization.dart';
import 'package:drift/drift.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'servers/server_providers.dart';
import 'servers/terminal_appearance_preferences.dart';
import 'shared/services/preference_store.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Each selected vault uses its own SQLite file and executor. Drift's debug
  // warning is type-based, so it cannot distinguish these independent files.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  final (terminalAppearancePreferences, preferenceStore) = await (
    TerminalAppearancePreferences.load(),
    PreferenceStore.load(),
  ).wait;

  if (DesktopWindowFrame.isPlatformDesktop) {
    await windowManager.ensureInitialized();
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
    // The red close button hides the window; sessions and forwards keep
    // running until the app is quit from the menu bar item or with ⌘Q.
    await windowManager.setPreventClose(true);
  }

  runApp(
    ProviderScope(
      overrides: [
        terminalAppearancePreferencesProvider.overrideWithValue(
          terminalAppearancePreferences,
        ),
        preferenceStoreProvider.overrideWithValue(preferenceStore),
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
