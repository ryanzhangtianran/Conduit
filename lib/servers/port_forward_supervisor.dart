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

/// Whether the running [forward] is the one [config] describes.
///
/// This is the single definition of forward identity: the supervisor uses it
/// to tell whether a preset is up, and the connection manager uses
/// [sameForwardEndpoints] to avoid starting the same forward twice. Direction
/// and destination are part of the identity, so a local and a remote preset
/// with the same bind address are distinct.
bool activeForwardMatches(
  ActivePortForward forward,
  PortForwardConfig config,
) => sameForwardEndpoints(
  forward,
  serverId: config.serverId,
  direction: PortForwardDirection.values.byName(config.direction),
  kind: PortForwardKind.values.byName(config.kind),
  bindHost: config.bindHost,
  bindPort: config.bindPort,
  targetHost: config.targetHost,
  targetPort: config.targetPort,
);

/// Whether [forward] has exactly these endpoints. SOCKS5 forwards have no
/// fixed destination, so only their listener is compared.
bool sameForwardEndpoints(
  ActivePortForward forward, {
  required int serverId,
  required PortForwardDirection direction,
  required PortForwardKind kind,
  required String bindHost,
  required int bindPort,
  required String targetHost,
  required int targetPort,
}) {
  if (forward.serverId != serverId ||
      forward.direction != direction ||
      forward.kind != kind ||
      forward.bindHost != bindHost ||
      forward.bindPort != bindPort) {
    return false;
  }
  if (kind == PortForwardKind.socks5) return true;
  return forward.targetHost == targetHost && forward.targetPort == targetPort;
}

/// How the supervisor currently treats a saved preset.
enum PortForwardPresetStatus {
  /// Not a keep-alive preset, or its server is not connected.
  unsupervised,

  /// Keep-alive and running.
  active,

  /// Keep-alive, its server is connected, and the forward is down; a retry
  /// is scheduled.
  retrying,

  /// The user stopped it; it stays down until [PortForwardSupervisor.resume]
  /// or the server's next connect.
  paused,
}

/// Starts saved forwards when a server connects and, for the presets that ask
/// for it, keeps them alive.
///
/// Auto-start alone is one-shot: the forward goes up on connect and stays down
/// if it later dies. A preset with `keepAlive` is instead supervised — the
/// forward is re-established with exponential backoff whenever it disappears
/// while the SSH session itself is still connected. A disconnected session
/// ends supervision until the next connect.
///
/// Presets are followed live through [configs], so a keep-alive preset added
/// or edited while its server is connected comes up right away, and one that
/// is deleted stops being supervised. A forward the supervisor itself started
/// exists only because of its preset, so it is stopped when that preset is
/// deleted or changes endpoints; forwards the user started by hand are left
/// alone.
class PortForwardSupervisor {
  PortForwardSupervisor(
    this._manager, {
    required Stream<List<Server>> servers,
    required Stream<List<PortForwardConfig>> configs,
  }) {
    _subscriptions = [
      _manager.portForwards.listen((_) => _reconcile()),
      _manager.connectedServerIds.listen(_onServerConnected),
      servers.listen(_onServersChanged, onError: (Object _, StackTrace _) {}),
      configs.listen(_onConfigsChanged, onError: (Object _, StackTrace _) {}),
    ];
  }

  final SshConnectionManager _manager;
  late final List<StreamSubscription<void>> _subscriptions;

  final _servers = <int, Server>{};

  /// Every saved preset, keyed by preset id.
  final _configs = <int, PortForwardConfig>{};
  var _configsLoaded = false;

  /// Servers that connected before the presets arrived.
  final _pendingConnects = <int>{};

  /// Presets the user stopped; cleared by [resume] or the next connect.
  final _paused = <int>{};

  /// Forward ids the supervisor itself started, keyed by preset id.
  final _startedForwards = <int, String>{};
  final _retryTimers = <int, Timer>{};
  final _retryAttempts = <int, int>{};
  var _statuses = <int, PortForwardPresetStatus>{};
  final _changes = StreamController<void>.broadcast();

  /// Fires whenever any preset's [statusOf] changes.
  Stream<void> get changes => _changes.stream;

  PortForwardPresetStatus statusOf(int configId) {
    final config = _configs[configId];
    if (config == null || !config.keepAlive) {
      return PortForwardPresetStatus.unsupervised;
    }
    if (_paused.contains(configId)) return PortForwardPresetStatus.paused;
    if (_manager.clientFor(config.serverId) == null) {
      return PortForwardPresetStatus.unsupervised;
    }
    return _activeFor(config) != null
        ? PortForwardPresetStatus.active
        : PortForwardPresetStatus.retrying;
  }

  /// Starts every auto-start preset for [server] and brings up the keep-alive
  /// ones. Safe to call repeatedly; running forwards are reused.
  Future<void> onConnected(Server server) async {
    _servers[server.id] = server;
    if (!_configsLoaded) {
      _pendingConnects.add(server.id);
      return;
    }
    for (final config in _configsFor(server.id)) {
      if (!config.autoStart && !config.keepAlive) continue;
      if (_paused.contains(config.id)) continue;
      if (_activeFor(config) != null) continue;
      await _start(server, config);
    }
    _reconcile();
  }

  /// The user pressed Stop: the forward goes down and stays down until
  /// [resume] or the server's next connect.
  void pause(int configId) {
    final config = _configs[configId];
    if (config == null) return;
    _paused.add(configId);
    final forward = _activeFor(config);
    if (forward != null) {
      _startedForwards.remove(configId);
      unawaited(_manager.stopPortForward(forward.id));
    }
    _reconcile();
  }

  /// The user pressed Start on a paused preset.
  void resume(int configId) {
    _paused.remove(configId);
    final config = _configs[configId];
    final server = config == null ? null : _servers[config.serverId];
    if (config != null && server != null && _activeFor(config) == null) {
      unawaited(_start(server, config));
    }
    _reconcile();
  }

  /// The preset was deleted: stop supervising it. A forward the supervisor
  /// started for it is stopped as well; one the user started stays up.
  void forget(int configId) {
    _paused.remove(configId);
    _configs.remove(configId);
    final forwardId = _startedForwards.remove(configId);
    if (forwardId != null) unawaited(_manager.stopPortForward(forwardId));
    _reconcile();
  }

  void _onServerConnected(int serverId) {
    // A fresh session lifts pauses: the user stopped a forward on the previous
    // session, not on this one.
    _paused.removeWhere((id) => _configs[id]?.serverId == serverId);
    final server = _servers[serverId];
    if (server == null) {
      _pendingConnects.add(serverId);
      return;
    }
    unawaited(onConnected(server));
  }

  void _onServersChanged(List<Server> servers) {
    _servers
      ..clear()
      ..addEntries(servers.map((server) => MapEntry(server.id, server)));
    _flushPendingConnects();
  }

  void _onConfigsChanged(List<PortForwardConfig> configs) {
    _configs
      ..clear()
      ..addEntries(configs.map((config) => MapEntry(config.id, config)));
    _configsLoaded = true;
    _paused.removeWhere((id) => !_configs.containsKey(id));
    // A supervisor-started forward whose preset vanished or changed endpoints
    // is stale; stop it so the edited preset can take its place.
    for (final entry in _startedForwards.entries.toList()) {
      final forward = _forwardById(entry.value);
      if (forward == null) {
        _startedForwards.remove(entry.key);
        continue;
      }
      final config = _configs[entry.key];
      if (config == null || !activeForwardMatches(forward, config)) {
        _startedForwards.remove(entry.key);
        unawaited(_manager.stopPortForward(forward.id));
      }
    }
    _flushPendingConnects();
    // New or edited keep-alive presets on a connected server come up now
    // rather than after the first retry delay.
    for (final config in _configs.values) {
      final server = _servers[config.serverId];
      if (server == null ||
          !config.keepAlive ||
          _paused.contains(config.id) ||
          _manager.clientFor(server.id) == null ||
          _activeFor(config) != null) {
        continue;
      }
      unawaited(_start(server, config));
    }
    _reconcile();
  }

  void _flushPendingConnects() {
    if (!_configsLoaded) return;
    for (final serverId in _pendingConnects.toList()) {
      final server = _servers[serverId];
      if (server == null) continue;
      _pendingConnects.remove(serverId);
      unawaited(onConnected(server));
    }
  }

  Iterable<PortForwardConfig> _configsFor(int serverId) =>
      _configs.values.where((config) => config.serverId == serverId);

  ActivePortForward? _activeFor(PortForwardConfig config) => _manager
      .currentPortForwards
      .where((forward) => activeForwardMatches(forward, config))
      .firstOrNull;

  ActivePortForward? _forwardById(String id) => _manager.currentPortForwards
      .where((forward) => forward.id == id)
      .firstOrNull;

  Future<void> _start(Server server, PortForwardConfig config) async {
    if (_manager.clientFor(server.id) == null) return;
    final alreadyRunning = _activeFor(config) != null;
    try {
      final forward = await _manager.startPortForward(
        server: server,
        direction: PortForwardDirection.values.byName(config.direction),
        kind: PortForwardKind.values.byName(config.kind),
        bindHost: config.bindHost,
        bindPort: config.bindPort,
        targetHost: config.targetHost,
        targetPort: config.targetPort,
      );
      if (!alreadyRunning) _startedForwards[config.id] = forward.id;
      _retryAttempts[server.id] = 0;
    } catch (_) {
      // One preset failing (e.g. its port is taken) must not stop the rest;
      // supervised presets come back through the retry timer.
      if (config.keepAlive && !_paused.contains(config.id)) {
        _scheduleRetry(server.id);
      }
    }
    _notify();
  }

  /// Re-evaluates every keep-alive preset: while its session is connected a
  /// missing forward gets a retry scheduled; a dropped session ends retries
  /// until the next connect.
  void _reconcile() {
    final serverIds = <int>{
      ..._retryTimers.keys,
      ..._retryAttempts.keys,
      for (final config in _configs.values)
        if (config.keepAlive) config.serverId,
    };
    for (final serverId in serverIds) {
      if (_manager.clientFor(serverId) == null) {
        _cancelRetry(serverId);
        _retryAttempts.remove(serverId);
        continue;
      }
      if (_missingFor(serverId).isNotEmpty) {
        _scheduleRetry(serverId);
      } else {
        _cancelRetry(serverId);
        _retryAttempts[serverId] = 0;
      }
    }
    _notify();
  }

  /// Keep-alive presets of [serverId] that should be running but are not.
  List<PortForwardConfig> _missingFor(int serverId) => [
    for (final config in _configsFor(serverId))
      if (config.keepAlive &&
          !_paused.contains(config.id) &&
          _activeFor(config) == null)
        config,
  ];

  void _scheduleRetry(int serverId) {
    if (_retryTimers.containsKey(serverId)) return;
    final attempt = _retryAttempts[serverId] ?? 0;
    _retryAttempts[serverId] = attempt + 1;
    _retryTimers[serverId] = Timer(portForwardRetryDelay(attempt), () async {
      _retryTimers.remove(serverId);
      final server = _servers[serverId];
      if (server == null) return;
      for (final config in _missingFor(serverId)) {
        await _start(server, config);
      }
      _reconcile();
    });
  }

  void _cancelRetry(int serverId) {
    _retryTimers.remove(serverId)?.cancel();
  }

  void _notify() {
    if (_changes.isClosed) return;
    final statuses = {for (final id in _configs.keys) id: statusOf(id)};
    if (_sameStatuses(statuses, _statuses)) return;
    _statuses = statuses;
    _changes.add(null);
  }

  static bool _sameStatuses(
    Map<int, PortForwardPresetStatus> a,
    Map<int, PortForwardPresetStatus> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void dispose() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_changes.close());
  }
}
