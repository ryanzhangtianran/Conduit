import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/data/local/app_database.dart';
import 'database_backup_service.dart';
import 'server_providers.dart';
import 'vault_service.dart';

/// Where an imported vault archive lands.
enum VaultImportDestination { newVault, replaceCurrent }

/// Restores `.conduit` vault archives (and legacy `.mkb`): either into a freshly created vault file
/// that then becomes the active vault, or over the current vault's data.
class VaultImportService {
  VaultImportService(this._ref);

  final Ref _ref;

  /// Decrypts the archive at [archivePath] with [archivePassword] and
  /// imports it into the active vault (which must be unlocked).
  Future<void> importIntoCurrentVault({
    required String archivePath,
    required String archivePassword,
  }) async {
    final archive = await File(archivePath).readAsString();
    await DatabaseBackupService(
      _ref.read(databaseProvider),
      _ref.read(vaultServiceProvider),
    ).importArchive(archive, archivePassword);
  }

  /// Creates a new vault file protected by [vaultPassword], imports the
  /// archive into it and switches the app to that vault.
  Future<void> importIntoNewVault({
    required String archivePath,
    required String archivePassword,
    required String vaultPassword,
  }) async {
    final storage = _ref.read(vaultFileStorageProvider);
    final vaultPath = await storage.createVaultPath(name: archivePath);
    await storage.persistentPath(vaultPath);
    final database = AppDatabase(filePath: vaultPath);
    final vault = VaultService(database, vaultId: storage.vaultId(vaultPath));
    try {
      await vault.create(vaultPassword);
      final archive = await File(archivePath).readAsString();
      await DatabaseBackupService(
        database,
        vault,
      ).importArchive(archive, archivePassword);
    } finally {
      await database.close();
    }
    await _ref.read(activeVaultFileProvider.notifier).select(vaultPath);
  }
}

final vaultImportServiceProvider = Provider<VaultImportService>(
  VaultImportService.new,
);
