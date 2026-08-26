import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:system_fonts/system_fonts.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/routing/app_router.gr.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';

import 'database_backup_service.dart';
import 'connection_export_service.dart';
import 'connection_import_service.dart';
import 'connection_import_sheet.dart';
import 'local_connection_manager.dart';
import 'server_providers.dart';
import 'ssh_config_bulk.dart';
import 'ssh_key_preferences.dart';
import 'terminal_adapter_preferences.dart';
import 'terminal_color_scheme.dart';
import 'transfer_conflict_preferences.dart';
import 'vault_service.dart';
import 'vault_file_storage.dart';

const _settingsCategories = [
  _SettingsCategory(
    id: 'terminal',
    titleKey: 'settingsTerminal',
    icon: Symbols.terminal,
  ),
  _SettingsCategory(
    id: 'connections',
    titleKey: 'settingsConnections',
    icon: Symbols.lan,
  ),
  _SettingsCategory(
    id: 'storage',
    titleKey: 'settingsStorage',
    icon: Symbols.storage,
  ),
  _SettingsCategory(
    id: 'export',
    titleKey: 'settingsExport',
    icon: Symbols.ios_share,
  ),
  _SettingsCategory(id: 'sync', titleKey: 'settingsSync', icon: Symbols.sync),
  _SettingsCategory(id: 'about', titleKey: 'settingsAbout', icon: Symbols.info),
];

class _SettingsCategory {
  const _SettingsCategory({
    required this.id,
    required this.titleKey,
    required this.icon,
  });

  final String id;
  final String titleKey;
  final IconData icon;
}

@RoutePage()
class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategoryId = useState(_settingsCategories.first.id);
    final biometricEnabled = ref.watch(biometricUnlockEnabledProvider);
    final terminalFontSize = ref.watch(terminalFontSizeProvider);
    final cursorAnimationEnabled = ref.watch(cursorAnimationEnabledProvider);
    final terminalLightTheme = ref.watch(terminalLightThemeProvider);
    final terminalDarkTheme = ref.watch(terminalDarkThemeProvider);
    final connectOnStartup = ref.watch(connectOnStartupProvider);
    final hideServerAddresses = ref.watch(hideServerAddressesProvider);
    final localMachineEnabled = ref.watch(localMachineEnabledProvider);
    final transferConflictMode = ref.watch(transferConflictModeProvider);
    final refreshInterval = ref.watch(serverMetricsRefreshIntervalProvider);
    final focusedRefreshInterval = ref.watch(
      focusedServerRefreshIntervalProvider,
    );
    final activeVaultFile = ref.watch(activeVaultFileProvider);
    final vaultFiles = ref.watch(vaultFilesProvider);
    final vaultLabels = ref.watch(vaultLabelsProvider);

    return ConduitAppScaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 768;
          final visibleCategories = _settingsCategories;
          final selectedCategory = visibleCategories.firstWhere(
            (category) => category.id == selectedCategoryId.value,
            orElse: () => visibleCategories.first,
          );
          final settingsContent = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                children: [
                  if (selectedCategory.id == 'terminal') ...[
                    _SettingsSection(
                      titleKey: 'settingsTerminal',
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _TerminalFontDropdown(),
                                const SizedBox(height: 16),
                                _TerminalFontSizeSlider(
                                  fontSize: terminalFontSize,
                                ),
                                const SizedBox(height: 8),
                                _TerminalLineHeightSlider(
                                  lineHeight: ref.watch(
                                    terminalLineHeightProvider,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _TerminalThemeTile(
                                  mode: Brightness.light,
                                  theme: terminalLightTheme,
                                  onEdit: () => _editTerminalTheme(
                                    context,
                                    ref,
                                    brightness: Brightness.light,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _TerminalThemeTile(
                                  mode: Brightness.dark,
                                  theme: terminalDarkTheme,
                                  onEdit: () => _editTerminalTheme(
                                    context,
                                    ref,
                                    brightness: Brightness.dark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: _sectionTilePadding,
                            title: const Text('settingsAnimateCursor').tr(),
                            subtitle: const Text(
                              'settingsAnimateCursorHint',
                            ).tr(),
                            value: cursorAnimationEnabled,
                            onChanged: (enabled) async {
                              await ref
                                  .read(cursorAnimationEnabledProvider.notifier)
                                  .setEnabled(enabled);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (selectedCategory.id == 'connections') ...[
                    _SettingsSection(
                      titleKey: 'settingsConnections',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: _sectionTilePadding,
                            title: const Text('settingsConnectOnStartup').tr(),
                            subtitle: const Text(
                              'settingsConnectOnStartupHint',
                            ).tr(),
                            value: connectOnStartup,
                            onChanged: (value) => ref
                                .read(connectOnStartupProvider.notifier)
                                .setEnabled(value),
                          ),
                          SwitchListTile(
                            contentPadding: _sectionTilePadding,
                            title: const Text(
                              'settingsHideServerAddresses',
                            ).tr(),
                            subtitle: const Text(
                              'settingsHideServerAddressesHint',
                            ).tr(),
                            value: hideServerAddresses,
                            onChanged: (value) => ref
                                .read(hideServerAddressesProvider.notifier)
                                .setEnabled(value),
                          ),
                          if (localMachineSupported) ...[
                            SwitchListTile(
                              contentPadding: _sectionTilePadding,
                              title: const Text('settingsLocalMachine').tr(),
                              subtitle: const Text(
                                'settingsLocalMachineHint',
                              ).tr(),
                              value: localMachineEnabled,
                              onChanged: (value) => ref
                                  .read(localMachineEnabledProvider.notifier)
                                  .setEnabled(value),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                _IntervalDropdown(
                                  labelKey: 'settingsBackgroundRefreshInterval',
                                  helperKey:
                                      'settingsBackgroundRefreshIntervalHint',
                                  value: refreshInterval,
                                  options: _refreshIntervals,
                                  fallback: _refreshIntervals[1],
                                  onChanged: (interval) {
                                    ref
                                        .read(
                                          serverMetricsRefreshIntervalProvider
                                              .notifier,
                                        )
                                        .setInterval(interval);
                                  },
                                ),
                                const SizedBox(height: 16),
                                _IntervalDropdown(
                                  labelKey: 'settingsFocusedRefreshInterval',
                                  helperKey:
                                      'settingsFocusedRefreshIntervalHint',
                                  value: focusedRefreshInterval,
                                  options: _focusedRefreshIntervals,
                                  fallback: _focusedRefreshIntervals.first,
                                  onChanged: (interval) {
                                    ref
                                        .read(
                                          focusedServerRefreshIntervalProvider
                                              .notifier,
                                        )
                                        .setInterval(interval);
                                  },
                                ),
                                const SizedBox(height: 16),
                                _TransferConflictDropdown(
                                  value: transferConflictMode,
                                  onChanged: (mode) => ref
                                      .read(
                                        transferConflictModeProvider.notifier,
                                      )
                                      .setMode(mode),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SettingsSection(
                      titleKey: 'settingsSshKeys',
                      child: _SshKeySettingsSection(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (selectedCategory.id == 'storage') ...[
                    _SettingsSection(
                      titleKey: 'settingsStorage',
                      padding: EdgeInsets.zero,
                      child: biometricEnabled.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: LinearProgressIndicator(),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'settingsBiometricError'.tr(
                              args: [error.toString()],
                            ),
                          ),
                        ),
                        data: (enabled) => Column(
                          children: [
                            SwitchListTile(
                              contentPadding: _sectionTilePadding,
                              shape: RoundedRectangleBorder(
                                borderRadius: _sectionTileBorderRadius(
                                  _SettingsTilePosition.first,
                                ),
                              ),
                              title: const Text('settingsBiometricUnlock').tr(),
                              subtitle: const Text(
                                'settingsBiometricUnlockHint',
                              ).tr(),
                              value: enabled,
                              onChanged: (value) =>
                                  _setBiometricUnlock(context, ref, value),
                            ),
                            ListTile(
                              contentPadding: _sectionTilePadding,
                              shape: RoundedRectangleBorder(
                                borderRadius: _sectionTileBorderRadius(
                                  _SettingsTilePosition.last,
                                ),
                              ),
                              leading: const Icon(Symbols.password),
                              title: const Text(
                                'settingsVaultChangePassword',
                              ).tr(),
                              subtitle: const Text(
                                'settingsVaultChangePasswordHint',
                              ).tr(),
                              trailing: const Icon(Symbols.chevron_right),
                              onTap: () => _changeVaultPassword(context, ref),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (selectedCategory.id == 'about') ...[
                    _SettingsSection(
                      titleKey: 'settingsAbout',
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: _sectionTilePadding,
                        shape: RoundedRectangleBorder(
                          borderRadius: _sectionTileBorderRadius(
                            _SettingsTilePosition.only,
                          ),
                        ),
                        leading: const Icon(Symbols.info),
                        title: Text('aboutTitle'.tr()),
                        subtitle: Text('settingsAboutHint'.tr()),
                        trailing: const Icon(Symbols.chevron_right),
                        onTap: () => context.router.push(const AboutRoute()),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (selectedCategory.id == 'storage') ...[
                    _SettingsSection(
                      titleKey: 'settingsVaults',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ...[
                            for (final (index, path) in vaultFiles.indexed)
                              _VaultCloudBindingTile(
                                vaultId: path,
                                position: index == 0
                                    ? _SettingsTilePosition.first
                                    : _SettingsTilePosition.middle,
                                title:
                                    vaultLabels[path] ??
                                    ref
                                        .read(vaultFileStorageProvider)
                                        .fileName(path),
                                active: activeVaultFile == path,
                                onSelect: () => ref
                                    .read(activeVaultFileProvider.notifier)
                                    .select(path),
                                onExport: activeVaultFile == path
                                    ? () => _exportDatabase(context, ref)
                                    : null,
                                onMove: externalVaultsSupported
                                    ? () => _moveVault(context, ref, path)
                                    : null,
                                onRename: () => _renameVault(
                                  context,
                                  ref,
                                  path,
                                  vaultLabels[path] ??
                                      ref
                                          .read(vaultFileStorageProvider)
                                          .fileName(path),
                                ),
                                onDelete: activeVaultFile == path
                                    ? null
                                    : () => _deleteVault(context, ref, path),
                                onImport: activeVaultFile == path
                                    ? () => _importDatabase(context, ref)
                                    : null,
                              ),
                          ],
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.last,
                              ),
                            ),
                            leading: const Icon(Symbols.add),
                            title: const Text('settingsVaultCreate').tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _showVaultOnboarding(context, ref),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (selectedCategory.id == 'export') ...[
                    _SettingsSection(
                      titleKey: 'settingsConnectionsTransfer',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.first,
                              ),
                            ),
                            leading: const Icon(Symbols.dns),
                            title: const Text('settingsConnectionsExport').tr(),
                            subtitle: const Text(
                              'settingsConnectionsExportHint',
                            ).tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _exportConnections(context, ref),
                          ),
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.last,
                              ),
                            ),
                            leading: const Icon(Symbols.upload_file),
                            title: const Text('settingsConnectionsImport').tr(),
                            subtitle: const Text(
                              'settingsConnectionsImportHint',
                            ).tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _importConnections(context, ref),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SettingsSection(
                      titleKey: 'settingsVaultBackupSection',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.first,
                              ),
                            ),
                            leading: const Icon(Symbols.archive),
                            title: const Text('settingsExportData').tr(),
                            subtitle: const Text('settingsExportDataHint').tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _exportDatabase(context, ref),
                          ),
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.last,
                              ),
                            ),
                            leading: const Icon(Symbols.unarchive),
                            title: const Text('settingsImportData').tr(),
                            subtitle: const Text('settingsImportDataHint').tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _importDatabase(context, ref),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SettingsSection(
                      titleKey: 'settingsSshConfigSyncSection',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.first,
                              ),
                            ),
                            leading: const Icon(Symbols.description),
                            title: const Text(
                              'settingsConnectionsExportSshConfig',
                            ).tr(),
                            subtitle: const Text(
                              'settingsConnectionsExportSshConfigHint',
                            ).tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _exportToSshConfig(context, ref),
                          ),
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.last,
                              ),
                            ),
                            leading: const Icon(Symbols.terminal),
                            title: const Text(
                              'settingsConnectionsImportSshConfig',
                            ).tr(),
                            subtitle: const Text(
                              'settingsConnectionsImportSshConfigHint',
                            ).tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () =>
                                _importFromLocalSshConfig(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (selectedCategory.id == 'sync') ...[
                    const SizedBox(height: 24),
                    _SettingsSection(
                      titleKey: 'settingsICloud',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.first,
                              ),
                            ),
                            leading: const Icon(Symbols.cloud_upload),
                            title: const Text('settingsICloudBackup').tr(),
                            subtitle: const Text(
                              'settingsICloudBackupHint',
                            ).tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _backupToICloud(context, ref),
                          ),
                          ListTile(
                            contentPadding: _sectionTilePadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: _sectionTileBorderRadius(
                                _SettingsTilePosition.last,
                              ),
                            ),
                            leading: const Icon(Symbols.cloud_download),
                            title: const Text('settingsICloudRestore').tr(),
                            subtitle: const Text(
                              'settingsICloudRestoreHint',
                            ).tr(),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => _restoreFromICloud(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 232,
                  child: _SettingsCategoryRail(
                    categories: visibleCategories,
                    selectedId: selectedCategory.id,
                    onSelected: (id) => selectedCategoryId.value = id,
                  ),
                ),
                Expanded(child: settingsContent),
              ],
            );
          }
          return Column(
            children: [
              _SettingsCategoryTabs(
                categories: visibleCategories,
                selectedId: selectedCategory.id,
                onSelected: (id) => selectedCategoryId.value = id,
              ),
              Expanded(child: settingsContent),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editTerminalTheme(
    BuildContext context,
    WidgetRef ref, {
    required Brightness brightness,
  }) async {
    final isLight = brightness == Brightness.light;
    final updated = await showDialog<TerminalColorScheme>(
      context: context,
      builder: (context) => _TerminalThemeDialog(
        brightness: brightness,
        initialScheme: isLight
            ? ref.read(terminalLightThemeProvider)
            : ref.read(terminalDarkThemeProvider),
      ),
    );
    if (updated == null) return;
    if (isLight) {
      await ref.read(terminalLightThemeProvider.notifier).save(updated);
    } else {
      await ref.read(terminalDarkThemeProvider.notifier).save(updated);
    }
  }

  Future<void> _setBiometricUnlock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final vault = ref.read(vaultServiceProvider);
    try {
      if (enabled) {
        // Prompt once during setup; only persist when authentication succeeds.
        await vault.enableBiometricUnlock();
      } else {
        await vault.disableBiometricUnlock();
      }
    } catch (error) {
      // Leave the switch off if setup fails (e.g. cancelled or unavailable).
      await vault.disableBiometricUnlock();
      if (context.mounted) {
        _showMessage(
          'settingsBiometricSetupFailed'.tr(args: [error.toString()]),
        );
      }
    } finally {
      ref.invalidate(biometricUnlockEnabledProvider);
    }
  }

  Future<void> _changeVaultPassword(BuildContext context, WidgetRef ref) async {
    final password = await _changeVaultPasswordSheet(context);
    if (password == null || !context.mounted) return;
    try {
      await ref.read(vaultServiceProvider).changePassword(password);
      if (context.mounted) {
        _showMessage('settingsVaultPasswordChanged'.tr());
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    final password = await _backupPasswordSheet(context, confirm: true);
    if (password == null || !context.mounted) return;

    final vault = ref.read(vaultServiceProvider);
    if (!await vault.unlockWithPassword(password)) {
      if (context.mounted) {
        _showMessage('settingsVaultPasswordInvalid'.tr());
      }
      return;
    }
    if (!context.mounted) return;

    final path = await FilePicker.saveFile(
      dialogTitle: 'settingsExportData'.tr(),
      fileName: 'maidkit-${exportFileNamePrefix(ref)}-${exportTimestamp()}.mkb',
      type: FileType.custom,
      allowedExtensions: const ['mkb'],
    );
    if (path == null || !context.mounted) return;

    try {
      final archive = await DatabaseBackupService(
        ref.read(databaseProvider),
        ref.read(vaultServiceProvider),
      ).exportArchive(password);
      await File(path).writeAsString(archive);
      if (context.mounted) _showMessage('settingsExportSuccess'.tr());
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  /// iCloud Drive's local folder, or null when iCloud Drive is off. Backups
  /// written here are synced by the system — no entitlements needed.
  static String? _icloudDrivePath() {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    final root = '$home/Library/Mobile Documents/com~apple~CloudDocs';
    return Directory(root).existsSync() ? root : null;
  }

  Future<void> _backupToICloud(BuildContext context, WidgetRef ref) async {
    final root = _icloudDrivePath();
    if (root == null) {
      _showMessage('settingsICloudUnavailable'.tr());
      return;
    }
    final password = await _backupPasswordSheet(context, confirm: true);
    if (password == null || !context.mounted) return;
    final vault = ref.read(vaultServiceProvider);
    if (!await vault.unlockWithPassword(password)) {
      if (context.mounted) _showMessage('settingsVaultPasswordInvalid'.tr());
      return;
    }
    if (!context.mounted) return;
    try {
      final archive = await DatabaseBackupService(
        ref.read(databaseProvider),
        ref.read(vaultServiceProvider),
      ).exportArchive(password);
      final dir = Directory('$root/Conduit');
      await dir.create(recursive: true);
      final name =
          'conduit-${exportFileNamePrefix(ref)}-${exportTimestamp()}.mkb';
      await File('${dir.path}/$name').writeAsString(archive, flush: true);
      await _pruneICloudBackups(dir);
      if (context.mounted) {
        _showMessage('settingsICloudBackupSuccess'.tr(args: [name]));
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  /// Keeps only the ten newest backups so the folder cannot grow forever.
  static Future<void> _pruneICloudBackups(Directory dir) async {
    final backups = <File>[
      await for (final entity in dir.list())
        if (entity is File && entity.path.endsWith('.mkb')) entity,
    ];
    if (backups.length <= 10) return;
    final dated = <(DateTime, File)>[
      for (final file in backups) ((await file.lastModified()), file),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, file) in dated.skip(10)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _restoreFromICloud(BuildContext context, WidgetRef ref) async {
    final root = _icloudDrivePath();
    if (root == null) {
      _showMessage('settingsICloudUnavailable'.tr());
      return;
    }
    final dir = Directory('$root/Conduit');
    final backups = <(DateTime, File)>[];
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.mkb')) {
          backups.add(((await entity.lastModified()), entity));
        }
      }
    }
    if (backups.isEmpty) {
      _showMessage('settingsICloudNoBackups'.tr());
      return;
    }
    backups.sort((a, b) => b.$1.compareTo(a.$1));
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsICloudChooseBackup'.tr(),
        heightFactor: 0.6,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final (modified, file) in backups)
              ListTile(
                leading: const Icon(Symbols.cloud_download),
                title: Text(file.uri.pathSegments.last),
                subtitle: Text(
                  '${modified.year}-'
                  '${modified.month.toString().padLeft(2, '0')}-'
                  '${modified.day.toString().padLeft(2, '0')} '
                  '${modified.hour.toString().padLeft(2, '0')}:'
                  '${modified.minute.toString().padLeft(2, '0')}',
                ),
                onTap: () => Navigator.of(sheetContext).pop(file.path),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _importDatabaseFromPath(context, ref, picked);
  }

  Future<void> _importDatabase(BuildContext context, WidgetRef ref) async {
    final selection = await FilePicker.pickFiles(
      dialogTitle: 'settingsImportData'.tr(),
      type: FileType.custom,
      allowedExtensions: const ['mkb'],
    );
    final path = selection?.files.singleOrNull?.path;
    if (path == null || !context.mounted) return;
    await _importDatabaseFromPath(context, ref, path);
  }

  Future<void> _importDatabaseFromPath(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) async {
    final password = await _backupPasswordSheet(context, confirm: false);
    if (password == null || !context.mounted) return;

    final destination = await showModalBottomSheet<_ImportDestination>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsImportDestinationTitle'.tr(),
        heightFactor: 0.44,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            RadioGroup<_ImportDestination>(
              groupValue: _ImportDestination.newVault,
              onChanged: (value) {
                if (value != null) Navigator.of(sheetContext).pop(value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<_ImportDestination>(
                    value: _ImportDestination.newVault,
                    title: const Text('settingsImportNewVault').tr(),
                    subtitle: const Text('settingsImportNewVaultHint').tr(),
                  ),
                  RadioListTile<_ImportDestination>(
                    value: _ImportDestination.replaceCurrent,
                    title: const Text('settingsImportReplaceCurrent').tr(),
                    subtitle: const Text(
                      'settingsImportReplaceCurrentHint',
                    ).tr(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('commonCancel').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (destination == null || !context.mounted) return;

    if (destination == _ImportDestination.replaceCurrent) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        builder: (sheetContext) => SheetScaffold(
          titleText: 'settingsImportConfirmTitle'.tr(),
          heightFactor: 0.34,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text('settingsImportConfirmDescription').tr(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('commonCancel').tr(),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('settingsImportReplaceCurrent').tr(),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await _importIntoCurrentVault(context, ref, path, password);
      return;
    }

    final vaultPassword = await _newVaultPasswordSheet(context);
    if (vaultPassword == null || !context.mounted) return;

    final storage = ref.read(vaultFileStorageProvider);
    final vaultPath = await storage.createVaultPath(name: path);
    await storage.persistentPath(vaultPath);

    final database = AppDatabase(filePath: vaultPath);
    final vault = VaultService(database, vaultId: storage.vaultId(vaultPath));
    try {
      await vault.create(vaultPassword);
      final archive = await File(path).readAsString();
      await DatabaseBackupService(
        database,
        vault,
      ).importArchive(archive, password);
      await ref.read(activeVaultFileProvider.notifier).select(vaultPath);
      if (context.mounted) _showMessage('settingsImportSuccess'.tr());
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    } finally {
      await database.close();
    }
  }

  Future<void> _importIntoCurrentVault(
    BuildContext context,
    WidgetRef ref,
    String path,
    String password,
  ) async {
    try {
      final archive = await File(path).readAsString();
      await DatabaseBackupService(
        ref.read(databaseProvider),
        ref.read(vaultServiceProvider),
      ).importArchive(archive, password);
      if (context.mounted) _showMessage('settingsImportSuccess'.tr());
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _exportConnections(BuildContext context, WidgetRef ref) async {
    final format = await showModalBottomSheet<_ConnectionsExportFormat>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsConnectionsExportTitle'.tr(),
        heightFactor: 0.5,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            RadioGroup<_ConnectionsExportFormat>(
              groupValue: _ConnectionsExportFormat.jsonRedacted,
              onChanged: (value) {
                if (value != null) Navigator.of(sheetContext).pop(value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<_ConnectionsExportFormat>(
                    value: _ConnectionsExportFormat.jsonRedacted,
                    title: const Text(
                      'settingsConnectionsFormatJsonRedacted',
                    ).tr(),
                    subtitle: const Text(
                      'settingsConnectionsFormatJsonRedactedHint',
                    ).tr(),
                  ),
                  RadioListTile<_ConnectionsExportFormat>(
                    value: _ConnectionsExportFormat.jsonProtected,
                    title: const Text(
                      'settingsConnectionsFormatJsonProtected',
                    ).tr(),
                    subtitle: const Text(
                      'settingsConnectionsFormatJsonProtectedHint',
                    ).tr(),
                  ),
                  RadioListTile<_ConnectionsExportFormat>(
                    value: _ConnectionsExportFormat.csv,
                    title: const Text('settingsConnectionsFormatCsv').tr(),
                    subtitle: const Text(
                      'settingsConnectionsFormatCsvHint',
                    ).tr(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('commonCancel').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) return;

    final extension = switch (format) {
      _ConnectionsExportFormat.csv => 'csv',
      _ => 'json',
    };
    final fileName =
        'maidkit-connections-${exportFileNamePrefix(ref)}-${exportTimestamp()}.$extension';
    String? passphrase;
    if (format == _ConnectionsExportFormat.jsonProtected) {
      passphrase = await _connectionsPasswordSheet(context);
      if (passphrase == null || !context.mounted) return;
    }

    final path = await FilePicker.saveFile(
      dialogTitle: 'settingsConnectionsExportTitle'.tr(),
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (path == null || !context.mounted) return;

    try {
      final service = ConnectionExportService(
        ref.read(databaseProvider),
        ref.read(vaultServiceProvider),
      );
      final content = switch (format) {
        _ConnectionsExportFormat.csv => await service.exportCsv(),
        _ => await service.exportJson(passphrase: passphrase),
      };
      await File(path).writeAsString(content);
      if (context.mounted) {
        _showMessage('settingsConnectionsExportSuccess'.tr());
      }
    } on VaultLockedException {
      if (context.mounted) {
        _showMessage('settingsConnectionsVaultLocked'.tr());
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage(
          'settingsConnectionsExportError'.tr(args: [error.toString()]),
        );
      }
    }
  }

  Future<void> _importConnections(BuildContext context, WidgetRef ref) async {
    final selection = await FilePicker.pickFiles(
      dialogTitle: 'settingsConnectionsImportTitle'.tr(),
      type: FileType.any,
      allowMultiple: true,
    );
    final paths =
        selection?.files
            .map((file) => file.path)
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList() ??
        const [];
    if (paths.isEmpty || !context.mounted) return;
    await _runConnectionsImport(context, ref, paths);
  }

  /// Imports straight from the local OpenSSH config, no file picker.
  Future<void> _importFromLocalSshConfig(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final config = ref.read(sshKeyStorageConfigProvider);
    final path = expandLocalPath(
      config.sshConfigPath,
      fallback: '~/.ssh/config',
    );
    if (!await File(path).exists()) {
      _showMessage('assetsSshConfigEmpty'.tr());
      return;
    }
    if (!context.mounted) return;
    await _runConnectionsImport(context, ref, [path]);
  }

  /// Writes every saved SSH server into the local OpenSSH config.
  Future<void> _exportToSshConfig(BuildContext context, WidgetRef ref) async {
    try {
      final (count, path) = await writeServersToSshConfig(
        repository: ref.read(serverRepositoryProvider),
        keyService: ref.read(sshKeyServiceProvider),
        config: ref.read(sshKeyStorageConfigProvider),
      );
      ref.invalidate(sshConfigHostsProvider);
      _showMessage('assetsSshConfigSyncDone'.tr(args: ['$count', path]));
    } catch (error) {
      _showMessage('settingsConnectionsExportError'.tr(args: ['$error']));
    }
  }

  Future<void> _runConnectionsImport(
    BuildContext context,
    WidgetRef ref,
    List<String> paths,
  ) async {
    final service = ConnectionImportService(
      ref.read(databaseProvider),
      ref.read(vaultServiceProvider),
    );
    final preview = await service.previewFiles(
      paths,
      requestPassphrase: () => _connectionsImportPasswordSheet(context),
    );
    if (!context.mounted || preview.aborted) return;

    if (preview.isEmpty) {
      if (preview.firstError is ConnectionSecretsPassphraseException) {
        _showMessage('settingsConnectionsImportWrongPassphrase'.tr());
      } else {
        _showMessage(
          'settingsConnectionsImportError'.tr(
            args: [
              preview.firstError?.toString() ??
                  'settingsConnectionsImportEmpty'.tr(),
            ],
          ),
        );
      }
      return;
    }

    final selected = await showModalBottomSheet<List<ImportCandidate>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) =>
          ConnectionImportPreviewSheet(candidates: preview.candidates),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;

    try {
      final result = await service.import(selected);
      if (context.mounted) {
        _showMessage(
          'settingsConnectionsImportSuccess'.tr(args: ['${result.created}']),
        );
      }
    } on Exception catch (error) {
      if (context.mounted) {
        _showMessage(
          'settingsConnectionsImportError'.tr(args: [error.toString()]),
        );
      }
    }
  }

  Future<String?> _chooseVaultFolder(
    BuildContext context, {
    String? initialDirectory,
  }) async {
    try {
      return await FilePicker.getDirectoryPath(
        dialogTitle: 'settingsVaultChooseFolder'.tr(),
        initialDirectory: initialDirectory,
      );
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
      return null;
    }
  }

  Future<void> _createLocalVault(BuildContext context, WidgetRef ref) async {
    final name = await _chooseVaultNameSheet(context);
    if (name == null || !context.mounted) return;
    final path = await ref
        .read(vaultFileStorageProvider)
        .createVaultPath(name: name);
    try {
      await ref.read(vaultLabelsProvider.notifier).rename(path, name);
      await ref.read(activeVaultFileProvider.notifier).select(path);
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _createExternalVault(BuildContext context, WidgetRef ref) async {
    if (!externalVaultsSupported) return;
    final name = await _chooseVaultNameSheet(context);
    if (name == null || !context.mounted) return;
    final folder = await _chooseVaultFolder(context);
    if (folder == null || !context.mounted) return;
    final path = await ref
        .read(vaultFileStorageProvider)
        .createVaultPath(name: name, directoryPath: folder);
    try {
      await ref.read(vaultLabelsProvider.notifier).rename(path, name);
      await ref.read(activeVaultFileProvider.notifier).select(path);
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _renameVault(
    BuildContext context,
    WidgetRef ref,
    String vaultId,
    String currentName,
  ) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => _VaultNameSheet(
        initialValue: currentName,
        titleKey: 'settingsVaultRename',
        actionKey: 'commonSave',
      ),
    );
    if (name != null) {
      await ref.read(vaultLabelsProvider.notifier).rename(vaultId, name);
    }
  }

  Future<void> _moveVault(
    BuildContext context,
    WidgetRef ref,
    String vaultId,
  ) async {
    if (!externalVaultsSupported) return;
    final folder = await _chooseVaultFolder(context);
    if (folder == null || !context.mounted) return;
    try {
      final storage = ref.read(vaultFileStorageProvider);
      final newPath = await storage.moveVault(
        vaultId,
        directoryPath: folder,
        name: storage.fileName(vaultId),
      );
      await VaultService.relocateStoredKeys(
        oldVaultId: vaultId,
        newVaultId: newPath,
      );
      final label = ref.read(vaultLabelsProvider)[vaultId];
      await ref.read(vaultFilesProvider.notifier).forget(vaultId);
      await ref.read(vaultFilesProvider.notifier).remember(newPath);
      await ref.read(vaultLabelsProvider.notifier).remove(vaultId);
      if (label != null) {
        await ref.read(vaultLabelsProvider.notifier).rename(newPath, label);
      }
      if (ref.read(activeVaultFileProvider) == vaultId) {
        await ref.read(activeVaultFileProvider.notifier).select(newPath);
      }
      if (context.mounted) _showMessage('settingsVaultMoveComplete'.tr());
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _deleteVault(
    BuildContext context,
    WidgetRef ref,
    String vaultId,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsVaultDelete'.tr(),
        heightFactor: 0.34,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('settingsVaultDeleteHint').tr(),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('commonCancel').tr(),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('commonDelete').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (ref.read(activeVaultFileProvider) == vaultId) {
      await ref.read(activeVaultFileProvider.notifier).select(null);
    }
    await ref.read(vaultFileStorageProvider).deleteVault(vaultId);
    await ref.read(vaultFilesProvider.notifier).forget(vaultId);
    await ref.read(vaultLabelsProvider.notifier).remove(vaultId);
  }

  Future<void> _showVaultOnboarding(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<_VaultOnboardingChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsVaultCreate'.tr(),
        heightFactor: 0.58,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            ListTile(
              leading: const Icon(Symbols.lock),
              title: const Text('settingsVaultCreateLocal').tr(),
              subtitle: const Text('settingsVaultCreateLocalHint').tr(),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_VaultOnboardingChoice.local),
            ),
            if (externalVaultsSupported)
              ListTile(
                leading: const Icon(Symbols.folder_open),
                title: const Text('settingsVaultCreateExternal').tr(),
                subtitle: const Text('settingsVaultCreateExternalHint').tr(),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_VaultOnboardingChoice.external),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('commonCancel').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (choice == _VaultOnboardingChoice.local && context.mounted) {
      await _createLocalVault(context, ref);
    } else if (choice == _VaultOnboardingChoice.external && context.mounted) {
      await _createExternalVault(context, ref);
    }
  }
}

enum _ImportDestination { newVault, replaceCurrent }

enum _ConnectionsExportFormat { jsonRedacted, jsonProtected, csv }

enum _VaultOnboardingChoice { local, external }

enum _VaultTileAction { move, rename, delete }

enum _SettingsTilePosition { only, first, middle, last }

const _sectionTilePadding = EdgeInsets.symmetric(horizontal: 16);

BorderRadius _sectionTileBorderRadius(_SettingsTilePosition position) {
  const radius = Radius.circular(12);
  return BorderRadius.only(
    topLeft:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.first
        ? radius
        : Radius.zero,
    topRight:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.first
        ? radius
        : Radius.zero,
    bottomLeft:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.last
        ? radius
        : Radius.zero,
    bottomRight:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.last
        ? radius
        : Radius.zero,
  );
}

Future<String?> _backupPasswordSheet(
  BuildContext context, {
  required bool confirm,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (context) => _BackupPasswordSheet(confirm: confirm),
);

Future<String?> _connectionsPasswordSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => const _BackupPasswordSheet(
        confirm: true,
        titleKey: 'settingsConnectionsPasswordTitle',
        hintKey: 'settingsConnectionsPasswordHint',
        actionKey: 'settingsConnectionsExportAction',
      ),
    );

Future<String?> _connectionsImportPasswordSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => const _BackupPasswordSheet(
        confirm: false,
        titleKey: 'settingsConnectionsImportPasswordTitle',
        hintKey: 'settingsConnectionsImportPasswordHint',
        actionKey: 'settingsConnectionsImportAction',
      ),
    );

Future<String?> _newVaultPasswordSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => const _BackupPasswordSheet(
        confirm: true,
        titleKey: 'settingsImportNewVaultPasswordTitle',
        hintKey: 'settingsImportNewVaultPasswordHint',
        actionKey: 'vaultCreateAction',
      ),
    );

Future<String?> _changeVaultPasswordSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => const _BackupPasswordSheet(
        confirm: true,
        titleKey: 'settingsVaultChangePassword',
        hintKey: 'settingsVaultChangePasswordHint',
        actionKey: 'commonSave',
      ),
    );

Future<String?> _chooseVaultNameSheet(
  BuildContext context, {
  String? initialValue,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (context) =>
      _VaultNameSheet(initialValue: initialValue ?? 'settingsVaultCreate'.tr()),
);

class _VaultNameSheet extends StatefulWidget {
  const _VaultNameSheet({
    required this.initialValue,
    this.titleKey = 'settingsVaultName',
    this.actionKey = 'commonContinue',
  });

  final String initialValue;
  final String titleKey;
  final String actionKey;

  @override
  State<_VaultNameSheet> createState() => _VaultNameSheetState();
}

class _VaultNameSheetState extends State<_VaultNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    titleText: widget.titleKey.tr(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: 'settingsVaultName'.tr()),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('commonCancel').tr(),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.actionKey.tr()),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BackupPasswordSheet extends StatefulWidget {
  const _BackupPasswordSheet({
    required this.confirm,
    this.titleKey,
    this.hintKey,
    this.actionKey,
  });

  final bool confirm;
  final String? titleKey;
  final String? hintKey;
  final String? actionKey;

  @override
  State<_BackupPasswordSheet> createState() => _BackupPasswordSheetState();
}

class _BackupPasswordSheetState extends State<_BackupPasswordSheet> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    titleText:
        (widget.titleKey ??
                (widget.confirm
                    ? 'settingsExportPasswordTitle'
                    : 'settingsImportPasswordTitle'))
            .tr(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          (widget.hintKey ??
                  (widget.confirm
                      ? 'settingsExportVaultPasswordHint'
                      : 'settingsImportVaultPasswordHint'))
              .tr(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: 'vaultPasswordLabel'.tr()),
        ),
        if (widget.confirm) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirmation,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'vaultConfirmPasswordLabel'.tr(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('commonCancel').tr(),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (widget.confirm && _password.text != _confirmation.text) {
                  showSnackBar('vaultPasswordsDontMatch'.tr());
                  return;
                }
                Navigator.of(context).pop(_password.text);
              },
              child: Text(
                widget.confirm
                    ? (widget.actionKey ?? 'settingsExportData').tr()
                    : (widget.actionKey ?? 'settingsImportData').tr(),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void _showMessage(String message) {
  showSnackBar(message);
}

class _VaultCloudBindingTile extends ConsumerWidget {
  const _VaultCloudBindingTile({
    required this.vaultId,
    required this.title,
    required this.position,
    required this.active,
    required this.onSelect,
    this.onExport,
    this.onImport,
    this.onMove,
    this.onRename,
    this.onDelete,
  });

  final String vaultId;
  final String title;
  final _SettingsTilePosition position;
  final bool active;
  final Future<void> Function() onSelect;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onMove;
  final Future<void> Function()? onRename;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final external =
        ref.watch(vaultExternalPathProvider(vaultId)).asData?.value ?? false;
    final tileBorderRadius = _sectionTileBorderRadius(position);
    return Material(
      color: active ? Theme.of(context).colorScheme.secondaryContainer : null,
      borderRadius: tileBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: _sectionTilePadding,
            shape: RoundedRectangleBorder(borderRadius: tileBorderRadius),
            leading: const Icon(Symbols.lock),
            title: Text(title),
            subtitle: external ? Text(vaultId) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<_VaultTileAction>(
                  onSelected: (action) {
                    if (action == _VaultTileAction.move) onMove?.call();
                    if (action == _VaultTileAction.rename) onRename?.call();
                    if (action == _VaultTileAction.delete) onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onMove != null)
                      PopupMenuItem(
                        value: _VaultTileAction.move,
                        child: Text('settingsVaultMove'.tr()),
                      ),
                    if (onRename != null)
                      PopupMenuItem(
                        value: _VaultTileAction.rename,
                        child: Text('settingsVaultRename'.tr()),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: _VaultTileAction.delete,
                        child: Text('settingsVaultDelete'.tr()),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Symbols.chevron_right),
              ],
            ),
            onTap: () => onSelect(),
          ),
          if (active)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onExport == null ? null : () => onExport!(),
                    icon: const Icon(Symbols.file_download),
                    label: const Text('settingsExportData').tr(),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onImport == null ? null : () => onImport!(),
                    icon: const Icon(Symbols.file_upload),
                    label: const Text('settingsImportData').tr(),
                  ),
                ],
              ),
            ).alignment(.centerLeft),
        ],
      ),
    );
  }
}

class _SettingsCategoryRail extends StatelessWidget {
  const _SettingsCategoryRail({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_SettingsCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                selected: category.id == selectedId,
                selectedTileColor: scheme.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(
                  category.icon,
                  color: category.id == selectedId
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                title: Text(category.titleKey).tr(),
                visualDensity: VisualDensity.compact,
                onTap: () => onSelected(category.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsCategoryTabs extends StatefulWidget {
  const _SettingsCategoryTabs({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_SettingsCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<_SettingsCategoryTabs> createState() => _SettingsCategoryTabsState();
}

class _SettingsCategoryTabsState extends State<_SettingsCategoryTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  int get _selectedIndex => widget.categories.indexWhere(
    (category) => category.id == widget.selectedId,
  );

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  TabController _createController() {
    final index = _selectedIndex;
    return TabController(
      length: widget.categories.length,
      vsync: this,
      initialIndex: index < 0 ? 0 : index,
    );
  }

  @override
  void didUpdateWidget(covariant _SettingsCategoryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories.length != oldWidget.categories.length) {
      _controller.dispose();
      _controller = _createController();
    } else if (widget.selectedId != oldWidget.selectedId) {
      final index = _selectedIndex;
      if (index >= 0 && index != _controller.index) {
        _controller.index = index;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: scheme.outlineVariant.withValues(alpha: 0.7),
          dividerHeight: 1,
          indicatorColor: scheme.primary,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          onTap: (index) => widget.onSelected(widget.categories[index].id),
          tabs: [
            for (final category in widget.categories)
              Tab(
                icon: Icon(category.icon, size: 18),
                text: category.titleKey.tr(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.titleKey,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String titleKey;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleKey, style: Theme.of(context).textTheme.titleMedium).tr(),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

class _IntervalDropdown extends StatelessWidget {
  const _IntervalDropdown({
    required this.labelKey,
    required this.helperKey,
    required this.value,
    required this.options,
    required this.fallback,
    required this.onChanged,
  });

  final String labelKey;
  final String helperKey;
  final Duration value;
  final List<Duration> options;
  final Duration fallback;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Duration>(
      initialValue: options.contains(value) ? value : fallback,
      decoration: InputDecoration(
        labelText: labelKey.tr(),
        helperText: helperKey.tr(),
      ),
      items: [
        for (final interval in options)
          DropdownMenuItem(
            value: interval,
            child: Text(_formatInterval(interval)),
          ),
      ],
      onChanged: (interval) {
        if (interval != null) onChanged(interval);
      },
    );
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
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TransferConflictMode>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'settingsTransferConflictMode'.tr(),
        helperText: 'settingsTransferConflictModeHint'.tr(),
      ),
      items: [
        for (final mode in TransferConflictMode.values)
          DropdownMenuItem(
            value: mode,
            child: Text(switch (mode) {
              TransferConflictMode.rename =>
                'settingsTransferConflictRename'.tr(),
              TransferConflictMode.overwrite =>
                'settingsTransferConflictOverwrite'.tr(),
              TransferConflictMode.ask => 'settingsTransferConflictAsk'.tr(),
            }),
          ),
      ],
      onChanged: (mode) {
        if (mode != null) onChanged(mode);
      },
    );
  }
}

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

String _formatInterval(Duration interval) {
  if (interval.inMinutes >= 1) {
    return 'settingsIntervalMinutes'.tr(args: ['${interval.inMinutes}']);
  }
  return 'settingsIntervalSeconds'.tr(args: ['${interval.inSeconds}']);
}

/// Whole-point font size slider for new terminals.
class _TerminalFontSizeSlider extends ConsumerWidget {
  const _TerminalFontSizeSlider({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'settingsTerminalFontSize'.tr(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text('${fontSize.round()} pt', style: theme.textTheme.labelLarge),
          ],
        ),
        Slider(
          value: fontSize.clamp(kTerminalFontSizeMin, kTerminalFontSizeMax),
          min: kTerminalFontSizeMin,
          max: kTerminalFontSizeMax,
          divisions: (kTerminalFontSizeMax - kTerminalFontSizeMin).round(),
          label: '${fontSize.round()}',
          onChanged: (value) => ref
              .read(terminalFontSizeProvider.notifier)
              .setFontSize(value.roundToDouble()),
        ),
        Text(
          'settingsTerminalFontSizeHint',
          style: theme.textTheme.bodySmall,
        ).tr(),
      ],
    );
  }
}

class _TerminalLineHeightSlider extends ConsumerWidget {
  const _TerminalLineHeightSlider({required this.lineHeight});

  final double lineHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'settingsTerminalLineHeight'.tr(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${lineHeight.toStringAsFixed(2)}×',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        Slider(
          value: lineHeight.clamp(
            kTerminalLineHeightMin,
            kTerminalLineHeightMax,
          ),
          min: kTerminalLineHeightMin,
          max: kTerminalLineHeightMax,
          divisions: 12,
          label: lineHeight.toStringAsFixed(2),
          onChanged: (value) => ref
              .read(terminalLineHeightProvider.notifier)
              .setLineHeight((value * 20).roundToDouble() / 20),
        ),
        Text(
          'settingsTerminalLineHeightHint',
          style: theme.textTheme.bodySmall,
        ).tr(),
      ],
    );
  }
}

class _TerminalFontDropdown extends HookConsumerWidget {
  const _TerminalFontDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(availableTerminalFontsProvider);
    final monoOnly = ref.watch(monospaceTerminalFontsOnlyProvider);
    final current = ref.watch(terminalFontFamilyProvider);

    final all = fonts.value ?? const <TerminalFontOption>[];
    final filtered = <TerminalFontOption>[
      for (final option in all)
        if (!monoOnly || option.label.toLowerCase().contains('mono')) option,
    ];
    if (!filtered.any((option) => option.family == current)) {
      filtered.insert(0, TerminalFontOption(label: current, family: current));
    }

    final loaded = useState<Set<String>>(const {});
    useEffect(
      () {
        var cancelled = false;
        final missing = filtered
            .map((option) => option.family)
            .where((family) => !loaded.value.contains(family))
            .toList();
        if (missing.isEmpty) return null;

        Future<void> loadMissingFonts() async {
          for (final family in missing) {
            if (cancelled) return;
            try {
              await SystemFonts().loadFont(family);
            } on Object {
              // Bundled or unavailable fonts need no engine loading.
            }
            if (cancelled) return;
            loaded.value = {...loaded.value, family};
          }
        }

        unawaited(loadMissingFonts());
        return () => cancelled = true;
      },
      [
        monoOnly,
        filtered.map((option) => option.family).join(','),
        fonts.value,
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fontHint = Text(
          'settingsTerminalFontHint',
          style: Theme.of(context).textTheme.bodySmall,
        ).tr();
        final monospaceToggle = constraints.maxWidth < 420
            ? Row(
                children: [
                  Flexible(
                    child: Text(
                      'settingsTerminalFontMonospaceOnly'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: monoOnly,
                    onChanged: (value) => ref
                        .read(monospaceTerminalFontsOnlyProvider.notifier)
                        .setEnabled(value),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'settingsTerminalFontMonospaceOnly'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: monoOnly,
                    onChanged: (value) => ref
                        .read(monospaceTerminalFontsOnlyProvider.notifier)
                        .setEnabled(value),
                  ),
                ],
              );

        void setFontFamily(String? family) {
          if (family != null) {
            ref.read(terminalFontFamilyProvider.notifier).setFontFamily(family);
          }
        }

        final fontDropdown = constraints.maxWidth < 420
            ? DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: current,
                decoration: InputDecoration(
                  labelText: 'settingsTerminalFont'.tr(),
                ),
                items: [
                  for (final option in filtered)
                    DropdownMenuItem(
                      value: option.family,
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: option.family),
                      ),
                    ),
                ],
                onChanged: setFontFamily,
              )
            : DropdownMenu<String>(
                width: constraints.maxWidth,
                enableFilter: true,
                initialSelection: current,
                label: Text('settingsTerminalFont'.tr()),
                onSelected: setFontFamily,
                dropdownMenuEntries: [
                  for (final option in filtered)
                    DropdownMenuEntry(
                      value: option.family,
                      label: option.label,
                      labelWidget: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: option.family),
                      ),
                    ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fontDropdown,
            const SizedBox(height: 4),
            if (constraints.maxWidth < 420)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [fontHint, monospaceToggle],
              )
            else
              Row(
                children: [
                  Expanded(child: fontHint),
                  const SizedBox(width: 8),
                  monospaceToggle,
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TerminalThemeTile extends StatelessWidget {
  const _TerminalThemeTile({
    required this.mode,
    required this.theme,
    required this.onEdit,
  });

  final Brightness mode;
  final TerminalColorScheme theme;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final titleKey = mode == Brightness.light
        ? 'settingsTerminalThemeLight'
        : 'settingsTerminalThemeDark';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _TerminalPalettePreview(theme: theme),
      title: Text(titleKey.tr()),
      subtitle: const Text('settingsTerminalThemeHint').tr(),
      trailing: IconButton(
        tooltip: 'settingsTerminalThemeEdit'.tr(),
        onPressed: onEdit,
        icon: const Icon(Symbols.edit),
      ),
      onTap: onEdit,
    );
  }
}

class _TerminalPalettePreview extends StatelessWidget {
  const _TerminalPalettePreview({required this.theme, this.large = false});

  final TerminalColorScheme theme;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: large ? 120 : 64,
      height: large ? 88 : 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aa',
            style: TextStyle(
              color: theme.foreground,
              fontSize: large ? 16 : 11,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              children: [
                for (final color in theme.ansiColors)
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1.5),
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

class _TerminalThemeDialog extends StatefulWidget {
  const _TerminalThemeDialog({
    required this.brightness,
    required this.initialScheme,
  });

  final Brightness brightness;
  final TerminalColorScheme initialScheme;

  @override
  State<_TerminalThemeDialog> createState() => _TerminalThemeDialogState();
}

class _TerminalThemeDialogState extends State<_TerminalThemeDialog> {
  static const _ansiBaseLabels = [
    'terminalColorBlack',
    'terminalColorRed',
    'terminalColorGreen',
    'terminalColorYellow',
    'terminalColorBlue',
    'terminalColorMagenta',
    'terminalColorCyan',
    'terminalColorWhite',
  ];

  late TerminalColorScheme _scheme;

  @override
  void initState() {
    super.initState();
    _scheme = widget.initialScheme;
  }

  Future<void> _editColor(
    String label,
    Color current,
    ValueChanged<Color> apply,
  ) async {
    final updated = await showDialog<Color>(
      context: context,
      builder: (context) =>
          _ColorEditDialog(title: label, initialColor: current),
    );
    if (updated != null) setState(() => apply(updated));
  }

  void _setAnsi(int index, Color color) {
    final ansi = List<Color>.of(_scheme.ansiColors);
    ansi[index] = color;
    _scheme = _scheme.copyWith(ansiColors: ansi);
  }

  void _save() => Navigator.of(context).pop(_scheme);

  @override
  Widget build(BuildContext context) {
    final titleKey = widget.brightness == Brightness.light
        ? 'settingsTerminalThemeLight'
        : 'settingsTerminalThemeDark';
    final presetId = TerminalColorSchemes.all
        .where((scheme) => scheme.id == _scheme.id)
        .firstOrNull
        ?.id;

    return AlertDialog(
      title: Text(titleKey.tr()),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The floating label rises above the field; without this gap the
              // scroll view clips it to its bottom half.
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: presetId ?? 'custom',
                decoration: InputDecoration(
                  labelText: 'settingsTerminalThemePreset'.tr(),
                ),
                items: [
                  for (final scheme in TerminalColorSchemes.all)
                    DropdownMenuItem(
                      value: scheme.id,
                      child: Text(scheme.label),
                    ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('settingsTerminalThemeCustom'.tr()),
                  ),
                ],
                onChanged: (id) {
                  if (id == null || id == 'custom') return;
                  setState(() => _scheme = TerminalColorSchemes.byId(id));
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: _TerminalPalettePreview(theme: _scheme, large: true),
              ),
              const SizedBox(height: 16),
              _TerminalColorRow(
                label: 'settingsTerminalThemeBackground'.tr(),
                color: _scheme.background,
                onTap: () => _editColor(
                  'settingsTerminalThemeBackground'.tr(),
                  _scheme.background,
                  (color) => _scheme = _scheme.copyWith(background: color),
                ),
              ),
              _TerminalColorRow(
                label: 'settingsTerminalThemeForeground'.tr(),
                color: _scheme.foreground,
                onTap: () => _editColor(
                  'settingsTerminalThemeForeground'.tr(),
                  _scheme.foreground,
                  (color) => _scheme = _scheme.copyWith(foreground: color),
                ),
              ),
              _TerminalColorRow(
                label: 'settingsTerminalThemeCursor'.tr(),
                color: _scheme.cursor,
                onTap: () => _editColor(
                  'settingsTerminalThemeCursor'.tr(),
                  _scheme.cursor,
                  (color) => _scheme = _scheme.copyWith(cursor: color),
                ),
              ),
              _TerminalColorRow(
                label: 'settingsTerminalThemeSelection'.tr(),
                color: _scheme.selection,
                onTap: () => _editColor(
                  'settingsTerminalThemeSelection'.tr(),
                  _scheme.selection,
                  (color) => _scheme = _scheme.copyWith(selection: color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'settingsTerminalThemeNormal'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (var i = 0; i < 8; i++)
                _TerminalColorRow(
                  label: _ansiBaseLabels[i].tr(),
                  color: _scheme.ansiColors[i],
                  onTap: () => _editColor(
                    _ansiBaseLabels[i].tr(),
                    _scheme.ansiColors[i],
                    (color) => _setAnsi(i, color),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'settingsTerminalThemeBright'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (var i = 0; i < 8; i++)
                _TerminalColorRow(
                  label: 'terminalColorBright'.tr(
                    args: [_ansiBaseLabels[i].tr()],
                  ),
                  color: _scheme.ansiColors[i + 8],
                  onTap: () => _editColor(
                    'terminalColorBright'.tr(args: [_ansiBaseLabels[i].tr()]),
                    _scheme.ansiColors[i + 8],
                    (color) => _setAnsi(i + 8, color),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton(onPressed: _save, child: Text('settingsThemeSave'.tr())),
      ],
    );
  }
}

class _TerminalColorRow extends StatelessWidget {
  const _TerminalColorRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      title: Text(label),
      trailing: Text(
        _hexFor(color),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

class _ColorEditDialog extends StatefulWidget {
  const _ColorEditDialog({required this.title, required this.initialColor});

  final String title;
  final Color initialColor;

  @override
  State<_ColorEditDialog> createState() => _ColorEditDialogState();
}

class _ColorEditDialogState extends State<_ColorEditDialog> {
  late final TextEditingController _hexController;
  late int _red;
  late int _green;
  late int _blue;
  String? _colorError;

  @override
  void initState() {
    super.initState();
    final color = widget.initialColor;
    _red = color.r.toInt();
    _green = color.g.toInt();
    _blue = color.b.toInt();
    _hexController = TextEditingController(text: _hexFor(_color));
  }

  Color get _color => Color.fromARGB(255, _red, _green, _blue);

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateFromHex(String value) {
    final color = _colorFromHex(value);
    setState(() {
      _colorError = color == null ? 'settingsThemeInvalidColor'.tr() : null;
      if (color != null) {
        _red = color.r.toInt();
        _green = color.g.toInt();
        _blue = color.b.toInt();
      }
    });
  }

  void _updateColor(void Function() update) {
    setState(() {
      update();
      _colorError = null;
      _hexController.text = _hexFor(_color);
    });
  }

  void _save() {
    final color = _colorFromHex(_hexController.text);
    if (color == null) {
      setState(() => _colorError = 'settingsThemeInvalidColor'.tr());
      return;
    }
    Navigator.of(context).pop(color);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      maxLength: 7,
                      onChanged: _updateFromHex,
                      decoration: InputDecoration(
                        labelText: 'settingsThemeColor'.tr(),
                        hintText: '#0F766E',
                        errorText: _colorError,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'settingsThemeColorHint'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _ColorChannelSlider(
                label: 'R',
                value: _red,
                onChanged: (value) => _updateColor(() => _red = value),
              ),
              _ColorChannelSlider(
                label: 'G',
                value: _green,
                onChanged: (value) => _updateColor(() => _green = value),
              ),
              _ColorChannelSlider(
                label: 'B',
                value: _blue,
                onChanged: (value) => _updateColor(() => _blue = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton(onPressed: _save, child: Text('settingsThemeSave'.tr())),
      ],
    );
  }
}

class _ColorChannelSlider extends StatelessWidget {
  const _ColorChannelSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: '$value',
            onChanged: (value) => onChanged(value.round()),
          ),
        ),
        SizedBox(width: 28, child: Text('$value')),
      ],
    );
  }
}

String _hexFor(Color color) =>
    '#${color.r.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}${color.g.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}${color.b.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}';

Color? _colorFromHex(String value) {
  final hex = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF$hex', radix: 16));
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
  late final _localPublic = TextEditingController(
    text: _initial.localPublicKeyDirectory,
  );
  late final _remoteDir = TextEditingController(
    text: _initial.remoteKeyDirectory,
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
    _localPublic.dispose();
    _remoteDir.dispose();
    _remoteAuthorizedKeys.dispose();
    _sshConfigPath.dispose();
    super.dispose();
  }

  Future<void> _save(SshKeyStorageConfig config) =>
      ref.read(sshKeyStorageConfigProvider.notifier).save(config);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(sshKeyStorageConfigProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('settingsSshKeysHint'.tr(), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        DropdownButtonFormField<SshKeyType>(
          initialValue: config.defaultKeyType,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyDefaultType'.tr(),
          ),
          items: [
            for (final type in SshKeyType.values)
              DropdownMenuItem(value: type, child: Text(type.label)),
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
            helperText: 'settingsSshKeyLocalPrivateDirHint'.tr(),
          ),
          onChanged: (value) =>
              _save(config.copyWith(localPrivateKeyDirectory: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _localPublic,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyLocalPublicDir'.tr(),
            helperText: 'settingsSshKeyLocalPublicDirHint'.tr(),
          ),
          onChanged: (value) =>
              _save(config.copyWith(localPublicKeyDirectory: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remoteDir,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyRemoteDir'.tr(),
            helperText: 'settingsSshKeyRemoteDirHint'.tr(),
          ),
          onChanged: (value) =>
              _save(config.copyWith(remoteKeyDirectory: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remoteAuthorizedKeys,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyRemoteAuthorizedKeys'.tr(),
            helperText: 'settingsSshKeyRemoteAuthorizedKeysHint'.tr(),
          ),
          onChanged: (value) =>
              _save(config.copyWith(remoteAuthorizedKeysPath: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sshConfigPath,
          decoration: InputDecoration(
            labelText: 'settingsSshKeyConfigPath'.tr(),
            helperText: 'settingsSshKeyConfigPathHint'.tr(),
          ),
          onChanged: (value) => _save(config.copyWith(sshConfigPath: value)),
        ),
      ],
    );
  }
}
