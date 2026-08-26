import 'dart:async';

import 'package:conduit/data/local/app_database.dart';
import 'server_models.dart';
import 'ssh_connection_manager.dart';

/// Refreshes lightweight metrics for connected servers when no detail page is
/// actively requesting its fuller data set.
///
/// One long-lived instance is fed through [update] whenever the interval, the
/// server list, the sessions or the focused server change; the periodic timer
/// survives those updates and is only recreated when the interval changes.
class ServerMetricsRefreshScheduler {
  ServerMetricsRefreshScheduler(this._connectionManager);

  final SshConnectionManager _connectionManager;
  Timer? _timer;
  Duration _interval = const Duration(seconds: 30);
  List<Server> _servers = const [];
  Set<int> _connectedServerIds = const {};
  var _refreshing = false;

  void update({
    required Duration interval,
    required List<Server> servers,
    required Iterable<SshSessionInfo> sessions,
    required int? focusedServerId,
  }) {
    _servers = servers;
    _connectedServerIds = sessions
        .where((session) => session.status == SessionStatus.connected)
        .map((session) => session.serverId)
        .toSet();
    if (focusedServerId != null) {
      _connectedServerIds = _connectedServerIds
          .where((id) => id != focusedServerId)
          .toSet();
    }
    if (_interval != interval) {
      _interval = interval;
      _timer?.cancel();
      _timer = null;
    }
    if (_connectedServerIds.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_interval, (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await Future.wait([
        for (final server in _servers)
          if (_connectedServerIds.contains(server.id))
            _connectionManager.refreshServerInfo(
              server,
              includeSystemInfo: false,
            ),
      ]);
    } finally {
      _refreshing = false;
    }
  }

  void dispose() => _timer?.cancel();
}
