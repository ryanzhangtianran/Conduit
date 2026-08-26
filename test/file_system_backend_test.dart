import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/file_system_backend.dart';

void main() {
  late Directory root;
  late LocalFileSystemBackend backend;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('conduit-backend-');
    backend = LocalFileSystemBackend();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  String path(String name) => backend.join(root.path, name);

  test('path helpers', () {
    expect(backend.isLocal, isTrue);
    expect(backend.join('/a', 'b'), '/a${backend.separator}b');
    expect(backend.parentOf(path('x')), root.path);
    expect(backend.nameOf(path('file.txt')), 'file.txt');
  });

  test('mkdir, exists and stat', () async {
    expect(await backend.exists(path('dir')), isFalse);
    expect(await backend.stat(path('dir')), isNull);
    await backend.mkdir(path('dir'));
    final entry = await backend.stat(path('dir'));
    expect(entry, isNotNull);
    expect(entry!.isDirectory, isTrue);
    expect(entry.isFile, isFalse);
    expect(entry.name, 'dir');
  });

  test('write, read and stat a file', () async {
    final sink = await backend.openWrite(path('a.txt'));
    await sink.add(utf8.encode('hello '));
    await sink.flush();
    await sink.add(utf8.encode('world'));
    await sink.close();

    final bytes = await backend
        .openRead(path('a.txt'))
        .expand((c) => c)
        .toList();
    expect(utf8.decode(bytes), 'hello world');
    final entry = await backend.stat(path('a.txt'));
    expect(entry!.isFile, isTrue);
    expect(entry.size, 11);
  });

  test('list excludes nothing and sorts directories first', () async {
    await backend.mkdir(path('zeta'));
    await File(path('Alpha.txt')).writeAsString('a');
    await File(path('beta.txt')).writeAsString('b');
    await backend.mkdir(path('Gamma'));

    final entries = await backend.list(root.path);
    sortFileEntries(entries);
    expect(entries.map((e) => e.name), [
      'Gamma',
      'zeta',
      'Alpha.txt',
      'beta.txt',
    ]);
    expect(entries.first.path, path('Gamma'));
  });

  test('rename moves files and directories', () async {
    await File(path('a.txt')).writeAsString('a');
    await backend.rename(path('a.txt'), path('b.txt'));
    expect(await backend.exists(path('a.txt')), isFalse);
    expect(await backend.exists(path('b.txt')), isTrue);

    await backend.mkdir(path('d1'));
    await backend.rename(path('d1'), path('d2'));
    expect((await backend.stat(path('d2')))!.isDirectory, isTrue);
  });

  test('remove handles files, empty and recursive directories', () async {
    await File(path('a.txt')).writeAsString('a');
    await backend.remove(path('a.txt'));
    expect(await backend.exists(path('a.txt')), isFalse);

    await backend.mkdir(path('tree'));
    await File(path('tree/child.txt')).writeAsString('c');
    await expectLater(
      backend.remove(path('tree')),
      throwsA(isA<FileSystemException>()),
    );
    await backend.remove(path('tree'), recursive: true);
    expect(await backend.exists(path('tree')), isFalse);

    // Missing paths are a no-op rather than an error.
    await backend.remove(path('missing'), recursive: true);
  });
}
