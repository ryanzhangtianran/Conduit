import 'dart:async';

import 'package:conduit/data/local/app_database.dart';

import 'port_forwarding_models.dart';
import 'ssh_connection_manager.dart';

/// Retry delay before re-establishing a dropped forward: 2s, 4s, 8s… capped
/// at 30s.
Duration portForwardRetryDelay(int attempt) {
  final seconds = 2 << (attempt < 0 ? 0 : attempt);
  return Duration(seconds: seconds > 30 ? 30 : seconds);
}

/// Starts saved forwards when a server connects and, for the presets that ask
/// for it, keeps them alive.
///
/// Auto-start alone is one-shot: the forward goes up on connect and stays down
/// if it later dies. A preset with `keepAlive` is instead supervised — the
/// forward is re-established with exponential backoff whenever it disappears
/// while the SSH session itself is still connected. A disconnected session
/// ends supervision until the next connect re-registers the server.
class PortForwardSupervisor {
  PortForwardSupervisor(this._manager, this._configsFor) {
    _subscription = _manager.portForwards.listen(_onForwardsChanged);
  }

  final SshConnectionManager _manager;
  final Future<List<PortForwardConfig>> Function(int serverId) _configsFor;

  late final StreamSubscription<void> _subscription;

  /// Supervised presets per server, keyed by preset id.
  final _supervised = <int, Map<int, PortForwardConfig>>{};
  final _servers = <int, Server>{};
  final _retryTimers = <int, Timer>{};
  final _retryAttempts = <int, int>{};

  /// Ids of servers with at least one supervised preset.
  Set<int> get supervisedServerIds => _supervised.keys.toSet();

  /// Starts every auto-start preset for [server] and begins supervising the
  /// ones marked keep-alive. Safe to call on every connect.
  Future<void> onConnected(Server server) async {
    final List<PortForwardConfig> configs;
    try {
      configs = await _configsFor(server.id);
    } catch (_) {
      // A database failure must never break the connection itself.
      return;
    }
    _servers[server.id] = server;
    final supervised = <int, PortForwardConfig>{};
    for (final config in configs) {
      if (config.keepAlive) supervised[config.id] = config;
      if (!config.autoStart && !config.keepAlive) continue;
      if (_isActive(server.id, config)) continue;
      await _start(server, config);
    }
    if (supervised.isEmpty) {
      _supervised.remove(server.id);
    } else {
      _supervised[server.id] = supervised;
    }
  }

  /// Stops supervising [serverId]; already-active forwards are left running.
  void forget(int serverId) {
    _supervised.remove(serverId);
    _servers.remove(serverId);
    _cancelRetry(serverId);
    _retryAttempts.remove(serverId);
  }

  /// Re-reads presets for every supervised server, picking up edited ports.
  Future<void> restartAll() async {
    for (final serverId in _supervised.keys.toList()) {
      final server = _servers[serverId];
      if (server == null) continue;
      for (final config in _supervised[serverId]?.values.toList() ?? const []) {
        final active = _activeFor(serverId, config);
        if (active != null) await _manager.stopPortForward(active.id);
      }
      _retryAttempts.remove(serverId);
      _cancelRetry(serverId);
      await onConnected(server);
    }
  }

  ActivePortForward? _activeFor(int serverId, PortForwardConfig config) {
    for (final forward in _manager.currentPortForwards) {
      if (forward.serverId == serverId &&
          forward.kind == PortForwardKind.values.byName(config.kind) &&
          forward.bindHost == config.bindHost &&
          forward.bindPort == config.bindPort) {
        return forward;
      }
    }
    return null;
  }

  bool _isActive(int serverId, PortForwardConfig config) =>
      _activeFor(serverId, config) != null;

  Future<void> _start(Server server, PortForwardConfig config) async {
    if (_manager.clientFor(server.id) == null) return;
    try {
      await _manager.startPortForward(
        server: server,
        direction: PortForwardDirection.values.byName(config.direction),
        kind: PortForwardKind.values.byName(config.kind),
        bindHost: config.bindHost,
        bindPort: config.bindPort,
        targetHost: config.targetHost,
        targetPort: config.targetPort,
      );
      _retryAttempts[server.id] = 0;
    } catch (_) {
      // One preset failing (e.g. its port is taken) must not stop the rest;
      // supervised presets come back through the retry timer.
      if (config.keepAlive) _scheduleRetry(server.id);
    }
  }

  /// Reacts to a supervised forward disappearing: while its session is still
  /// connected, bring it back.
  void _onForwardsChanged(void _) {
    for (final serverId in _supervised.keys.toList()) {
      if (_manager.clientFor(serverId) == null) {
        // The session dropped; reconnection re-registers via onConnected.
        _cancelRetry(serverId);
        _retryAttempts.remove(serverId);
        continue;
      }
      final missing = _supervised[serverId]!.values.any(
        (config) => !_isActive(serverId, config),
      );
      if (missing) {
        _scheduleRetry(serverId);
      } else {
        _retryAttempts[serverId] = 0;
      }
    }
  }

  void _scheduleRetry(int serverId) {
    if (_retryTimers.containsKey(serverId)) return;
    final attempt = _retryAttempts[serverId] ?? 0;
    _retryAttempts[serverId] = attempt + 1;
    _retryTimers[serverId] = Timer(portForwardRetryDelay(attempt), () async {
      _retryTimers.remove(serverId);
      final server = _servers[serverId];
      if (server == null) return;
      for (final config in _supervised[serverId]?.values.toList() ?? const []) {
        if (!_isActive(serverId, config)) await _start(server, config);
      }
    });
  }

  void _cancelRetry(int serverId) {
    _retryTimers.remove(serverId)?.cancel();
  }

  void dispose() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    unawaited(_subscription.cancel());
  }
}
