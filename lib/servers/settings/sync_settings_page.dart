import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'package:conduit/shared/presentation/password_prompt.dart';
import '../connection_export_service.dart';
import '../connection_import_service.dart';
import '../connection_import_sheet.dart';
import '../database_backup_service.dart';
import '../icloud_backup_service.dart';
import '../server_providers.dart';
import '../ssh_config_bulk.dart';
import '../ssh_key_preferences.dart';
import '../vault_import.dart';
import '../vault_service.dart';
import 'settings_section.dart';

enum _ConnectionsExportFormat { jsonRedacted, jsonProtected, csv }

/// Moving data in and out: connection files, vault archives, the local
/// OpenSSH config and iCloud backups.
@RoutePage()
class SyncSettingsPage extends ConsumerWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsPageBody(
      children: [
        SettingsSection(
          titleKey: 'settingsImportSection',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ActionTile(
                icon: Symbols.upload_file,
                titleKey: 'settingsConnectionsImport',
                hintKey: 'settingsConnectionsImportHint',
                onTap: () => _importConnections(context, ref),
              ),
              _ActionTile(
                icon: Symbols.unarchive,
                titleKey: 'settingsImportData',
                hintKey: 'settingsImportDataHint',
                onTap: () => _importDatabase(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsSection(
          titleKey: 'settingsExportSection',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ActionTile(
                icon: Symbols.dns,
                titleKey: 'settingsConnectionsExport',
                hintKey: 'settingsConnectionsExportHint',
                onTap: () => _exportConnections(context, ref),
              ),
              _ActionTile(
                icon: Symbols.archive,
                titleKey: 'settingsExportData',
                hintKey: 'settingsExportDataHint',
                onTap: () => _exportDatabase(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsSection(
          titleKey: 'settingsSshConfigSyncSection',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ActionTile(
                icon: Symbols.description,
                titleKey: 'settingsConnectionsExportSshConfig',
                hintKey: 'settingsConnectionsExportSshConfigHint',
                onTap: () => syncServersToSshConfig(context, ref),
              ),
              _ActionTile(
                icon: Symbols.terminal,
                titleKey: 'settingsConnectionsImportSshConfig',
                hintKey: 'settingsConnectionsImportSshConfigHint',
                onTap: () => _importFromLocalSshConfig(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsSection(
          titleKey: 'settingsICloud',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsPasswordTile(
                icon: Symbols.cloud_upload,
                titleKey: 'settingsICloudBackup',
                hintKey: 'settingsICloudBackupHint',
                actionKey: 'settingsICloudBackup',
                onSubmit: (password) => _backupToICloud(ref, password),
              ),
              _ActionTile(
                icon: Symbols.cloud_download,
                titleKey: 'settingsICloudRestore',
                hintKey: 'settingsICloudRestoreHint',
                onTap: () => _restoreFromICloud(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _archiveName(WidgetRef ref) =>
      'conduit-${exportFileNamePrefix(ref)}-${exportTimestamp()}'
      '${ICloudBackupService.archiveExtension}';

  /// The vault archive, once the user has proven the vault password.
  Future<String?> _exportArchive(WidgetRef ref, String password) async {
    final vault = ref.read(vaultServiceProvider);
    if (!await vault.unlockWithPassword(password)) {
      showSettingsMessage('settingsVaultPasswordInvalid'.tr());
      return null;
    }
    return DatabaseBackupService(
      ref.read(databaseProvider),
      vault,
    ).exportArchive(password);
  }

  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    final password = await showPasswordPrompt(
      context,
      titleKey: 'settingsExportPasswordTitle',
      hintKey: 'settingsExportVaultPasswordHint',
      actionKey: 'settingsExportData',
      confirm: true,
    );
    if (password == null || !context.mounted) return;
    try {
      final archive = await _exportArchive(ref, password);
      if (archive == null) return;
      final path = await FilePicker.saveFile(
        dialogTitle: 'settingsExportData'.tr(),
        fileName: _archiveName(ref),
        type: FileType.custom,
        allowedExtensions: const ['conduit'],
      );
      if (path == null) return;
      await File(path).writeAsString(archive);
      showSettingsMessage('settingsExportSuccess'.tr());
    } catch (error) {
      showSettingsMessage('settingsBackupError'.tr(args: [error.toString()]));
    }
  }

  Future<bool> _backupToICloud(WidgetRef ref, String password) async {
    final backups = ref.read(icloudBackupServiceProvider);
    if (backups.drivePath == null) {
      showSettingsMessage('settingsICloudUnavailable'.tr());
      return false;
    }
    try {
      final archive = await _exportArchive(ref, password);
      if (archive == null) return false;
      final name = _archiveName(ref);
      await backups.write(name: name, archive: archive);
      showSettingsMessage('settingsICloudBackupSuccess'.tr(args: [name]));
      return true;
    } catch (error) {
      showSettingsMessage('settingsBackupError'.tr(args: [error.toString()]));
      return false;
    }
  }

  Future<void> _restoreFromICloud(BuildContext context, WidgetRef ref) async {
    final backups = ref.read(icloudBackupServiceProvider);
    if (backups.drivePath == null) {
      showSettingsMessage('settingsICloudUnavailable'.tr());
      return;
    }
    final archives = await backups.list();
    if (archives.isEmpty) {
      showSettingsMessage('settingsICloudNoBackups'.tr());
      return;
    }
    if (!context.mounted) return;
    final picked = await showConduitChoiceDialog<String>(
      context,
      title: 'settingsICloudChooseBackup'.tr(),
      initial: archives.first.file.path,
      choices: [
        for (final backup in archives)
          ConduitChoice(
            backup.file.path,
            backup.file.uri.pathSegments.last,
            hint: _formatModified(backup.modifiedAt),
          ),
      ],
    );
    if (picked == null || !context.mounted) return;
    await _importDatabaseFromPath(context, ref, picked);
  }

  static String _formatModified(DateTime modified) =>
      '${modified.year}-'
      '${modified.month.toString().padLeft(2, '0')}-'
      '${modified.day.toString().padLeft(2, '0')} '
      '${modified.hour.toString().padLeft(2, '0')}:'
      '${modified.minute.toString().padLeft(2, '0')}';

  Future<void> _importDatabase(BuildContext context, WidgetRef ref) async {
    final selection = await FilePicker.pickFiles(
      dialogTitle: 'settingsImportData'.tr(),
      type: FileType.custom,
      allowedExtensions: const ['conduit', 'mkb'],
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
    final password = await showPasswordPrompt(
      context,
      titleKey: 'settingsImportPasswordTitle',
      hintKey: 'settingsImportVaultPasswordHint',
      actionKey: 'settingsImportData',
    );
    if (password == null || !context.mounted) return;

    final destination = await showConduitChoiceDialog<VaultImportDestination>(
      context,
      title: 'settingsImportDestinationTitle'.tr(),
      initial: VaultImportDestination.newVault,
      choices: [
        ConduitChoice(
          VaultImportDestination.newVault,
          'settingsImportNewVault'.tr(),
          hint: 'settingsImportNewVaultHint'.tr(),
        ),
        ConduitChoice(
          VaultImportDestination.replaceCurrent,
          'settingsImportReplaceCurrent'.tr(),
          hint: 'settingsImportReplaceCurrentHint'.tr(),
        ),
      ],
    );
    if (destination == null || !context.mounted) return;

    final importer = ref.read(vaultImportServiceProvider);
    try {
      switch (destination) {
        case VaultImportDestination.replaceCurrent:
          final confirmed = await showConduitConfirmAlert(
            'settingsImportConfirmDescription'.tr(),
            'settingsImportConfirmTitle'.tr(),
            icon: Symbols.warning,
            isDanger: true,
          );
          if (!confirmed) return;
          await importer.importIntoCurrentVault(
            archivePath: path,
            archivePassword: password,
          );
        case VaultImportDestination.newVault:
          final vaultPassword = await showPasswordPrompt(
            context,
            titleKey: 'settingsImportNewVaultPasswordTitle',
            hintKey: 'settingsImportNewVaultPasswordHint',
            actionKey: 'vaultCreateAction',
            confirm: true,
          );
          if (vaultPassword == null) return;
          await importer.importIntoNewVault(
            archivePath: path,
            archivePassword: password,
            vaultPassword: vaultPassword,
          );
      }
      showSettingsMessage('settingsImportSuccess'.tr());
    } catch (error) {
      showSettingsMessage('settingsBackupError'.tr(args: [error.toString()]));
    }
  }

  Future<void> _exportConnections(BuildContext context, WidgetRef ref) async {
    final format = await showConduitChoiceDialog<_ConnectionsExportFormat>(
      context,
      title: 'settingsConnectionsExportTitle'.tr(),
      initial: _ConnectionsExportFormat.jsonRedacted,
      choices: [
        ConduitChoice(
          _ConnectionsExportFormat.jsonRedacted,
          'settingsConnectionsFormatJsonRedacted'.tr(),
          hint: 'settingsConnectionsFormatJsonRedactedHint'.tr(),
        ),
        ConduitChoice(
          _ConnectionsExportFormat.jsonProtected,
          'settingsConnectionsFormatJsonProtected'.tr(),
          hint: 'settingsConnectionsFormatJsonProtectedHint'.tr(),
        ),
        ConduitChoice(
          _ConnectionsExportFormat.csv,
          'settingsConnectionsFormatCsv'.tr(),
          hint: 'settingsConnectionsFormatCsvHint'.tr(),
        ),
      ],
    );
    if (format == null || !context.mounted) return;

    final extension = switch (format) {
      _ConnectionsExportFormat.csv => 'csv',
      _ => 'json',
    };
    final fileName =
        'conduit-connections-${exportFileNamePrefix(ref)}-${exportTimestamp()}.$extension';
    String? passphrase;
    if (format == _ConnectionsExportFormat.jsonProtected) {
      passphrase = await showPasswordPrompt(
        context,
        titleKey: 'settingsConnectionsPasswordTitle',
        hintKey: 'settingsConnectionsPasswordHint',
        actionKey: 'settingsConnectionsExportAction',
        confirm: true,
      );
      if (passphrase == null || !context.mounted) return;
    }

    final path = await FilePicker.saveFile(
      dialogTitle: 'settingsConnectionsExportTitle'.tr(),
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (path == null) return;

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
      showSettingsMessage('settingsConnectionsExportSuccess'.tr());
    } on VaultLockedException {
      showSettingsMessage('settingsConnectionsVaultLocked'.tr());
    } catch (error) {
      showSettingsMessage(
        'settingsConnectionsExportError'.tr(args: [error.toString()]),
      );
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
      showSettingsMessage('assetsSshConfigEmpty'.tr());
      return;
    }
    if (!context.mounted) return;
    await _runConnectionsImport(context, ref, [path]);
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
      requestPassphrase: () => showPasswordPrompt(
        context,
        titleKey: 'settingsConnectionsImportPasswordTitle',
        hintKey: 'settingsConnectionsImportPasswordHint',
        actionKey: 'settingsConnectionsImportAction',
      ),
    );
    if (!context.mounted || preview.aborted) return;

    if (preview.isEmpty) {
      showSettingsMessage(
        preview.firstError is ConnectionSecretsPassphraseException
            ? 'settingsConnectionsImportWrongPassphrase'.tr()
            : 'settingsConnectionsImportError'.tr(
                args: [
                  preview.firstError?.toString() ??
                      'settingsConnectionsImportEmpty'.tr(),
                ],
              ),
      );
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
    if (selected == null || selected.isEmpty) return;

    try {
      final result = await service.import(selected);
      showSettingsMessage(
        'settingsConnectionsImportSuccess'.tr(args: ['${result.created}']),
      );
    } on Exception catch (error) {
      showSettingsMessage(
        'settingsConnectionsImportError'.tr(args: [error.toString()]),
      );
    }
  }
}

/// A tappable row that starts an import or export.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.titleKey,
    required this.hintKey,
    required this.onTap,
  });

  final IconData icon;
  final String titleKey;
  final String hintKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: settingsTilePadding,
    leading: Icon(icon),
    title: Text(titleKey).tr(),
    subtitle: Text(hintKey).tr(),
    trailing: const Icon(Symbols.chevron_right),
    onTap: onTap,
  );
}
