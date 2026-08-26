import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/shared/presentation/licenses_dialog.dart';
import 'package:conduit/shared/services/package_info_provider.dart';
import 'settings_section.dart';

/// App name, version, description, licences and the credit line.
@RoutePage()
class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = ref.watch(packageInfoProvider).asData?.value;
    final appName = info == null || info.appName.isEmpty
        ? 'title'.tr()
        : info.appName;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) => SettingsPageBody(
        children: [
          // Fill the viewport (minus the list padding) so the credit line
          // can sit at the bottom of the page.
          SizedBox(
            height: constraints.maxHeight - 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/icons/icon_transparent.png',
                      width: 96,
                      height: 96,
                      errorBuilder: (_, _, _) =>
                          Icon(Symbols.dns, size: 64, color: scheme.primary),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (info != null)
                          Text(
                            'aboutVersionInfo'.tr(args: [info.version]),
                            style: muted,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'aboutDescription'.tr(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SettingsSection(
                  titleKey: 'aboutLegal',
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: settingsTilePadding,
                    leading: const Icon(Symbols.description),
                    title: Text('aboutOpenSourceLicenses'.tr()),
                    subtitle: Text('aboutOpenSourceLicensesHint'.tr()),
                    trailing: const Icon(Symbols.chevron_right),
                    onTap: () => showLicensesDialog(context),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'aboutCopyright'.tr(args: ['${DateTime.now().year}']),
                        style: muted,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('aboutMadeWithBefore'.tr(), style: muted),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Image.asset(
                              'assets/icons/clawd.png',
                              width: 26,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                          if ('aboutMadeWithAfter'.tr().isNotEmpty)
                            Text('aboutMadeWithAfter'.tr(), style: muted),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
