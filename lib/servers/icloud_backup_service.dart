import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A vault archive found in the iCloud backup folder.
typedef ICloudBackup = ({DateTime modifiedAt, File file});

/// Vault backups in the user's iCloud Drive folder.
///
/// Files written under `~/Library/Mobile Documents/com~apple~CloudDocs` are
/// synced by the system, so no entitlements are needed. Only the newest
/// [keepNewest] archives are kept so the folder cannot grow forever.
class ICloudBackupService {
  ICloudBackupService({String? home})
    : _home = home ?? Platform.environment['HOME'];

  static const keepNewest = 10;
  static const archiveExtension = '.conduit';

  /// Extension written by releases before the Conduit rename; still listed
  /// and restorable.
  static const legacyArchiveExtension = '.mkb';

  static const archiveExtensions = [archiveExtension, legacyArchiveExtension];

  final String? _home;

  /// iCloud Drive's local folder, or null when iCloud Drive is off.
  String? get drivePath {
    final home = _home;
    if (home == null) return null;
    final root = '$home/Library/Mobile Documents/com~apple~CloudDocs';
    return Directory(root).existsSync() ? root : null;
  }

  Directory? get _backupDirectory {
    final root = drivePath;
    return root == null ? null : Directory('$root/Conduit');
  }

  /// Writes [archive] as [name] into the backup folder and prunes older
  /// archives. Throws [StateError] when iCloud Drive is unavailable.
  Future<void> write({required String name, required String archive}) async {
    final dir = _backupDirectory;
    if (dir == null) throw StateError('iCloud Drive is unavailable');
    await dir.create(recursive: true);
    await File('${dir.path}/$name').writeAsString(archive, flush: true);
    await _prune(dir);
  }

  /// Archives in the backup folder, newest first; empty when iCloud Drive
  /// is off or nothing has been backed up.
  Future<List<ICloudBackup>> list() async {
    final dir = _backupDirectory;
    if (dir == null || !await dir.exists()) return const [];
    return _listArchives(dir);
  }

  Future<List<ICloudBackup>> _listArchives(Directory dir) async {
    final backups = <ICloudBackup>[
      await for (final entity in dir.list())
        if (entity is File && archiveExtensions.any(entity.path.endsWith))
          (modifiedAt: await entity.lastModified(), file: entity),
    ];
    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<void> _prune(Directory dir) async {
    for (final backup in (await _listArchives(dir)).skip(keepNewest)) {
      try {
        await backup.file.delete();
      } catch (_) {
        // A file the system is still syncing can refuse deletion; the next
        // backup tries again.
      }
    }
  }
}

final icloudBackupServiceProvider = Provider<ICloudBackupService>(
  (ref) => ICloudBackupService(),
);
