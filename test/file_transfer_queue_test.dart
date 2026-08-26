import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/servers/file_system_backend.dart';
import 'package:conduit/servers/file_transfer_queue.dart';
import 'package:conduit/servers/transfer_conflict_preferences.dart';
import 'package:conduit/shared/presentation/task_progress_model.dart';

/// Local backend that hands out small chunks slowly so tests can pause and
/// cancel a transfer while it is in flight.
class _SlowBackend extends LocalFileSystemBackend {
  _SlowBackend({this.onChunk});

  static const chunkSize = 1024;
  final FutureOr<void> Function(int chunkIndex)? onChunk;
  var chunksRead = 0;

  @override
  Stream<List<int>> openRead(String path) async* {
    final bytes = await File(path).readAsBytes();
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, bytes.length);
      await onChunk?.call(chunksRead);
      chunksRead += 1;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      yield bytes.sublist(offset, end);
    }
  }
}

void main() {
  late Directory root;
  late ProviderContainer container;
  late TaskProgressNotifier progress;
  var mode = TransferConflictMode.rename;
  var choice = TransferConflictChoice.skip;
  late List<TransferNotification> notifications;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('conduit-queue-');
    container = ProviderContainer();
    progress = container.read(taskProgressProvider.notifier);
    mode = TransferConflictMode.rename;
    choice = TransferConflictChoice.skip;
    notifications = [];
  });

  tearDown(() async {
    container.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  FileTransferQueue queueWith(FileSystemBackend backend) => FileTransferQueue(
    progress: () => progress,
    conflictMode: () => mode,
    openBackend: (_) async => backend,
    askConflict: (_) async => choice,
    notify: notifications.add,
  );

  String p(String name) => '${root.path}${Platform.pathSeparator}$name';

  Future<File> writeFile(String name, int size) async {
    final file = File(p(name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.generate(size, (i) => i % 251));
    return file;
  }

  FileTransferRequest request(
    String name, {
    required bool isDirectory,
    String destination = 'dest',
    bool deleteSource = false,
    bool notify = true,
    int? totalBytes,
  }) => FileTransferRequest(
    title: 'copy $name',
    source: const TransferEndpoint.local(),
    sourcePath: p(name),
    name: name,
    isDirectory: isDirectory,
    destination: const TransferEndpoint.local(),
    destinationDirectory: p(destination),
    totalBytes: totalBytes,
    deleteSourceOnSuccess: deleteSource,
    notify: notify,
  );

  String activeTaskId() =>
      container.read(taskProgressProvider).firstWhere((t) => t.isActive).id;

  group('copyTree', () {
    test('copies a file and reports cumulative progress', () async {
      final backend = LocalFileSystemBackend();
      final source = await writeFile('src.bin', 300 * 1024);
      final reported = <int>[];
      final total = await copyTree(
        backend,
        source.path,
        backend,
        p('out.bin'),
        isDirectory: false,
        onProgress: reported.add,
      );
      expect(total, 300 * 1024);
      expect(reported.last, 300 * 1024);
      expect(reported, orderedEquals([...reported]..sort()));
      expect(
        await File(p('out.bin')).readAsBytes(),
        await source.readAsBytes(),
      );
    });

    test('copies a directory tree recursively', () async {
      final backend = LocalFileSystemBackend();
      await writeFile('tree/a.txt', 10);
      await writeFile('tree/sub/b.txt', 20);
      await Directory(p('tree/empty')).create();
      final total = await copyTree(
        backend,
        p('tree'),
        backend,
        p('copy'),
        isDirectory: true,
      );
      expect(total, 30);
      expect(await File(p('copy/a.txt')).length(), 10);
      expect(await File(p('copy/sub/b.txt')).length(), 20);
      expect(await Directory(p('copy/empty')).exists(), isTrue);
    });
  });

  group('FileTransferQueue', () {
    test('runs transfers serially and notifies completion once', () async {
      final queue = queueWith(LocalFileSystemBackend());
      await writeFile('one.txt', 100);
      await writeFile('two.txt', 100);
      await Directory(p('dest')).create();
      final first = queue.enqueue(request('one.txt', isDirectory: false));
      final second = queue.enqueue(request('two.txt', isDirectory: false));
      // The first transfer starts synchronously; the second waits its turn.
      expect(container.read(taskProgressProvider).map((t) => t.status), [
        TaskProgressStatus.inProgress,
        TaskProgressStatus.queued,
      ]);
      expect(await first, TaskProgressStatus.completed);
      expect(await second, TaskProgressStatus.completed);
      expect(await File(p('dest/one.txt')).exists(), isTrue);
      expect(await File(p('dest/two.txt')).exists(), isTrue);
      expect(notifications.where((n) => !n.isError), hasLength(2));
      expect(queue.isIdle, isTrue);
    });

    test('rename mode keeps both copies', () async {
      final queue = queueWith(LocalFileSystemBackend());
      await writeFile('a.txt', 10);
      await writeFile('dest/a.txt', 5);
      await queue.enqueue(request('a.txt', isDirectory: false));
      expect(await File(p('dest/a.txt')).length(), 5);
      expect(await File(p('dest/a (1).txt')).length(), 10);
    });

    test('ask mode skip completes quietly without writing', () async {
      final queue = queueWith(LocalFileSystemBackend());
      mode = TransferConflictMode.ask;
      choice = TransferConflictChoice.skip;
      await writeFile('a.txt', 10);
      await writeFile('dest/a.txt', 5);
      final status = await queue.enqueue(request('a.txt', isDirectory: false));
      expect(status, TaskProgressStatus.completed);
      expect(await File(p('dest/a.txt')).length(), 5);
      expect(await Directory(p('dest')).list().length, 1);
      expect(notifications, isEmpty);
    });

    test('overwrite replaces the destination after a full copy', () async {
      final queue = queueWith(LocalFileSystemBackend());
      mode = TransferConflictMode.overwrite;
      await writeFile('tree/a.txt', 10);
      await writeFile('dest/tree/old.txt', 5);
      await queue.enqueue(request('tree', isDirectory: true));
      expect(await File(p('dest/tree/a.txt')).exists(), isTrue);
      expect(await File(p('dest/tree/old.txt')).exists(), isFalse);
      // No partial sibling left behind.
      expect(await Directory(p('dest')).list().length, 1);
    });

    test('cancelling an overwrite keeps the original untouched', () async {
      mode = TransferConflictMode.overwrite;
      await writeFile('big.bin', 64 * 1024);
      await writeFile('dest/big.bin', 7);
      late FileTransferQueue queue;
      final backend = _SlowBackend(
        onChunk: (index) async {
          if (index == 3) await progress.cancel(activeTaskId());
        },
      );
      queue = queueWith(backend);
      final status = await queue.enqueue(
        request('big.bin', isDirectory: false, totalBytes: 64 * 1024),
      );
      expect(status, TaskProgressStatus.canceled);
      expect(await File(p('dest/big.bin')).length(), 7);
      expect(await Directory(p('dest')).list().length, 1);
      expect(
        container.read(taskProgressProvider).single.status,
        TaskProgressStatus.canceled,
      );
    });

    test('cancelling a fresh copy removes the partial file', () async {
      await writeFile('big.bin', 64 * 1024);
      await Directory(p('dest')).create();
      final backend = _SlowBackend(
        onChunk: (index) async {
          if (index == 2) await progress.cancel(activeTaskId());
        },
      );
      final status = await queueWith(
        backend,
      ).enqueue(request('big.bin', isDirectory: false));
      expect(status, TaskProgressStatus.canceled);
      expect(await File(p('dest/big.bin')).exists(), isFalse);
      expect(backend.chunksRead, lessThan(10));
    });

    test('pause stops reading until resumed', () async {
      await writeFile('big.bin', 16 * 1024);
      await Directory(p('dest')).create();
      final backend = _SlowBackend(
        onChunk: (index) async {
          if (index == 2) await progress.pause(activeTaskId());
        },
      );
      final done = queueWith(
        backend,
      ).enqueue(request('big.bin', isDirectory: false));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final readWhilePaused = backend.chunksRead;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(backend.chunksRead, readWhilePaused);
      expect(
        container.read(taskProgressProvider).single.status,
        TaskProgressStatus.paused,
      );
      await progress.resume(activeTaskId());
      expect(await done, TaskProgressStatus.completed);
      expect(await File(p('dest/big.bin')).length(), 16 * 1024);
    });

    test('deleteSourceOnSuccess removes the source after copying', () async {
      final queue = queueWith(LocalFileSystemBackend());
      await writeFile('tree/a.txt', 10);
      await Directory(p('dest')).create();
      await queue.enqueue(
        request('tree', isDirectory: true, deleteSource: true),
      );
      expect(await Directory(p('tree')).exists(), isFalse);
      expect(await File(p('dest/tree/a.txt')).exists(), isTrue);
    });

    test(
      'a failed transfer is reported exactly once even with notify off',
      () async {
        final queue = queueWith(LocalFileSystemBackend());
        final status = await queue.enqueue(
          request('missing.txt', isDirectory: false, notify: false),
        );
        expect(status, TaskProgressStatus.failed);
        expect(notifications, hasLength(1));
        expect(notifications.single.isError, isTrue);
        expect(
          container.read(taskProgressProvider).single.status,
          TaskProgressStatus.failed,
        );
      },
    );

    test('refuses to copy a folder into itself', () async {
      final queue = queueWith(LocalFileSystemBackend());
      await writeFile('tree/a.txt', 10);
      final status = await queue.enqueue(
        request('tree', isDirectory: true, destination: 'tree'),
      );
      expect(status, TaskProgressStatus.failed);
      expect(await Directory(p('tree')).list().length, 1);
    });
  });
}
