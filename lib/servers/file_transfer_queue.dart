import 'dart:async';
import 'dart:collection';

import 'package:easy_localization/easy_localization.dart';

import 'package:conduit/shared/presentation/task_progress_model.dart';
import 'file_system_backend.dart';
import 'transfer_conflict_preferences.dart';

/// Where a transfer reads from or writes to: the local disk or a server.
class TransferEndpoint {
  const TransferEndpoint.local() : serverId = null;
  const TransferEndpoint.server(int this.serverId);

  final int? serverId;

  bool get isLocal => serverId == null;

  @override
  bool operator ==(Object other) =>
      other is TransferEndpoint && other.serverId == serverId;

  @override
  int get hashCode => serverId.hashCode;
}

class TransferCancelled implements Exception {
  const TransferCancelled();
}

/// Thrown inside a transfer when the user chose to skip the conflicting entry
/// in ask mode. The transfer completes quietly instead of failing.
class TransferSkipped implements Exception {
  const TransferSkipped();
}

/// Per-conflict choice when the transfer conflict mode is [ask].
enum TransferConflictChoice { overwrite, keepBoth, skip }

/// Pause/cancel switch checked between chunks of a running transfer.
class TransferController {
  var _isPaused = false;
  var _isCancelled = false;
  Completer<void>? _resumeCompleter;

  bool get isCancelled => _isCancelled;
  bool get isPaused => _isPaused;

  void pause() {
    if (_isCancelled || _isPaused) return;
    _isPaused = true;
    _resumeCompleter = Completer<void>();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    resume();
  }

  Future<void> waitIfPaused() async {
    throwIfCancelled();
    final completer = _resumeCompleter;
    if (_isPaused && completer != null) await completer.future;
    throwIfCancelled();
  }

  void throwIfCancelled() {
    if (_isCancelled) throw const TransferCancelled();
  }
}

/// One entry to copy (or move) from [source] into [destinationDirectory].
class FileTransferRequest {
  const FileTransferRequest({
    required this.title,
    required this.source,
    required this.sourcePath,
    required this.name,
    required this.isDirectory,
    required this.destination,
    required this.destinationDirectory,
    this.totalBytes,
    this.deleteSourceOnSuccess = false,
    this.notify = true,
    this.onFinish,
  });

  final String title;
  final TransferEndpoint source;
  final String sourcePath;
  final String name;
  final bool isDirectory;
  final TransferEndpoint destination;
  final String destinationDirectory;

  /// Known size for single files; `null` shows indeterminate progress.
  final int? totalBytes;

  /// Removes the source after a successful copy (cut & paste).
  final bool deleteSourceOnSuccess;

  /// Whether to announce completion. Failures are always announced once.
  final bool notify;

  /// Runs after the transfer ends in any state (e.g. to release a
  /// security-scoped bookmark).
  final Future<void> Function()? onFinish;
}

/// Flush written data every ~1 MiB so a cancelled transfer leaves a bounded
/// amount of unflushed bytes and the OS write cache stays small.
const int transferFlushInterval = 1024 * 1024;

/// Copies a file or directory tree between any two backends, streaming each
/// file in chunks. Returns the cumulative byte count (starting from
/// [transferredBytes]) so recursive calls report a single running total.
Future<int> copyTree(
  FileSystemBackend source,
  String sourcePath,
  FileSystemBackend destination,
  String destinationPath, {
  required bool isDirectory,
  TransferController? controller,
  void Function(int transferredBytes)? onProgress,
  int transferredBytes = 0,
}) async {
  await controller?.waitIfPaused();
  if (!isDirectory) {
    final sink = await destination.openWrite(destinationPath);
    var sinceFlush = 0;
    try {
      await for (final chunk in source.openRead(sourcePath)) {
        await controller?.waitIfPaused();
        await sink.add(chunk);
        transferredBytes += chunk.length;
        sinceFlush += chunk.length;
        onProgress?.call(transferredBytes);
        if (sinceFlush >= transferFlushInterval) {
          sinceFlush = 0;
          await sink.flush();
        }
      }
    } finally {
      await sink.close();
    }
    return transferredBytes;
  }

  await destination.mkdir(destinationPath);
  for (final child in await source.list(sourcePath, followLinks: false)) {
    if (!child.isDirectory && !child.isFile) continue;
    transferredBytes = await copyTree(
      source,
      child.path,
      destination,
      destination.join(destinationPath, child.name),
      isDirectory: child.isDirectory,
      controller: controller,
      onProgress: onProgress,
      transferredBytes: transferredBytes,
    );
  }
  return transferredBytes;
}

/// Removes a file or a whole directory tree; no-op when nothing exists.
Future<void> removeTree(FileSystemBackend backend, String path) =>
    backend.remove(path, recursive: true);

/// Returns `directory/name`, or `directory/name (n).ext` when that exists.
Future<String> uniquePath(
  FileSystemBackend backend,
  String directory,
  String name,
) async {
  var candidate = backend.join(directory, name);
  if (!await backend.exists(candidate)) return candidate;
  final dot = name.lastIndexOf('.');
  final hasExtension = dot > 0 && !name.startsWith('.');
  final stem = hasExtension ? name.substring(0, dot) : name;
  final extension = hasExtension ? name.substring(dot) : '';
  var index = 1;
  while (true) {
    candidate = backend.join(directory, '$stem ($index)$extension');
    if (!await backend.exists(candidate)) return candidate;
    index += 1;
  }
}

/// Resolves where [name] should land inside [directory] according to [mode].
/// Returns `null` when the user chose to skip the entry (ask mode only).
Future<String?> resolveDestination(
  FileSystemBackend backend,
  String directory,
  String name, {
  required TransferConflictMode mode,
  required Future<TransferConflictChoice> Function(String name) askConflict,
}) async {
  final candidate = backend.join(directory, name);
  if (!await backend.exists(candidate)) return candidate;
  switch (mode) {
    case TransferConflictMode.rename:
      return uniquePath(backend, directory, name);
    case TransferConflictMode.overwrite:
      return candidate;
    case TransferConflictMode.ask:
      return switch (await askConflict(name)) {
        TransferConflictChoice.overwrite => candidate,
        TransferConflictChoice.keepBoth => uniquePath(backend, directory, name),
        TransferConflictChoice.skip => null,
      };
  }
}

/// Serial queue of file transfers that outlives any file-manager tab.
///
/// Each transfer opens its own backends (its own SFTP channel for a server
/// endpoint) and closes them when it ends, so closing the tab that queued it
/// never pulls the session out from under a running copy. Progress, pause,
/// resume and cancel go through [TaskProgressNotifier] so the global task bar
/// is the single status model.
class FileTransferQueue {
  FileTransferQueue({
    required this._progress,
    required this._conflictMode,
    required this._openBackend,
    required this._askConflict,
    this._notify,
  });

  final TaskProgressNotifier Function() _progress;
  final TransferConflictMode Function() _conflictMode;
  final Future<FileSystemBackend> Function(TransferEndpoint) _openBackend;
  final Future<TransferConflictChoice> Function(String) _askConflict;
  final void Function(TransferNotification)? _notify;

  final Queue<_QueuedTransfer> _queue = Queue<_QueuedTransfer>();
  var _draining = false;

  static const _progressInterval = Duration(milliseconds: 250);

  bool get isIdle => !_draining && _queue.isEmpty;

  /// Queues [request] and completes with the task's final status once it has
  /// run: `completed` (including a user skip), `canceled` or `failed`.
  Future<TaskProgressStatus> enqueue(FileTransferRequest request) {
    final controller = TransferController();
    final taskId = _progress().start(
      title: request.title,
      totalBytes: request.totalBytes,
      status: TaskProgressStatus.queued,
      onCancel: controller.cancel,
    );
    final transfer = _QueuedTransfer(
      taskId: taskId,
      request: request,
      controller: controller,
    );
    _queue.add(transfer);
    _pump();
    return transfer.done.future;
  }

  void _pump() {
    if (_draining) return;
    _draining = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    try {
      while (_queue.isNotEmpty) {
        final transfer = _queue.removeFirst();
        if (transfer.controller.isCancelled) {
          await _progress().cancel(transfer.taskId);
          await transfer.request.onFinish?.call();
          transfer.done.complete(TaskProgressStatus.canceled);
          continue;
        }
        final status = await _run(transfer);
        transfer.done.complete(status);
      }
    } finally {
      _draining = false;
      if (_queue.isNotEmpty) _pump();
    }
  }

  Future<TaskProgressStatus> _run(_QueuedTransfer transfer) async {
    final request = transfer.request;
    final controller = transfer.controller;
    final progress = _progress();
    progress.startRunning(
      transfer.taskId,
      onPause: controller.pause,
      onResume: controller.resume,
      onCancel: controller.cancel,
    );

    Timer? progressTimer;
    var pendingBytes = 0;
    var hasPendingProgress = false;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

    void flushProgress() {
      progressTimer?.cancel();
      progressTimer = null;
      if (!hasPendingProgress) return;
      hasPendingProgress = false;
      lastProgressAt = DateTime.now();
      progress.update(transfer.taskId, pendingBytes);
    }

    void reportProgress(int transferredBytes) {
      pendingBytes = transferredBytes;
      hasPendingProgress = true;
      final elapsed = DateTime.now().difference(lastProgressAt);
      if (elapsed >= _progressInterval) {
        flushProgress();
        return;
      }
      progressTimer ??= Timer(_progressInterval - elapsed, flushProgress);
    }

    FileSystemBackend? source;
    FileSystemBackend? destination;
    try {
      source = await _openBackend(request.source);
      destination = request.destination == request.source
          ? source
          : await _openBackend(request.destination);
      await _copy(request, source, destination, controller, reportProgress);
      controller.throwIfCancelled();
      flushProgress();
      progress.complete(transfer.taskId);
      if (request.notify) {
        _notify?.call(
          TransferNotification(
            title: 'fileManagerTransferComplete'.tr(),
            message: request.title,
            isError: false,
          ),
        );
      }
      return TaskProgressStatus.completed;
    } on TransferCancelled {
      flushProgress();
      await progress.cancel(transfer.taskId);
      return TaskProgressStatus.canceled;
    } on TransferSkipped {
      flushProgress();
      progress.complete(transfer.taskId);
      return TaskProgressStatus.completed;
    } catch (error) {
      flushProgress();
      progress.fail(transfer.taskId);
      _notify?.call(
        TransferNotification(
          title: 'fileManagerTransferFailed'.tr(),
          message: '${request.title}: $error',
          isError: true,
        ),
      );
      return TaskProgressStatus.failed;
    } finally {
      progressTimer?.cancel();
      if (destination != null && !identical(destination, source)) {
        await _closeQuietly(destination);
      }
      if (source != null) await _closeQuietly(source);
      await request.onFinish?.call();
    }
  }

  Future<void> _copy(
    FileTransferRequest request,
    FileSystemBackend source,
    FileSystemBackend destination,
    TransferController controller,
    void Function(int) reportProgress,
  ) async {
    final target = await resolveDestination(
      destination,
      request.destinationDirectory,
      request.name,
      mode: _conflictMode(),
      askConflict: _askConflict,
    );
    if (target == null) throw const TransferSkipped();
    if (request.isDirectory &&
        identical(source, destination) &&
        (target == request.sourcePath ||
            target.startsWith('${request.sourcePath}${source.separator}'))) {
      throw StateError('fileManagerCopyIntoItself'.tr());
    }

    // Write beside the existing entry and swap on success so cancelling an
    // overwrite never destroys the copy that was already there.
    final replacing = await destination.exists(target);
    final writePath = replacing
        ? destination.join(
            request.destinationDirectory,
            '.${request.name}.conduit-partial-'
            '${DateTime.now().microsecondsSinceEpoch}',
          )
        : target;
    try {
      await copyTree(
        source,
        request.sourcePath,
        destination,
        writePath,
        isDirectory: request.isDirectory,
        controller: controller,
        onProgress: reportProgress,
      );
      controller.throwIfCancelled();
      if (replacing) {
        await removeTree(destination, target);
        await destination.rename(writePath, target);
      }
    } catch (_) {
      if (controller.isCancelled || replacing) {
        try {
          await removeTree(destination, writePath);
        } catch (_) {}
      }
      rethrow;
    }
    if (request.deleteSourceOnSuccess) {
      await removeTree(source, request.sourcePath);
    }
  }

  Future<void> _closeQuietly(FileSystemBackend backend) async {
    try {
      await backend.close();
    } catch (_) {}
  }
}

class TransferNotification {
  const TransferNotification({
    required this.title,
    required this.message,
    required this.isError,
  });

  final String title;
  final String message;
  final bool isError;
}

class _QueuedTransfer {
  _QueuedTransfer({
    required this.taskId,
    required this.request,
    required this.controller,
  });

  final String taskId;
  final FileTransferRequest request;
  final TransferController controller;
  final Completer<TaskProgressStatus> done = Completer<TaskProgressStatus>();
}
