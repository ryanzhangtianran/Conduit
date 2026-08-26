import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:conduit/app_tray_controller.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/shared/formatters.dart';
import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'package:conduit/shared/presentation/licenses_dialog.dart';
import 'package:conduit/shared/services/package_info_provider.dart';
import 'package:conduit/shared/services/update_service.dart';
import 'settings_section.dart';

/// App name, version, software update, description, licences and the
/// credit line.
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
          // Fill at least the viewport (minus the list padding) so the
          // credit line sits at the bottom; grow with the content when the
          // update section needs more room.
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
            child: IntrinsicHeight(
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
                  _SoftwareUpdateSection(installedVersion: info?.version),
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
                  const SizedBox(height: 24),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
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
          ),
        ],
      ),
    );
  }
}

/// Check for updates, the outcome, install/release-notes actions for a
/// newer release, and the launch-time check switch.
class _SoftwareUpdateSection extends ConsumerWidget {
  const _SoftwareUpdateSection({required this.installedVersion});

  final String? installedVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(availableUpdateProvider);
    final notifier = ref.read(availableUpdateProvider.notifier);
    final update = state.update;
    final busy = state.checking || state.installing;
    final version = installedVersion;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return SettingsSection(
      titleKey: 'updateSectionTitle',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: settingsTilePadding,
            leading: const Icon(Symbols.update),
            title: Text(_statusText(state)),
            subtitle: version == null
                ? null
                : Text('updateInstalledVersion'.tr(args: [version])),
            trailing: state.checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : OutlinedButton(
                    onPressed: busy ? null : notifier.check,
                    child: const Text('updateCheckAction').tr(),
                  ),
          ),
          if (update != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.installing) ...[
                    LinearProgressIndicator(
                      value: state.downloadTotal > 0
                          ? state.downloaded / state.downloadTotal
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'updateDownloading'.tr(
                        args: [
                          formatBytes(state.downloaded),
                          formatBytes(
                            state.downloadTotal > 0
                                ? state.downloadTotal
                                : null,
                          ),
                        ],
                      ),
                      style: muted,
                    ),
                  ] else
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          icon: const Icon(Symbols.download),
                          onPressed: update.canInstall && !busy
                              ? () => _install(context, ref, update)
                              : null,
                          label: const Text('updateInstallAction').tr(),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: update.htmlUrl.isEmpty
                              ? null
                              : () => launchUrl(Uri.parse(update.htmlUrl)),
                          child: const Text('updateReleaseNotesAction').tr(),
                        ),
                      ],
                    ),
                  if (!update.canInstall) ...[
                    const SizedBox(height: 8),
                    Text('updateNoDownload'.tr(), style: muted),
                  ],
                  if (state.installError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'updateDownloadFailed'.tr(
                        args: ['${state.installError}'],
                      ),
                      style: muted?.copyWith(color: scheme.error),
                    ),
                  ],
                ],
              ),
            ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: settingsTilePadding,
            title: const Text('updateAutoCheck').tr(),
            subtitle: const Text('updateAutoCheckHint').tr(),
            value: ref.watch(autoCheckUpdatesProvider),
            onChanged: ref.read(autoCheckUpdatesProvider.notifier).set,
          ),
        ],
      ),
    );
  }

  static String _statusText(AvailableUpdateState state) =>
      switch (state.result) {
        null => 'updateNotChecked'.tr(),
        UpdateUpToDate() => 'updateUpToDate'.tr(),
        UpdateAvailable(:final update) => 'updateAvailable'.tr(
          args: [update.version, formatBytes(update.size)],
        ),
        UpdateCheckFailed(:final failure, :final detail) =>
          'updateCheckFailed'.tr(
            args: [
              switch (failure) {
                UpdateCheckFailure.network =>
                  detail == null || detail.isEmpty
                      ? 'updateErrorNetwork'.tr()
                      : '${'updateErrorNetwork'.tr()} ($detail)',
                UpdateCheckFailure.rateLimited => 'updateErrorRateLimited'.tr(),
                UpdateCheckFailure.badResponse =>
                  detail == null || detail.isEmpty
                      ? 'updateErrorBadResponse'.tr()
                      : '${'updateErrorBadResponse'.tr()} ($detail)',
              },
            ],
          ),
      };

  Future<void> _install(
    BuildContext context,
    WidgetRef ref,
    UpdateInfo update,
  ) async {
    final confirmed = await showConduitConfirmAlert(
      'updateInstallConfirmMessage'.tr(args: [update.version]),
      'updateInstallConfirmTitle'.tr(),
      icon: Symbols.update,
    );
    if (!confirmed || !context.mounted) return;
    await ref
        .read(availableUpdateProvider.notifier)
        .install(
          update,
          // The same shutdown as the menu bar's Quit, so sessions and
          // forwards close cleanly before the installer takes over.
          quit: () async {
            final tray = ref.read(appTrayControllerProvider);
            if (tray != null) {
              await tray.quit();
            } else {
              exit(0);
            }
          },
        );
  }
}
