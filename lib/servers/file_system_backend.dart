import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'package:conduit/shared/formatters.dart';

/// One directory entry as shown by the file manager or walked by a transfer.
class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.isFile,
    this.size,
  });

  final String name;
  final String path;
  final bool isDirectory;

  /// Regular file. Neither flag is set for sockets, devices or dangling links.
  final bool isFile;
  final int? size;
}

/// Sorts directories first, then names case-insensitively, in place.
void sortFileEntries(List<FileEntry> entries) {
  entries.sort((a, b) {
    final directoryOrder = (b.isDirectory ? 1 : 0) - (a.isDirectory ? 1 : 0);
    return directoryOrder != 0
        ? directoryOrder
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

/// A writable file handle. Unlike `IOSink`, [add] is awaited so remote
/// backends can apply back-pressure per chunk.
abstract class FileWriteSink {
  Future<void> add(List<int> chunk);
  Future<void> flush();
  Future<void> close();
}

/// The file-system operations the file manager and the transfer queue need,
/// implemented once for the local disk and once for an SFTP session so both
/// panes and every transfer direction share the same code.
abstract class FileSystemBackend {
  bool get isLocal;

  /// Path separator used by [join].
  String get separator;

  String join(String directory, String name);
  String parentOf(String path);
  String nameOf(String path);

  /// Resolves relative segments (and `.` on SFTP) to an absolute path.
  Future<String> absolute(String path);

  /// Lists [path] without `.` and `..`, unsorted.
  Future<List<FileEntry>> list(String path, {bool followLinks = true});

  /// `null` when nothing exists at [path].
  Future<FileEntry?> stat(String path);
  Future<bool> exists(String path) async => await stat(path) != null;
  Future<void> mkdir(String path);
  Future<void> rename(String from, String to);

  /// Removes a file, or a directory when [recursive] is set. Throws when the
  /// path is a non-empty directory and [recursive] is false.
  Future<void> remove(String path, {bool recursive = false});
  Stream<List<int>> openRead(String path);
  Future<FileWriteSink> openWrite(String path);

  /// Releases the underlying session; the backend is unusable afterwards.
  Future<void> close();
}

class LocalFileSystemBackend extends FileSystemBackend {
  LocalFileSystemBackend();

  @override
  bool get isLocal => true;

  @override
  String get separator => Platform.pathSeparator;

  @override
  String join(String directory, String name) {
    if (directory.endsWith(separator)) return '$directory$name';
    return '$directory$separator$name';
  }

  @override
  String parentOf(String path) => Directory(path).parent.path;

  @override
  String nameOf(String path) {
    final segments = Uri.file(path).pathSegments;
    return segments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => path,
    );
  }

  @override
  Future<String> absolute(String path) async => Directory(path).absolute.path;

  @override
  Future<List<FileEntry>> list(String path, {bool followLinks = true}) async {
    final entities = await Directory(
      path,
    ).list(followLinks: followLinks).toList();
    return [for (final entity in entities) _entryFor(entity)];
  }

  FileEntry _entryFor(FileSystemEntity entity, {int? size}) => FileEntry(
    name: nameOf(entity.path),
    path: entity.path,
    isDirectory: entity is Directory,
    isFile: entity is File,
    size: size,
  );

  @override
  Future<FileEntry?> stat(String path) async {
    final type = await FileSystemEntity.type(path);
    return switch (type) {
      FileSystemEntityType.notFound => null,
      FileSystemEntityType.directory => _entryFor(Directory(path)),
      FileSystemEntityType.file => _entryFor(
        File(path),
        size: await File(path).length(),
      ),
      _ => FileEntry(
        name: nameOf(path),
        path: path,
        isDirectory: false,
        isFile: false,
      ),
    };
  }

  @override
  Future<void> mkdir(String path) => Directory(path).create();

  @override
  Future<void> rename(String from, String to) async {
    if (await FileSystemEntity.isDirectory(from)) {
      await Directory(from).rename(to);
    } else {
      await File(from).rename(to);
    }
  }

  @override
  Future<void> remove(String path, {bool recursive = false}) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: recursive);
      case FileSystemEntityType.link:
        await Link(path).delete();
      default:
        await File(path).delete();
    }
  }

  @override
  Stream<List<int>> openRead(String path) => File(path).openRead();

  @override
  Future<FileWriteSink> openWrite(String path) async =>
      // Open eagerly so a missing directory fails here, inside the caller's
      // try/catch, instead of surfacing later on an IOSink's `done` future.
      _LocalWriteSink(await File(path).open(mode: FileMode.write));

  @override
  Future<void> close() async {}
}

class _LocalWriteSink implements FileWriteSink {
  _LocalWriteSink(this._file);

  final RandomAccessFile _file;

  @override
  Future<void> add(List<int> chunk) => _file.writeFrom(chunk);

  @override
  Future<void> flush() => _file.flush();

  @override
  Future<void> close() => _file.close();
}

class SftpFileSystemBackend extends FileSystemBackend {
  SftpFileSystemBackend(this._sftp);

  final SftpClient _sftp;

  static const _readChunkSize = 64 * 1024;
  static const _maxPendingReads = 4;

  @override
  bool get isLocal => false;

  @override
  String get separator => '/';

  @override
  String join(String directory, String name) => joinRemotePath(directory, name);

  @override
  String parentOf(String path) => parentRemotePath(path);

  @override
  String nameOf(String path) {
    final normalized = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  @override
  Future<String> absolute(String path) => _sftp.absolute(path);

  @override
  Future<List<FileEntry>> list(String path, {bool followLinks = true}) async {
    final names = await _sftp.listdir(path);
    return [
      for (final entry in names)
        if (entry.filename != '.' && entry.filename != '..')
          FileEntry(
            name: entry.filename,
            path: join(path, entry.filename),
            isDirectory: entry.attr.isDirectory,
            isFile: entry.attr.isFile,
            size: entry.attr.size,
          ),
    ];
  }

  @override
  Future<FileEntry?> stat(String path) async {
    final SftpFileAttrs attrs;
    try {
      attrs = await _sftp.stat(path);
    } on SftpStatusError {
      return null;
    }
    return FileEntry(
      name: nameOf(path),
      path: path,
      isDirectory: attrs.isDirectory,
      isFile: attrs.isFile,
      size: attrs.size,
    );
  }

  @override
  Future<void> mkdir(String path) => _sftp.mkdir(path);

  @override
  Future<void> rename(String from, String to) => _sftp.rename(from, to);

  @override
  Future<void> remove(String path, {bool recursive = false}) async {
    final entry = await stat(path);
    if (entry == null) return;
    if (!entry.isDirectory) {
      await _sftp.remove(path);
      return;
    }
    if (recursive) {
      for (final child in await list(path)) {
        await remove(child.path, recursive: true);
      }
    }
    await _sftp.rmdir(path);
  }

  @override
  Stream<List<int>> openRead(String path) async* {
    final file = await _sftp.open(path, mode: SftpFileOpenMode.read);
    try {
      yield* file.read(
        chunkSize: _readChunkSize,
        maxPendingRequests: _maxPendingReads,
      );
    } finally {
      await file.close();
    }
  }

  @override
  Future<FileWriteSink> openWrite(String path) async {
    final file = await _sftp.open(
      path,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    return _SftpWriteSink(file);
  }

  @override
  Future<void> close() => _sftp.close();
}

class _SftpWriteSink implements FileWriteSink {
  _SftpWriteSink(this._file);

  final SftpFile _file;
  var _offset = 0;

  @override
  Future<void> add(List<int> chunk) async {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    await _file.writeBytes(bytes, offset: _offset);
    _offset += bytes.length;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() => _file.close();
}
