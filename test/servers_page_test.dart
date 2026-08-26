import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_editor_dialog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  Future<void> pumpEditor(WidgetTester tester, {int? serverId}) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        useFallbackTranslations: true,
        child: ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ServerEditorDialog(serverId: serverId)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('new server hides serial connection option', (tester) async {
    await pumpEditor(tester);

    expect(find.text('serverConnectionSerial'.tr()), findsNothing);
  });

  testWidgets('a stored private key is masked, never echoed', (tester) async {
    const pem =
        '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET-MATERIAL\n'
        '-----END OPENSSH PRIVATE KEY-----\n';
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        useFallbackTranslations: true,
        child: ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ServerEditorDialog(
                serverId: 7,
                initial: const ServerDraft(
                  name: 'box',
                  host: 'example.com',
                  port: 22,
                  username: 'root',
                  credential: ServerCredential.privateKey(privateKey: pem),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('serverPrivateKeySet'.tr()), findsOneWidget);
    expect(find.textContaining('SECRET-MATERIAL'), findsNothing);
    expect(find.text('serverPrivateKeyLabel'.tr()), findsNothing);

    // Opting to paste reveals an empty field instead of the old key. The
    // credential area sits below the jump-host/proxy sections, so bring it
    // into view first.
    await tester.scrollUntilVisible(
      find.text('serverPrivateKeyPaste'.tr()),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible stops once the item is built (cache extent), which
    // can still be outside the viewport; ensureVisible finishes the job.
    await tester.ensureVisible(find.text('serverPrivateKeyPaste'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('serverPrivateKeyPaste'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('serverPrivateKeyLabel'.tr()), findsOneWidget);
    expect(find.textContaining('SECRET-MATERIAL'), findsNothing);
  });

  testWidgets('switching to key auth does not carry the password over', (
    tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        useFallbackTranslations: true,
        child: ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ServerEditorDialog(
                serverId: 8,
                initial: const ServerDraft(
                  name: 'box',
                  host: 'example.com',
                  port: 22,
                  username: 'root',
                  credential: ServerCredential.password('hunter2'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('serverAuthPrivateKey'.tr()));
    await tester.pumpAndSettle();

    // The key field is empty: no masked card, and the password is not reused
    // as key material.
    expect(find.text('serverPrivateKeySet'.tr()), findsNothing);
    expect(find.text('serverPrivateKeyLabel'.tr()), findsOneWidget);
    expect(find.textContaining('hunter2'), findsNothing);
  });

  testWidgets('title distinguishes adding from editing', (tester) async {
    await pumpEditor(tester);
    expect(find.text('serversAddSheetTitle'.tr()), findsOneWidget);

    await pumpEditor(tester, serverId: 1);
    expect(find.text('serversEditServer'.tr()), findsOneWidget);
    expect(find.text('serversAddSheetTitle'.tr()), findsNothing);
  });

  testWidgets('advanced server sections start collapsed', (tester) async {
    await pumpEditor(tester);

    for (final key in [
      'serverProxyLabel',
      'serverEnvironmentLabel',
      'serverTagsLabel',
    ]) {
      final label = find.text(key.tr());
      await tester.scrollUntilVisible(
        label,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final tile = find.ancestor(
        of: label,
        matching: find.byType(ExpansionTile),
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<ExpansionTile>(tile).initiallyExpanded, isFalse);
    }
  });
}
