import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'activity_models.dart';
import 'server_models.dart';
import 'server_providers.dart';

/// Rolling activity history for one server.
class ActivityHistoryState {
  const ActivityHistoryState({
    this.history = const [],
    this.error,
    this.hasSample = false,
  });

  final List<ActivitySample> history;

  /// Last collection error; only shown until the first sample arrives.
  final String? error;
  final bool hasSample;

  ActivityHistoryState copyWith({
    List<ActivitySample>? history,
    String? error,
    bool clearError = false,
    bool? hasSample,
  }) => ActivityHistoryState(
    history: history ?? this.history,
    error: clearError ? null : error ?? this.error,
    hasSample: hasSample ?? this.hasSample,
  );
}

/// Samples a connected server on a timer and keeps the last
/// [ActivityHistoryNotifier.historyLimit] points. The provider is kept alive
/// while the server is connected so history survives leaving the page, and
/// it stops sampling (and lets itself dispose) as soon as the server
/// disconnects.
final activityHistoryProvider = NotifierProvider.autoDispose
    .family<ActivityHistoryNotifier, ActivityHistoryState, int>(
      ActivityHistoryNotifier.new,
    );

class ActivityHistoryNotifier extends Notifier<ActivityHistoryState> {
  ActivityHistoryNotifier(this.serverId);

  static const historyLimit = 60;

  final int serverId;
  Timer? _timer;
  Duration? _interval;
  ActivityCounters? _previous;
  var _polling = false;
  var _running = false;
  void Function()? _releaseKeepAlive;
  StreamSubscription<List<SshSessionInfo>>? _sessions;

  @override
  ActivityHistoryState build() {
    final manager = ref.read(connectionManagerProvider);
    _sessions = manager.sessions.listen((sessions) {
      final info = sessions
          .where((session) => session.serverId == serverId)
          .firstOrNull;
      if (info == null || info.status != SessionStatus.connected) stop();
    });
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_sessions?.cancel());
    });
    return const ActivityHistoryState();
  }

  /// Starts (or retunes) sampling while [connected]; stops otherwise. A fresh
  /// connection clears the previous history.
  void configure({required bool connected, required Duration interval}) {
    if (!connected) {
      stop();
      return;
    }
    _releaseKeepAlive ??= ref.keepAlive().close;
    final starting = !_running;
    _running = true;
    if (starting) {
      _previous = null;
      state = const ActivityHistoryState();
      unawaited(poll());
    }
    if (_timer == null || _interval != interval) {
      _interval = interval;
      _timer?.cancel();
      _timer = Timer.periodic(interval, (_) => poll());
    }
  }

  /// Stops sampling and releases the keep-alive so the provider can dispose.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _interval = null;
    _running = false;
    _releaseKeepAlive?.call();
    _releaseKeepAlive = null;
  }

  Future<void> poll() async {
    if (_polling || !ref.mounted) return;
    _polling = true;
    try {
      final counters = await ref
          .read(connectionManagerProvider)
          .collectActivityCounters(serverId);
      final sample = counters.toSample(previous: _previous);
      _previous = counters;
      if (!ref.mounted) return;
      final history = [...state.history, sample];
      if (history.length > historyLimit) {
        history.removeRange(0, history.length - historyLimit);
      }
      state = state.copyWith(
        history: history,
        hasSample: true,
        clearError: true,
      );
    } catch (error) {
      if (ref.mounted && !state.hasSample) {
        state = state.copyWith(error: error.toString());
      }
    } finally {
      _polling = false;
    }
  }
}
