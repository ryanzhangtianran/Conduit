import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Owns vault database files created by the user.
///
/// Vaults live in Conduit's private application-support storage: the macOS
/// sandbox does not retain access to user-selected folders across launches,
/// so vault files outside that directory cannot be managed.
class VaultFileStorage {
  static const _directoryName = 'vaults';
  static const _extension = '.conduit';
  final Uuid _uuid = const Uuid();
  final Set<String> _managedPaths = {};

  /// Returns the stable identity used for keychain entries.
  ///
  /// Internal vaults are identified by their generated filename rather than
  /// the absolute iOS sandbox path. External vaults retain their path because
  /// two external files may legitimately have the same filename.
  String vaultId(String path) =>
      _managedPaths.contains(File(path).absolute.path) ? fileName(path) : path;

  /// Converts a runtime path into the value safe to persist in preferences.
  ///
  /// Internal vaults need only their filename: iOS can change the application
  /// container prefix when installing an update.
  Future<String> persistentPath(String path) async {
    final absolute = File(path).absolute.path;
    return await isExternalPath(absolute) ? absolute : fileName(absolute);
  }

  /// Resolves a persisted vault reference against the current app container.
  ///
  /// Older versions persisted absolute paths. If such a path is stale after an
  /// iOS update, its filename still identifies the managed vault file.
  Future<String?> resolvePersistedPath(String value) async {
    final hasSeparator = value.contains('/') || value.contains('\\');
    if (!hasSeparator && _isVaultFile(value)) {
      final directory = await _vaultDirectory();
      final managed = File('${directory.path}/$value');
      if (await managed.exists()) {
        final path = managed.absolute.path;
        await isExternalPath(path);
        return path;
      }
    }

    final candidate = File(value);
    if (await candidate.exists()) {
      final path = candidate.absolute.path;
      await isExternalPath(path);
      return path;
    }

    if (_isVaultFile(value)) {
      final directory = await _vaultDirectory();
      final managed = File('${directory.path}/${fileName(value)}');
      if (await managed.exists()) {
        final path = managed.absolute.path;
        await isExternalPath(path);
        return path;
      }
    }
    return null;
  }

  /// Lists internal vault files even when their preference entry was lost.
  ///
  /// This recovers files left behind by the pre-fix startup path, which
  /// discarded stale absolute-path preferences after an iOS update.
  Future<List<String>> managedVaultPaths() async {
    final directory = await _vaultDirectory();
    final paths = <String>[];
    await for (final entity in directory.list()) {
      if (entity is File && _isVaultFile(entity.path)) {
        final path = entity.absolute.path;
        await isExternalPath(path);
        paths.add(path);
      }
    }
    paths.sort();
    return paths;
  }

  /// Creates a new vault file path in Conduit's private application-support
  /// storage.
  Future<String> createVaultPath({String? name}) async {
    final directory = await _vaultDirectory();
    final stem = _safeStem(fileName(name ?? 'Conduit vault'));
    return '${directory.path}/$stem-${_uuid.v4()}$_extension';
  }

  Future<void> deleteVault(String path) async {
    final file = File(path);
    if (!_isVaultFile(path) || !await file.exists()) {
      throw FileSystemException(
        'Only existing Conduit vault files can be deleted.',
        path,
      );
    }
    await file.delete();
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('$path$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }

  bool _isVaultFile(String path) {
    final lower = fileName(path).toLowerCase();
    return lower.endsWith('.conduit') ||
        lower.endsWith('.sqlite') ||
        lower.endsWith('.db');
  }

  Future<Directory> _vaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/$_directoryName').create(recursive: true);
  }

  Future<bool> isExternalPath(String path) async {
    final support = await getApplicationSupportDirectory();
    final external = !isInDirectory(path, '${support.path}/$_directoryName');
    if (!external) _managedPaths.add(File(path).absolute.path);
    return external;
  }

  /// The final path segment, tolerating both '/' and '\' separators.
  ///
  /// Managed vault paths are built with '/' while path_provider and
  /// FilePicker may report native '\' paths on Windows, so splitting on
  /// [Platform.pathSeparator] alone would return the whole path there.
  String fileName(String path) => path.split(RegExp(r'[/\\]')).last;

  /// Whether [path] points inside [directory], tolerant of '/' and '\'
  /// separators and of a trailing separator on [directory].
  bool isInDirectory(String path, String directory) {
    final normalizedPath = path.replaceAll('\\', '/');
    final normalizedDirectory = directory
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    return normalizedPath == normalizedDirectory ||
        normalizedPath.startsWith('$normalizedDirectory/');
  }

  String _safeStem(String value) {
    final withoutExtension = value.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final sanitized = withoutExtension.replaceAll(
      RegExp(r'[^a-zA-Z0-9 _-]'),
      '_',
    );
    return sanitized.trim().isEmpty ? 'Vault' : sanitized.trim();
  }
}
