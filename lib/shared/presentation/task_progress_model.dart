/// The single model for "a long-running thing with progress and cancel".
/// File transfers (and any future background task) report into
/// [taskProgressProvider]; [TaskProgressStatus] is their only status enum.
library;

import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

enum TaskProgressStatus {
  queued,
  inProgress,
  paused,
  completed,
  failed,
  canceled,
}

class AppTaskProgress {
  const AppTaskProgress({
    required this.id,
    required this.title,
    required this.totalBytes,
    required this.transferredBytes,
    required this.speedBytesPerSecond,
    required this.canPause,
    required this.canCancel,
    required this.status,
  });

  final String id;
  final String title;
  final int? totalBytes;
  final int transferredBytes;
  final double? speedBytesPerSecond;
  final bool canPause;
  final bool canCancel;
  final TaskProgressStatus status;

  bool get isActive =>
      status == TaskProgressStatus.queued ||
      status == TaskProgressStatus.inProgress ||
      status == TaskProgressStatus.paused;

  bool get isQueued => status == TaskProgressStatus.queued;

  bool get isPaused => status == TaskProgressStatus.paused;

  double? get progress => totalBytes == null
      ? null
      : (transferredBytes / totalBytes!).clamp(0, 1).toDouble();

  Duration? get eta {
    final total = totalBytes;
    final speed = speedBytesPerSecond;
    if (total == null || speed == null || speed <= 0) return null;
    final remaining = total - transferredBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / speed).ceil());
  }

  AppTaskProgress copyWith({
    TaskProgressStatus? status,
    int? transferredBytes,
    double? speedBytesPerSecond,
    bool? canPause,
    bool? canCancel,
  }) => AppTaskProgress(
    id: id,
    title: title,
    totalBytes: totalBytes,
    transferredBytes: transferredBytes ?? this.transferredBytes,
    speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
    canPause: canPause ?? this.canPause,
    canCancel: canCancel ?? this.canCancel,
    status: status ?? this.status,
  );
}

final taskProgressProvider =
    NotifierProvider<TaskProgressNotifier, List<AppTaskProgress>>(
      TaskProgressNotifier.new,
    );

class TaskProgressNotifier extends Notifier<List<AppTaskProgress>> {
  final _handlers = <String, _TaskControlHandlers>{};
  final _samples = <String, _TaskProgressSample>{};
  final _pendingRemovalTimers = <String, Timer>{};

  @override
  List<AppTaskProgress> build() => const [];

  String start({
    required String title,
    int? totalBytes,
    TaskProgressStatus status = TaskProgressStatus.inProgress,
    FutureOr<void> Function()? onPause,
    FutureOr<void> Function()? onResume,
    FutureOr<void> Function()? onCancel,
  }) {
    final id = 'task-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    _handlers[id] = _TaskControlHandlers(
      onPause: onPause,
      onResume: onResume,
      onCancel: onCancel,
    );
    _samples[id] = _TaskProgressSample(bytes: 0, timestamp: now);
    state = [
      ...state,
      AppTaskProgress(
        id: id,
        title: title,
        totalBytes: totalBytes,
        transferredBytes: 0,
        speedBytesPerSecond: null,
        canPause:
            status == TaskProgressStatus.inProgress &&
            onPause != null &&
            onResume != null,
        canCancel: onCancel != null,
        status: status,
      ),
    ];
    return id;
  }

  void startRunning(
    String id, {
    FutureOr<void> Function()? onPause,
    FutureOr<void> Function()? onResume,
    FutureOr<void> Function()? onCancel,
  }) {
    _handlers[id] = _TaskControlHandlers(
      onPause: onPause,
      onResume: onResume,
      onCancel: onCancel,
    );
    _samples[id] = _TaskProgressSample(
      bytes:
          state.where((task) => task.id == id).firstOrNull?.transferredBytes ??
          0,
      timestamp: DateTime.now(),
    );
    state = state.map((task) {
      if (task.id != id || !task.isActive) return task;
      return task.copyWith(
        status: TaskProgressStatus.inProgress,
        canPause: onPause != null && onResume != null,
        canCancel: onCancel != null,
      );
    }).toList();
  }

  void update(String id, int transferredBytes) {
    if (!ref.mounted) return;
    final now = DateTime.now();
    final previous = _samples[id];
    var speed = previous == null
        ? null
        : _speed(previous, transferredBytes, now);
    _samples[id] = _TaskProgressSample(bytes: transferredBytes, timestamp: now);
    state = state.map((task) {
      if (task.id != id || !task.isActive) return task;
      speed ??= task.speedBytesPerSecond;
      return task.copyWith(
        transferredBytes: transferredBytes,
        speedBytesPerSecond: speed,
      );
    }).toList();
  }

  Future<void> pause(String id) async {
    final handler = _handlers[id]?.onPause;
    if (handler == null) return;
    state = state.map((task) {
      if (task.id != id || !task.isActive) return task;
      return task.copyWith(status: TaskProgressStatus.paused);
    }).toList();
    await handler();
  }

  Future<void> resume(String id) async {
    final handler = _handlers[id]?.onResume;
    if (handler == null) return;
    await handler();
    _samples[id] = _TaskProgressSample(
      bytes:
          state.where((task) => task.id == id).firstOrNull?.transferredBytes ??
          0,
      timestamp: DateTime.now(),
    );
    state = state.map((task) {
      if (task.id != id || task.status != TaskProgressStatus.paused) {
        return task;
      }
      return task.copyWith(status: TaskProgressStatus.inProgress);
    }).toList();
  }

  Future<void> cancel(String id) async {
    final handler = _handlers[id]?.onCancel;
    if (handler == null) return;
    await handler();
    _finish(id, TaskProgressStatus.canceled);
  }

  void complete(String id) => _finish(id, TaskProgressStatus.completed);

  void fail(String id) => _finish(id, TaskProgressStatus.failed);

  void _finish(String id, TaskProgressStatus status) {
    if (!ref.mounted) return;
    final task = state.where((task) => task.id == id).firstOrNull;
    if (task == null ||
        task.status == TaskProgressStatus.completed ||
        task.status == TaskProgressStatus.failed ||
        task.status == TaskProgressStatus.canceled) {
      return;
    }
    _handlers.remove(id);
    _samples.remove(id);
    _pendingRemovalTimers.remove(id)?.cancel();
    state = state.map((task) {
      if (task.id != id) return task;
      return task.copyWith(
        status: status,
        transferredBytes: status == TaskProgressStatus.completed
            ? (task.totalBytes ?? task.transferredBytes)
            : task.transferredBytes,
        canPause: false,
        canCancel: false,
      );
    }).toList();
    _pendingRemovalTimers[id] = Timer(const Duration(seconds: 3), () {
      _pendingRemovalTimers.remove(id);
      if (ref.mounted) {
        state = state.where((task) => task.id != id).toList();
      }
    });
  }

  double? _speed(
    _TaskProgressSample previous,
    int transferredBytes,
    DateTime now,
  ) {
    final elapsedMs = now.difference(previous.timestamp).inMilliseconds;
    final delta = transferredBytes - previous.bytes;
    if (elapsedMs <= 0 || delta <= 0) return null;
    return delta * 1000 / elapsedMs;
  }
}

class _TaskControlHandlers {
  const _TaskControlHandlers({this.onPause, this.onResume, this.onCancel});

  final FutureOr<void> Function()? onPause;
  final FutureOr<void> Function()? onResume;
  final FutureOr<void> Function()? onCancel;
}

class _TaskProgressSample {
  const _TaskProgressSample({required this.bytes, required this.timestamp});

  final int bytes;
  final DateTime timestamp;
}
