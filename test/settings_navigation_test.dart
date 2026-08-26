import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart' hide GlobalMaterialLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/routing/app_router.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/theme.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    bool settle = true,
  }) async {
    final router = AppRouter();
    addTearDown(router.dispose);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ProviderScope(
          overrides: [
            serversProvider.overrideWith((ref) => Stream.value(<Server>[])),
            biometricUnlockEnabledProvider.overrideWith(
              (ref) => Future.value(false),
            ),
            // The real provider reads ~/.ssh/config; file IO never completes
            // under the test's fake async clock.
            sshConfigHostsProvider.overrideWith(
              (ref) => Future.value(const []),
            ),
          ],
          child: MaterialApp.router(
            theme: createConduitTheme(Brightness.light),
            locale: const Locale('en', 'US'),
            supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router.config(),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('opens Settings from the desktop navigation rail', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('tabSettings'.tr()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('settingsTerminal'.tr()).first);
    await tester.pumpAndSettle();
    expect(find.text('settingsTerminalFontSize'.tr()), findsOneWidget);

    await tester.tap(find.text('settingsAbout'.tr()).first);
    await tester.pumpAndSettle();
    expect(find.text('settingsAbout'.tr()), findsWidgets);
  });

  testWidgets('uses category tabs on mobile settings', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(390, 844));

    await tester.tap(find.byIcon(Symbols.settings).last);
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    final terminalTab = find.text('settingsTerminal'.tr()).first;
    await tester.ensureVisible(terminalTab);
    await tester.tap(terminalTab);
    await tester.pumpAndSettle();
    expect(find.text('settingsTerminalFontSize'.tr()), findsOneWidget);
  });

  testWidgets('opens Connections from the navigation rail', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // The rail is a custom reorderable list; tap its dns destination.
    await tester.tap(find.byIcon(Symbols.dns).first);
    await tester.pumpAndSettle();
    expect(find.text('assetsConnectionsDescription'.tr()), findsOneWidget);
  });
}
