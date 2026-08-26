import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/shared/presentation/conduit_dropdown.dart';
import '../server_providers.dart';
import '../ssh_key_preferences.dart';
import '../transfer_conflict_preferences.dart';
import 'settings_section.dart';

const _refreshIntervals = [
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
];

const _focusedRefreshIntervals = [
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

/// Startup connection, refresh intervals, transfer conflicts and SSH key
/// storage.
@RoutePage()
class ConnectionsSettingsPage extends ConsumerWidget {
  const ConnectionsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsPageBody(
      children: [
        SettingsSection(
          titleKey: 'settingsConnections',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: settingsTilePadding,
                title: const Text('settingsConnectOnStartup').tr(),
                value: ref.watch(connectOnStartupProvider),
                onChanged: ref.read(connectOnStartupProvider.notifier).set,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    _IntervalDropdown(
                      labelKey: 'settingsBackgroundRefreshInterval',
                      value: ref.watch(serverMetricsRefreshIntervalProvider),
                      options: _refreshIntervals,
                      fallback: _refreshIntervals[1],
                      onChanged: ref
                          .read(serverMetricsRefreshIntervalProvider.notifier)
                          .set,
                    ),
                    const SizedBox(height: 16),
                    _IntervalDropdown(
                      labelKey: 'settingsFocusedRefreshInterval',
                      value: ref.watch(focusedServerRefreshIntervalProvider),
                      options: _focusedRefreshIntervals,
                      fallback: _focusedRefreshIntervals.first,
                      onChanged: ref
                          .read(focusedServerRefreshIntervalProvider.notifier)
                          .set,
                    ),
                    const SizedBox(height: 16),
                    _TransferConflictDropdown(
                      value: ref.watch(transferConflictModeProvider),
                      onChanged: ref
                          .read(transferConflictModeProvider.notifier)
                          .set,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSection(
          titleKey: 'settingsSshKeys',
          child: _SshKeySettingsSection(),
        ),
      ],
    );
  }
}

class _IntervalDropdown extends StatelessWidget {
  const _IntervalDropdown({
    required this.labelKey,
    required this.value,
    required this.options,
    required this.fallback,
    required this.onChanged,
  });

  final String labelKey;
  final Duration value;
  final List<Duration> options;
  final Duration fallback;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) => ConduitDropdown<Duration>(
    value: options.contains(value) ? value : fallback,
    label: labelKey.tr(),
    entries: [
      for (final interval in options)
        DropdownMenuEntry(value: interval, label: _formatInterval(interval)),
    ],
    onChanged: (interval) {
      if (interval != null) onChanged(interval);
    },
  );

  static String _formatInterval(Duration interval) {
    if (interval.inMinutes >= 1) {
      return 'settingsIntervalMinutes'.tr(args: ['${interval.inMinutes}']);
    }
    return 'settingsIntervalSeconds'.tr(args: ['${interval.inSeconds}']);
  }
}

class _TransferConflictDropdown extends StatelessWidget {
  const _TransferConflictDropdown({
    required this.value,
    required this.onChanged,
  });

  final TransferConflictMode value;
  final ValueChanged<TransferConflictMode> onChanged;

  @override
  Widget build(BuildContext context) => ConduitDropdown<TransferConflictMode>(
    value: value,
    label: 'settingsTransferConflictMode'.tr(),
    entries: [
      for (final mode in TransferConflictMode.values)
        DropdownMenuEntry(
          value: mode,
          label: switch (mode) {
            TransferConflictMode.rename =>
              'settingsTransferConflictRename'.tr(),
            TransferConflictMode.overwrite =>
              'settingsTransferConflictOverwrite'.tr(),
            TransferConflictMode.ask => 'settingsTransferConflictAsk'.tr(),
          },
        ),
    ],
    onChanged: (mode) {
      if (mode != null) onChanged(mode);
    },
  );
}

/// Where generated SSH keys live locally and on servers. Each field saves as
/// it is edited; blank fields fall back to the defaults at use time.
class _SshKeySettingsSection extends ConsumerStatefulWidget {
  const _SshKeySettingsSection();

  @override
  ConsumerState<_SshKeySettingsSection> createState() =>
      _SshKeySettingsSectionState();
}

class _SshKeySettingsSectionState
    extends ConsumerState<_SshKeySettingsSection> {
  late final SshKeyStorageConfig _initial = ref.read(
    sshKeyStorageConfigProvider,
  );
  late final _localPrivate = TextEditingController(
    text: _initial.localPrivateKeyDirectory,
  );
  late final _remoteAuthorizedKeys = TextEditingController(
    text: _initial.remoteAuthorizedKeysPath,
  );
  late final _sshConfigPath = TextEditingController(
    text: _initial.sshConfigPath,
  );

  @override
  void dispose() {
    _localPrivate.dispose();
    _remoteAuthorizedKeys.dispose();
    _sshConfigPath.dispose();
    super.dispose();
  }

  Future<void> _save(SshKeyStorageConfig config) =>
      ref.read(sshKeyStorageConfigProvider.notifier).save(config);

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(sshKeyStorageConfigProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ConduitDropdown<SshKeyType>(
          value: config.defaultKeyType,
          label: 'settingsSshKeyDefaultType'.tr(),
          entries: [
            for (final type in SshKeyType.values)
              DropdownMenuEntry(value: type, label: type.label),
          ],
          onChanged: (value) {
            if (value != null) _save(config.copyWith(defaultKeyType: value));
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _localPrivate,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyLocalPrivateDir'.tr(),
          ),
          onChanged: (value) =>
              _save(config.copyWith(localPrivateKeyDirectory: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remoteAuthorizedKeys,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyRemoteAuthorizedKeys'.tr(),
          ),
          onChanged: (value) =>
              _save(config.copyWith(remoteAuthorizedKeysPath: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sshConfigPath,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyConfigPath'.tr(),
          ),
          onChanged: (value) => _save(config.copyWith(sshConfigPath: value)),
        ),
      ],
    );
  }
}
