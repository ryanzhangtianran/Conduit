import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:conduit/servers/vault_create_page.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('internal creation does not show a folder picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: const ProviderScope(child: MaterialApp(home: VaultCreatePage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('vaultCreateFileAction'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('vaultChooseFolder'.tr()), findsNothing);
    expect(find.text('vaultChangeFolder'.tr()), findsNothing);
  });
}
