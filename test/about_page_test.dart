import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:conduit/servers/about_page.dart';
import 'package:conduit/shared/services/package_info_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  Future<void> pumpAboutPage(WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        useFallbackTranslations: true,
        child: ProviderScope(
          overrides: [
            packageInfoProvider.overrideWith(
              (ref) => Future.value(
                PackageInfo(
                  appName: 'Conduit',
                  packageName: 'dev.solsynth.maidkit',
                  version: '1.0.0',
                  buildNumber: '3',
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: AboutPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows app info without the removed ad section', (tester) async {
    await pumpAboutPage(tester);

    expect(find.text('aboutAppInfo'.tr()), findsOneWidget);
    expect(find.text('aboutOtherWorks'.tr()), findsNothing);
  });
}
