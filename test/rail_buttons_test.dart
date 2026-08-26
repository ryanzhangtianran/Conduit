import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart' as ez;
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart' as ez_tr;
import 'package:material_ui/material_ui.dart' hide GlobalMaterialLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/routing/app_router.dart';
import 'package:conduit/servers/port_forwarding_models.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/servers/ssh_connection_manager.dart';
import 'package:conduit/theme.dart';

/// Records stop requests instead of touching SSH.
class _RecordingConnectionManager extends SshConnectionManager {
  final stoppedIds = <String>[];

  @override
  Future<void> stopPortForward(String id) async => stoppedIds.add(id);
}

/// Navigation rail button state: settings icon fill on selection and
/// port-forward indicator sizing.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
    // Drift's driftDatabase() asks path_provider for a temp dir.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return Directory.systemTemp.path;
        });
    // The EasyLocalization widget's asset load never completes under
    // FakeAsync, so prime the singleton with real en-US translations.
    // Otherwise `.plural()` throws on `_locale`.
    final enMap =
        jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
            as Map<String, dynamic>;
    ez.Localization.load(
      const Locale('en', 'US'),
      translations: ez_tr.Translations(enMap),
      ignorePluralRules: false,
    );
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    SshConnectionManager? connectionManager,
    List<ActivePortForward> forwards = const [
      ActivePortForward(
        id: 'f1',
        serverId: 1,
        serverName: 'test-server',
        direction: PortForwardDirection.local,
        kind: PortForwardKind.tcp,
        bindHost: '127.0.0.1',
        bindPort: 8080,
        targetHost: 'example.com',
        targetPort: 80,
      ),
    ],
  }) async {
    final router = AppRouter();
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1200, 800);
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
            connectionManagerProvider.overrideWithValue(
              connectionManager ?? _RecordingConnectionManager(),
            ),
            portForwardsProvider.overrideWith((ref) => Stream.value(forwards)),
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
    await tester.pumpAndSettle();
  }

  Finder settingsIcon() => find.descendant(
    of: find.byTooltip('tabSettings'.tr()),
    matching: find.byType(Icon),
  );

  testWidgets('rail settings icon fills only while the settings tab is open', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(tester.widget<Icon>(settingsIcon()).fill, 0);

    await tester.tap(find.byTooltip('tabSettings'.tr()));
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(settingsIcon()).fill, 1);

    await tester.tap(find.byIcon(Symbols.dashboard));
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(settingsIcon()).fill, 0);
  });

  testWidgets('rail gear opens the settings tab directly', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('tabSettings'.tr()));
    await tester.pumpAndSettle();

    // No intermediate sheet: the gear lands straight on the settings tab.
    expect(find.byType(SheetScaffold), findsNothing);
    expect(tester.widget<Icon>(settingsIcon()).fill, 1);
  });
}
