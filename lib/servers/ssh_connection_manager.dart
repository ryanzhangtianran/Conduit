import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:conduit/data/local/app_database.dart';
import 'activity_models.dart';
import 'metrics_parsers.dart';
import 'port_forward_supervisor.dart';
import 'port_forwarding_models.dart';
import 'server_metrics_collector.dart';
import 'server_models.dart';
import 'ssh_proxy_connect.dart';
import 'socks5_protocol.dart';

typedef HostKeyApproval = Future<bool> Function(HostKeyPrompt prompt);

/// Builds the user-facing explanation of an authentication failure from the
/// credential Conduit offered and the `methodsLeft` list the server answered
/// with. The UI layer supplies this so the transport layer holds no prose.
typedef AuthFailureDescriber =
    String Function({
      required CredentialType credentialType,
      String? serverAuthMethods,
    });

/// Wraps an authentication failure so every caller — session card and
/// snackbar alike — reports [message] instead of dartssh2's generic
/// "All authentication methods failed".
class SshAuthenticationException implements Exception {
  const SshAuthenticationException(
    this.message, {
    required this.credentialType,
    this.serverAuthMethods,
  });

  final String message;

  /// The credential that was offered.
  final CredentialType credentialType;

  /// The server's `methodsLeft` list, if it advertised one.
  final String? serverAuthMethods;

  @override
  String toString() => message;
}

String _defaultAuthFailureMessage({
  required CredentialType credentialType,
  String? serverAuthMethods,
}) => credentialType == CredentialType.privateKey
    ? 'The server rejected the private key.'
    : 'The server rejected the password.';

class SshConnectionManager {
  SshConnectionManager({AuthFailureDescriber? describeAuthFailure})
    : _describeAuthFailure = describeAuthFailure ?? _defaultAuthFailureMessage;

  final AuthFailureDescriber _describeAuthFailure;
  final ServerMetricsCollector _metricsCollector =
      const AutoServerMetricsCollector();

  /// These clients are used exclusively for collecting server information.
  /// Terminal shells keep their own clients so reconnecting statistics never
  /// interrupts an interactive session.
  final _sessions = <int, SSHClient>{};

  /// In-flight [connect] calls, so a second connect for the same server joins
  /// the first instead of opening a second transport.
  final _pendingConnects = <int, Future<void>>{};

  /// Bumped by [disconnect]; a connect whose generation moved on while its
  /// handshake was in flight has been cancelled and discards its client.
  final _connectGenerations = <int, int>{};
  final _connectedController = StreamController<int>.broadcast();

  /// Immediate jump-host relationships for retained SSH sessions. Keeping
  /// these relationships lets a disconnected parent tear down its children.
  final _sessionJumpHosts = <int, int?>{};
  final _terminals = <String, _TerminalConnection>{};

  /// Non-interactive SSH commands do not source the user's shell profile.
  /// Include common Homebrew and Docker Desktop locations explicitly so
  /// user-installed tools are discoverable on macOS and Linuxbrew hosts.
  static const _remoteToolPath =
      '/opt/homebrew/bin:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:'
      '/Applications/Docker.app/Contents/Resources/bin';
  final _controller = StreamController<List<SshSessionInfo>>.broadcast();
  final _portForwardController =
      StreamController<List<ActivePortForward>>.broadcast();
  final _states = <int, SshSessionInfo>{};
  final _portForwards = <String, _PortForwardingConnection>{};
  var _nextTerminalId = 0;
  var _nextPortForwardId = 0;

  Stream<List<SshSessionInfo>> get sessions => _controller.stream;
  List<SshSessionInfo> get current => _states.values.toList();

  /// Emits a server id each time its SSH session becomes connected. The
  /// port-forward supervisor listens to start saved presets.
  Stream<int> get connectedServerIds => _connectedController.stream;
  Stream<List<ActivePortForward>> get portForwards =>
      _portForwardController.stream;
  List<ActivePortForward> get currentPortForwards =>
      _portForwards.values.map((forward) => forward.info).toList();

  Future<ActivePortForward> startPortForward({
    required Server server,
    required PortForwardDirection direction,
    required PortForwardKind kind,
    required String bindHost,
    required int bindPort,
    String targetHost = '',
    int targetPort = 0,
  }) async {
    final client = clientFor(server.id);
    if (client == null) throw const ServerConnectionRequiredException();
    if (kind == PortForwardKind.socks5 &&
        direction == PortForwardDirection.remote) {
      throw ArgumentError(
        'SOCKS5 forwarding is only available in the local direction.',
      );
    }
    // Starting the exact same forward twice (auto-start already brought it
    // up, then the user presses play) reuses the running one instead of
    // fighting over the port.
    if (bindPort != 0) {
      for (final existing in _portForwards.values) {
        if (sameForwardEndpoints(
          existing.info,
          serverId: server.id,
          direction: direction,
          kind: kind,
          bindHost: bindHost,
          bindPort: bindPort,
          targetHost: targetHost,
          targetPort: targetPort,
        )) {
          return existing.info;
        }
      }
    }
    final id = 'forward-${_nextPortForwardId++}';
    var info = ActivePortForward(
      id: id,
      serverId: server.id,
      serverName: server.name,
      direction: direction,
      kind: kind,
      bindHost: bindHost,
      bindPort: bindPort,
      targetHost: targetHost,
      targetPort: targetPort,
    );

    late final _PortForwardingConnection connection;
    if (direction == PortForwardDirection.local) {
      final listener = await ServerSocket.bind(bindHost, bindPort);
      info = info.copyWith(bindPort: listener.port);
      connection = _PortForwardingConnection.local(info, listener);
      connection.subscription = listener.listen((socket) {
        unawaited(
          kind == PortForwardKind.socks5
              ? _pipeSocks5Connection(client, socket, connection.traffic)
              : _pipeLocalConnection(
                  client,
                  socket,
                  targetHost,
                  targetPort,
                  connection.traffic,
                ),
        );
      }, onError: (_, _) => unawaited(stopPortForward(id)));
    } else {
      final remote = await client.forwardRemote(host: bindHost, port: bindPort);
      if (remote == null) {
        throw PortForwardRefusedException(bindHost, bindPort);
      }
      connection = _PortForwardingConnection.remote(info, remote);
      connection.subscription = remote.connections.listen((channel) {
        unawaited(
          _pipeRemoteConnection(
            channel,
            targetHost,
            targetPort,
            connection.traffic,
          ),
        );
      }, onError: (_, _) => unawaited(stopPortForward(id)));
    }
    _portForwards[id] = connection;
    _emitPortForwards();
    return info;
  }

  Future<void> stopPortForward(String id) async {
    final forward = _portForwards.remove(id);
    if (forward == null) return;
    await forward.close();
    _emitPortForwards();
  }

  Future<void> _pipeLocalConnection(
    SSHClient client,
    Socket socket,
    String targetHost,
    int targetPort,
    _ForwardTraffic traffic,
  ) async {
    traffic.opened();
    try {
      final channel = await client.forwardLocal(
        targetHost,
        targetPort,
        localHost: socket.remoteAddress.address,
        localPort: socket.remotePort,
      );
      await _pumpForward(
        fromServer: channel.stream.cast<List<int>>(),
        toLocal: socket,
        fromLocal: socket.cast<List<int>>(),
        toServer: channel.sink,
        traffic: traffic,
      );
    } catch (_) {
      await socket.close();
    } finally {
      traffic.closed();
    }
  }

  /// Pipes both directions of a forwarded connection, counting bytes into
  /// [traffic], and completes when both sides are done.
  Future<void> _pumpForward({
    required Stream<List<int>> fromServer,
    required StreamConsumer<List<int>> toLocal,
    required Stream<List<int>> fromLocal,
    required StreamConsumer<List<int>> toServer,
    required _ForwardTraffic traffic,
  }) => Future.wait([
    fromServer
        .map((chunk) {
          traffic.addDown(chunk.length);
          return chunk;
        })
        .pipe(toLocal)
        .catchError((_) {}),
    fromLocal
        .map((chunk) {
          traffic.addUp(chunk.length);
          return chunk;
        })
        .pipe(toServer)
        .catchError((_) {}),
  ]);

  /// Runs a SOCKS5 server handshake on a locally accepted [socket], then
  /// tunnels the client's traffic to the destination it chose over an SSH
  /// direct-tcpip channel. DNS for domain destinations happens on the SSH
  /// server, matching plain TCP forwarding.
  Future<void> _pipeSocks5Connection(
    SSHClient client,
    Socket socket,
    _ForwardTraffic traffic,
  ) async {
    traffic.opened();
    final handshake = Socks5ServerHandshake(socket, socket);
    try {
      final destination = await handshake.negotiate();
      final channel = await client.forwardLocal(
        destination.host,
        destination.port,
        localHost: socket.remoteAddress.address,
        localPort: socket.remotePort,
      );
      handshake.startPump();
      await _pumpForward(
        fromServer: channel.stream.cast<List<int>>(),
        toLocal: socket,
        fromLocal: handshake.stream.cast<List<int>>(),
        toServer: channel.sink,
        traffic: traffic,
      );
    } on Socks5ProtocolException {
      // The failure reply was already sent (or none applies); just close.
      await handshake.dispose();
      await socket.close();
    } catch (_) {
      // The handshake succeeded but the tunnel could not be opened.
      try {
        socket.add(const [0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
      } catch (_) {}
      await handshake.dispose();
      await socket.close();
    } finally {
      traffic.closed();
    }
  }

  Future<void> _pipeRemoteConnection(
    SSHForwardChannel channel,
    String targetHost,
    int targetPort,
    _ForwardTraffic traffic,
  ) async {
    traffic.opened();
    try {
      final socket = await Socket.connect(targetHost, targetPort);
      await _pumpForward(
        fromServer: channel.stream.cast<List<int>>(),
        toLocal: socket,
        fromLocal: socket.cast<List<int>>(),
        toServer: channel.sink,
        traffic: traffic,
      );
    } catch (_) {
      await channel.sink.close();
    } finally {
      traffic.closed();
    }
  }

  void _emitPortForwards() => _portForwardController.add(currentPortForwards);

  /// Current traffic readings for every active forward, keyed by forward id.
  Map<String, PortForwardMetrics> portForwardMetrics() => {
    for (final entry in _portForwards.entries)
      entry.key: entry.value.traffic.snapshot(),
  };

  /// Returns the retained authenticated client for [serverId], if available.
  ///
  /// Feature code should reuse this client for remote operations instead of
  /// opening a second transport connection.
  SSHClient? clientFor(int serverId) {
    final client = _sessions[serverId];
    return client == null || client.isClosed ? null : client;
  }

  Future<T> withClient<T>(
    int serverId,
    Future<T> Function(SSHClient client) run,
  ) {
    final client = clientFor(serverId);
    if (client == null) throw const ServerConnectionRequiredException();
    return run(client);
  }

  /// Size requested for every new PTY; the emulator starts at the same size.
  static const terminalColumns = 120;
  static const terminalRows = 36;

  /// Opens an authenticated shell and returns its transport handle.
  ///
  /// The manager stays transport-only: rendering and emulation are attached
  /// by the caller, which also decides when the terminal disappears from the
  /// UI. The shell ending (`exit`, logout, network drop) completes
  /// [TerminalTransport.done] and releases the SSH client here.
  Future<TerminalTransport> openTerminal(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    String? initialDirectory,
    ServerProxy? proxy,
    Map<String, String>? environment,
    List<String>? initialScripts,
  }) async {
    final client = await _createClient(
      server,
      credential,
      approve,
      knownHostKeyFingerprint: knownHostKeyFingerprint,
      proxy: proxy,
    );
    late SSHSession shell;
    try {
      shell = await client.shell(
        pty: const SSHPtyConfig(
          type: 'xterm-256color',
          width: terminalColumns,
          height: terminalRows,
        ),
        environment: environment,
      );
    } catch (_) {
      client.close();
      rethrow;
    }
    final terminalId = 'terminal-${_nextTerminalId++}';
    _terminals[terminalId] = _TerminalConnection(
      serverId: server.id,
      jumpHostServerId: server.jumpHostServerId,
      client: client,
      shell: shell,
    );
    // A remote shell ending is normal (`exit`, a logout, or a network drop).
    // Do not use `whenComplete` here: its returned future re-emits an SSH
    // channel error and, because this is fire-and-forget cleanup, would become
    // an unhandled application error.
    shell.done.then<void>(
      (_) => _closeTerminalAfterShellEnds(terminalId, shell),
      onError: (_, _) => _closeTerminalAfterShellEnds(terminalId, shell),
    );
    final directory = initialDirectory?.trim();
    if (directory != null && directory.isNotEmpty) {
      // Move into the requested remote folder after the shell starts. Quote the
      // path so spaces and special characters remain literal.
      shell.write(utf8.encode('cd ${_shellSingleQuote(directory)}\n'));
    }
    // Configured initial snippets run once the shell is ready, after any
    // requested directory change. They are written as typed commands so the
    // user sees and can interrupt them.
    for (final script in initialScripts ?? const <String>[]) {
      if (script.trim().isEmpty) continue;
      shell.write(utf8.encode('$script\n'));
    }
    return TerminalTransport(
      id: terminalId,
      columns: terminalColumns,
      rows: terminalRows,
      stdout: shell.stdout,
      stderr: shell.stderr,
      write: shell.write,
      resize: shell.resizeTerminal,
      done: shell.done,
      close: () => closeTerminal(terminalId),
    );
  }

  /// POSIX-safe single-quoted string for remote shell commands.
  String _shellSingleQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  Future<void> closeTerminal(String terminalId) async {
    final terminal = _terminals.remove(terminalId);
    if (terminal == null) return;
    // The remote shell may already have closed its channel by the time this
    // runs. Treat those close races as successful cleanup rather than letting
    // an `exit` command escape as an unhandled error.
    try {
      await terminal.shell.stdin.close();
    } catch (_) {}
    terminal.client.close();
  }

  /// Measures an SSH command round trip for an open terminal connection.
  ///
  /// Using the existing authenticated transport makes this work when ICMP is
  /// unavailable and avoids opening an additional socket just for the status
  /// bar.
  Future<Duration?> measureTerminalLatency(String terminalId) async {
    final terminal = _terminals[terminalId];
    if (terminal == null || terminal.client.isClosed) return null;

    final latency = await _probeLatency(terminal.client);
    return latency != null && identical(_terminals[terminalId], terminal)
        ? latency
        : null;
  }

  void _closeTerminalAfterShellEnds(String terminalId, SSHSession shell) {
    if (!identical(_terminals[terminalId]?.shell, shell)) return;
    unawaited(closeTerminal(terminalId).catchError((_) {}));
  }

  /// Refreshes latency and, per the server's settings, statistics. Detail
  /// pages also ask for system information; background refreshes of server
  /// lists pass [includeSystemInfo] false to keep the round trips cheap.
  Future<void> refreshServerInfo(
    Server server, {
    bool includeSystemInfo = true,
  }) async {
    final client = clientFor(server.id);
    final state = _states[server.id];
    if (client == null || client.isClosed || state == null) return;
    await _refreshNetworkLatency(server, state);
    if (server.collectStats) {
      await _refreshStats(client, _states[server.id] ?? state);
    }
    if (includeSystemInfo && server.collectSystemInfo) {
      await _refreshSystemInfo(client, _states[server.id] ?? state);
    }
  }

  /// Measures the SSH round trip on the live session, so the reading follows
  /// whatever path the connection actually takes (proxy, jump host, VPN) —
  /// unlike a direct ICMP ping, which those paths don't carry.
  Future<void> _refreshNetworkLatency(
    Server server,
    SshSessionInfo state,
  ) async {
    final client = _sessions[server.id];
    if (client == null || client.isClosed) return;
    final latency = await _probeLatency(client);
    if (latency == null || !identical(_sessions[server.id], client)) return;
    _set((_states[server.id] ?? state).copyWith(networkLatency: latency));
  }

  /// Measures one SSH command round trip on [client], or returns `null` if
  /// the probe fails.
  Future<Duration?> _probeLatency(SSHClient client) async {
    final stopwatch = Stopwatch()..start();
    try {
      // The bare no-op keeps the reading a pure round trip.
      await _execute(client, ':', prependToolPath: false);
      return stopwatch.elapsed;
    } catch (_) {
      return null;
    }
  }

  static const processListLimit = 250;

  Future<List<ServerProcess>> listProcesses(int serverId) async {
    return withClient(serverId, (client) async {
      // Sort once on the host so head keeps top CPU/RSS-relevant rows without
      // shipping the entire process table. Avoid polling this every few seconds
      // when the Processes tab is not visible.
      final windowsResult = await _execute(
        client,
        _windowsProcessCommand(processListLimit),
      );
      if (windowsResult.exitCode == 0 &&
          windowsResult.stdout.contains('--WINDOWS--')) {
        return windowsResult.stdout
            .split('\n')
            .where((line) => !line.startsWith('--WINDOWS--'))
            .map(_parseProcess)
            .whereType<ServerProcess>()
            .toList();
      }
      final result = await _execute(client, '''sh -c '
if ps -eo pid=,user=,%cpu=,%mem=,rss=,comm= --sort=-%cpu >/dev/null 2>&1; then
  ps -eo pid=,user=,%cpu=,%mem=,rss=,comm= --sort=-%cpu | head -n $processListLimit
else
  ps -Ao pid=,user=,%cpu=,%mem=,rss=,comm= -r | head -n $processListLimit
fi
' ''');
      return result.stdout
          .split('\n')
          .map(_parseProcess)
          .whereType<ServerProcess>()
          .toList();
    });
  }

  /// Sends SIGKILL to [pid] on the remote host.
  ///
  /// Tries as the SSH user first; if that fails and elevation is available
  /// (root session or sudo), retries with privileges so other users' processes
  /// can be killed from a normal admin login.
  Future<void> killProcess(
    int serverId, {
    required int pid,
    bool sshUserIsRoot = false,
    String? sudoPassword,
  }) async {
    if (pid <= 1) {
      throw StateError('Refusing to send SIGKILL to pid $pid.');
    }
    await withClient(serverId, (client) async {
      final command = 'kill -s KILL -- $pid';
      var result = await _execute(client, command);
      if (result.exitCode == 0) return;

      if (!sshUserIsRoot) {
        final elevated = await _execute(
          client,
          '${_rootPrefix(false, sudoPassword)}$command',
          stdin: sudoPassword,
        );
        if (elevated.exitCode == 0) return;
        result = elevated;
      }

      throw Exception(_commandError(result));
    });
  }

  /// Collects raw host counters for the Activity tab in a single SSH
  /// round-trip.
  Future<ActivityCounters> collectActivityCounters(int serverId) async {
    return withClient(serverId, (client) async {
      final result = await _execute(client, '''
sh -c '
if [ -r /proc/stat ]; then
  echo --STAT--
  head -n 1 /proc/stat 2>/dev/null || true
  echo --LOAD--
  cat /proc/loadavg 2>/dev/null || true
  echo --CPU--
  getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1
  echo --MEM--
  cat /proc/meminfo 2>/dev/null || true
  echo --DISK--
  df -Pk / 2>/dev/null | tail -n 1 || true
  echo --NET--
  cat /proc/net/dev 2>/dev/null || true
  echo --UPTIME--
  cut -d. -f1 /proc/uptime 2>/dev/null || true
  echo --GPU--
  $nvidiaGpuQuery 2>/dev/null || true
else
  echo --STAT--
  sysctl -n kern.cp_time 2>/dev/null || true
  echo --LOAD--
  sysctl -n vm.loadavg 2>/dev/null || true
  echo --CPU--
  sysctl -n hw.ncpu 2>/dev/null || true
  echo --MEM--
  sysctl -n hw.memsize 2>/dev/null || true
  echo --VMSTAT--
  vm_stat 2>/dev/null || true
  echo --SWAP--
  sysctl -n vm.swapusage 2>/dev/null || true
  echo --DISK--
  df -Pk / 2>/dev/null || true
  echo --NET--
  netstat -ib 2>/dev/null || true
  echo --UPTIME--
  sysctl -n kern.boottime 2>/dev/null || true
fi
'
''');
      final counters = _parseActivityCounters(result.stdout);
      if (result.exitCode == 0 && _hasActivityData(counters)) {
        return counters;
      }
      final windowsResult = await _execute(client, windowsHostMetricsCommand());
      if (windowsResult.exitCode == 0 &&
          windowsResult.stdout.contains('--WINDOWS--')) {
        return _parseActivityCounters(windowsResult.stdout);
      }
      if (result.exitCode != 0 && result.stdout.trim().isEmpty) {
        throw StateError(_commandError(result));
      }
      return counters;
    });
  }

  bool _hasActivityData(ActivityCounters counters) =>
      counters.load1 != null ||
      counters.cpuCount != null ||
      counters.memoryTotalKb != null ||
      counters.diskTotalKb != null ||
      counters.netRxBytes != null ||
      counters.uptime != null;

  ActivityCounters _parseActivityCounters(String output) {
    final now = DateTime.now();
    return parseHostMetrics(output, now: now).toActivityCounters(at: now);
  }

  String _rootPrefix(bool sshUserIsRoot, String? sudoPassword) {
    if (sshUserIsRoot) return '';
    return sudoPassword == null ? 'sudo -n ' : 'sudo -S -p "" ';
  }

  /// Runs one non-interactive command. Every remote command goes through
  /// here; [prependToolPath] exports [_remoteToolPath] first so user-installed
  /// tools resolve, and is turned off only where the command must run exactly
  /// as written (latency probes, the metrics collectors' portable scripts).
  Future<_CommandResult> _execute(
    SSHClient client,
    String command, {
    String? stdin,
    bool prependToolPath = true,
  }) async {
    final session = await client.execute(
      prependToolPath ? _withRemoteToolPath(command) : command,
    );
    final stdout = utf8.decoder.bind(session.stdout).join();
    final stderr = utf8.decoder.bind(session.stderr).join();
    if (stdin != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode('$stdin\n')));
      await session.stdin.close();
    }
    await session.done;
    return _CommandResult(
      stdout: await stdout,
      stderr: await stderr,
      exitCode: session.exitCode ?? 1,
    );
  }

  String _withRemoteToolPath(String command) =>
      'export PATH="$_remoteToolPath:\$PATH"; $command';

  String _commandError(_CommandResult result) {
    final message = result.stderr.trim().isNotEmpty
        ? result.stderr.trim()
        : result.stdout.trim();
    return message.isEmpty
        ? 'The command exited with code ${result.exitCode}.'
        : message;
  }

  Future<void> _refreshStats(SSHClient client, SshSessionInfo state) async {
    try {
      final stats = await _metricsCollector.collect(
        (command) async =>
            (await _execute(client, command, prependToolPath: false)).stdout,
      );
      if (stats != null && identical(_sessions[state.serverId], client)) {
        _set((_states[state.serverId] ?? state).copyWith(stats: stats));
      }
    } catch (_) {
      // Statistics are optional and can be unavailable on restricted hosts.
    }
  }

  Future<void> _refreshSystemInfo(
    SSHClient client,
    SshSessionInfo state,
  ) async {
    try {
      final windowsResult = await _execute(client, _windowsSystemInfoCommand());
      if (windowsResult.exitCode == 0 &&
          windowsResult.stdout.contains('--WINDOWS--')) {
        final values = windowsResult.stdout
            .split('\n')
            .where((line) => line.isNotEmpty && line != '--WINDOWS--')
            .toList();
        if (values.isNotEmpty && identical(_sessions[state.serverId], client)) {
          _set(
            (_states[state.serverId] ?? state).copyWith(
              systemInfo: ServerSystemInfo(
                distribution: values.first,
                kernel: values.length > 1 ? values[1] : null,
              ),
            ),
          );
        }
        return;
      }
      final result = await _execute(client, r"""sh -c '
if command -v sw_vers >/dev/null 2>&1; then
  printf "%s %s\n" "$(sw_vers -productName)" "$(sw_vers -productVersion)"
elif [ -r /etc/os-release ]; then
  . /etc/os-release
  printf "%s\n" "$PRETTY_NAME"
else
  uname -s
fi
uname -s
'""");
      final values = result.stdout.trim().split('\n');
      if (values.isNotEmpty && identical(_sessions[state.serverId], client)) {
        _set(
          (_states[state.serverId] ?? state).copyWith(
            systemInfo: ServerSystemInfo(
              distribution: values.firstOrNull,
              kernel: values.length > 1 ? values[1] : null,
            ),
          ),
        );
      }
    } catch (_) {
      // System information is optional on restricted or non-POSIX hosts.
    }
  }

  /// Opens the retained statistics session for [server].
  ///
  /// A second call for the same server while one is in flight joins it. A
  /// [disconnect] during the handshake cancels it: the authenticated client
  /// is closed as soon as it arrives and the status stays closed.
  Future<void> connect(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    ServerProxy? proxy,
  }) {
    final pending = _pendingConnects[server.id];
    if (pending != null) return pending;
    late final Future<void> future;
    future =
        _connect(
          server,
          credential,
          approve,
          knownHostKeyFingerprint: knownHostKeyFingerprint,
          proxy: proxy,
        ).whenComplete(() {
          if (identical(_pendingConnects[server.id], future)) {
            _pendingConnects.remove(server.id);
          }
        });
    _pendingConnects[server.id] = future;
    return future;
  }

  Future<void> _connect(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    required String? knownHostKeyFingerprint,
    required ServerProxy? proxy,
  }) async {
    await disconnect(server.id);
    final generation = _connectGenerations[server.id] ?? 0;
    bool cancelled() => _connectGenerations[server.id] != generation;
    _set(
      SshSessionInfo(
        serverId: server.id,
        serverName: server.name,
        connectedAt: DateTime.now(),
        status: SessionStatus.connecting,
        authMethod: credential.type,
      ),
    );
    String? serverAuthMethods;
    try {
      final client = await _createClient(
        server,
        credential,
        approve,
        knownHostKeyFingerprint: knownHostKeyFingerprint,
        onAuthMethods: (methods) => serverAuthMethods = methods,
        proxy: proxy,
      );
      if (cancelled()) {
        // disconnect() already reported the closed status; never keep an
        // authenticated client nobody tracks.
        client.close();
        return;
      }
      _sessions[server.id] = client;
      _sessionJumpHosts[server.id] = server.jumpHostServerId;
      _set(
        _states[server.id]!.copyWith(
          status: SessionStatus.connected,
          clearError: true,
        ),
      );
      _connectedController.add(server.id);
      // Listen before issuing probes: a transport can fail while the first
      // command is being opened, and [SSHClient.done] completes with that
      // transport error.
      unawaited(
        client.done.then<void>(
          (_) => _handleClientClosed(server, client),
          onError: (Object error, StackTrace _) {
            _handleClientClosed(server, client, error: error);
          },
        ),
      );
      unawaited(
        _refreshNetworkLatency(server, _states[server.id]!).catchError((_) {}),
      );
      unawaited(_refreshConnectionDetails(server, client));
    } catch (error) {
      if (cancelled()) return;
      if (error is SSHAuthFailError) {
        final exception = SshAuthenticationException(
          _describeAuthFailure(
            credentialType: credential.type,
            serverAuthMethods: serverAuthMethods,
          ),
          credentialType: credential.type,
          serverAuthMethods: serverAuthMethods,
        );
        _setFailed(server.id, exception.message);
        throw exception;
      }
      _setFailed(server.id, error.toString());
      rethrow;
    }
  }

  void _setFailed(int serverId, String message) {
    final state = _states[serverId];
    if (state == null) return;
    _set(state.copyWith(status: SessionStatus.failed, error: message));
  }

  /// Teardown when the statistics transport drops on its own.
  ///
  /// Terminals of this server are deliberately left alone: each terminal owns
  /// an independent transport (see [_sessions]), so losing the statistics
  /// client says nothing about them, and their own `done` handlers close
  /// them when their transport fails. What does depend on this client is
  /// everything tunnelled through it — port forwards, and the sessions and
  /// terminals of servers that use this one as a jump host — and those are
  /// closed here exactly as [disconnect] closes them.
  void _handleClientClosed(Server server, SSHClient client, {Object? error}) {
    if (!identical(_sessions[server.id], client)) return;
    _sessions.remove(server.id);
    _sessionJumpHosts.remove(server.id);
    unawaited(_closeDependentSessions(server.id));
    unawaited(_closeTerminalsForJumpHost(server.id));
    unawaited(_stopPortForwardsFor(server.id));
    final state = _states[server.id];
    if (state != null && state.status == SessionStatus.connected) {
      _set(
        state.copyWith(
          status: SessionStatus.closed,
          error: error == null ? 'SSH connection closed.' : error.toString(),
        ),
      );
    }
  }

  Future<void> _refreshConnectionDetails(
    Server server,
    SSHClient client,
  ) async {
    final state = _states[server.id];
    if (!identical(_sessions[server.id], client) || state == null) return;
    if (server.collectStats) await _refreshStats(client, state);
    if (server.collectSystemInfo) {
      await _refreshSystemInfo(client, _states[server.id] ?? state);
    }
  }

  /// Closes the statistics session and everything tunnelled through it.
  /// Terminals of the server itself keep running on their own transports;
  /// a connect still in flight is cancelled.
  Future<void> disconnect(int serverId) async {
    _connectGenerations[serverId] = (_connectGenerations[serverId] ?? 0) + 1;
    _pendingConnects.remove(serverId);
    await _closeDependentSessions(serverId);
    await _stopPortForwardsFor(serverId);
    await _closeTerminalsForJumpHost(serverId);
    final client = _sessions.remove(serverId);
    _sessionJumpHosts.remove(serverId);
    client?.close();
    final state = _states[serverId];
    if (state != null) _set(state.copyWith(status: SessionStatus.closed));
  }

  /// The server was deleted: disconnect it, close its terminals and drop its
  /// session state so it no longer appears in [current].
  Future<void> forgetServer(int serverId) async {
    await disconnect(serverId);
    await _closeTerminalsFor(serverId);
    if (_states.remove(serverId) != null) _controller.add(current);
  }

  /// Connects every jump host on the way to [server], root first, calling
  /// [connectHop] for each hop that is not connected yet. [server] itself is
  /// not connected; callers decide whether it needs a statistics session or
  /// a terminal. [servers] resolves jump-host ids; a missing hop or a cycle
  /// throws a [StateError].
  Future<void> connectJumpHosts(
    Server server,
    Iterable<Server> servers, {
    required Future<void> Function(Server hop) connectHop,
  }) async {
    final byId = {for (final candidate in servers) candidate.id: candidate};
    Future<void> visit(Server current, Set<int> visiting) async {
      if (clientFor(current.id) != null) return;
      final jumpHostId = current.jumpHostServerId;
      if (jumpHostId == null) return;
      if (!visiting.add(current.id)) {
        throw StateError('Jump-host cycle detected at ${current.name}.');
      }
      final jumpHost = byId[jumpHostId];
      if (jumpHost == null) {
        throw StateError(
          'Jump host $jumpHostId for ${current.name} no longer exists.',
        );
      }
      await visit(jumpHost, visiting);
      if (clientFor(jumpHost.id) == null) await connectHop(jumpHost);
      visiting.remove(current.id);
    }

    await visit(server, <int>{});
  }

  void _set(SshSessionInfo value) {
    _states[value.serverId] = value;
    _controller.add(current);
  }

  Future<void> dispose() async {
    for (final terminalId in _terminals.keys.toList()) {
      await closeTerminal(terminalId);
    }
    for (final serverId in {..._sessions.keys, ..._pendingConnects.keys}) {
      await disconnect(serverId);
    }
    for (final id in _portForwards.keys.toList()) {
      await stopPortForward(id);
    }
    await _controller.close();
    await _portForwardController.close();
    await _connectedController.close();
  }

  Future<void> _closeDependentSessions(int serverId) async {
    final dependentIds = _sessionJumpHosts.entries
        .where((entry) => entry.value == serverId)
        .map((entry) => entry.key)
        .toList();
    for (final dependentId in dependentIds) {
      await disconnect(dependentId);
    }
  }

  Future<void> _stopPortForwardsFor(int serverId) async {
    final ids = _portForwards.entries
        .where((entry) => entry.value.info.serverId == serverId)
        .map((entry) => entry.key)
        .toList();
    for (final id in ids) {
      await stopPortForward(id);
    }
  }

  Future<void> _closeTerminalsFor(int serverId) async {
    final terminalIds = _terminals.entries
        .where((entry) => entry.value.serverId == serverId)
        .map((entry) => entry.key)
        .toList();
    for (final terminalId in terminalIds) {
      await closeTerminal(terminalId);
    }
  }

  Future<void> _closeTerminalsForJumpHost(int serverId) async {
    final terminalIds = _terminals.entries
        .where((entry) => entry.value.jumpHostServerId == serverId)
        .map((entry) => entry.key)
        .toList();
    for (final terminalId in terminalIds) {
      await closeTerminal(terminalId);
    }
  }

  ServerProcess? _parseProcess(String line) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < 6) return null;
    final pid = int.tryParse(fields[0]);
    final cpuPercent = double.tryParse(fields[2]);
    final memoryPercent = double.tryParse(fields[3]);
    final rssKb = int.tryParse(fields[4]);
    if (pid == null ||
        cpuPercent == null ||
        memoryPercent == null ||
        rssKb == null) {
      return null;
    }
    return ServerProcess(
      pid: pid,
      user: fields[1],
      cpuPercent: cpuPercent,
      memoryPercent: memoryPercent,
      rssKb: rssKb,
      command: fields.sublist(5).join(' '),
    );
  }

  Future<SSHClient> _createClient(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    void Function(String? methods)? onAuthMethods,
    ServerProxy? proxy,
  }) async {
    final identities = credential.type == CredentialType.privateKey
        ? SSHKeyPair.fromPem(credential.privateKey!, credential.keyPassphrase)
        : null;
    late final SSHSocket rawSocket;
    if (server.jumpHostServerId != null) {
      rawSocket = await _socketThroughJumpHost(server);
    } else {
      rawSocket = await _LowLatencySshSocket.connect(
        server.host,
        server.port,
        proxy: proxy,
      );
    }
    final socket = _SafeSshSocket(rawSocket);
    final client = SSHClient(
      socket,
      username: server.username,
      identities: identities,
      onPasswordRequest: credential.type == CredentialType.password
          ? () => credential.password
          : null,
      onUserInfoRequest: credential.type == CredentialType.password
          ? (request) => List<String>.filled(
              request.prompts.length,
              credential.password!,
            )
          : null,
      onVerifyHostKey: (algorithm, fingerprint) {
        final presented =
            'SHA256:${base64Encode(fingerprint).replaceAll('=', '')}';
        if (knownHostKeyFingerprint == presented) return true;
        return approve(
          HostKeyPrompt(
            algorithm: algorithm,
            fingerprint: presented,
            replacesExisting: knownHostKeyFingerprint != null,
          ),
        );
      },
      printTrace: (message) {
        final match = RegExp(
          r'SSH_Message_Userauth_Failure\(methodsLeft: \[(.*?)\]',
        ).firstMatch(message ?? '');
        if (match != null) onAuthMethods?.call(match.group(1));
      },
      handshakeTimeout: const Duration(seconds: 15),
      authTimeout: const Duration(seconds: 15),
      ident: "Conduit",
    );
    await client.authenticated;
    return client;
  }

  Future<SSHSocket> _socketThroughJumpHost(Server server) async {
    final jumpHostServerId = server.jumpHostServerId!;
    final jumpClient = clientFor(jumpHostServerId);
    if (jumpClient == null) {
      throw JumpHostConnectionRequiredException(jumpHostServerId);
    }
    return jumpClient.forwardLocal(server.host, server.port);
  }
}

/// Prevents dartssh2's asynchronous channel uploader from throwing after the
/// underlying socket has already completed. The transport closure is still
/// reported through [SSHClient.done]; closed writes are deliberately dropped.
class _SafeSshSocket implements SSHSocket {
  _SafeSshSocket(this._delegate) {
    unawaited(
      _delegate.done.then<void>(
        (_) => _closed = true,
        onError: (_, _) => _closed = true,
      ),
    );
  }

  final SSHSocket _delegate;
  var _closed = false;
  late final StreamSink<List<int>> _safeSink = _SafeSshSink(
    _delegate.sink,
    () => _closed,
    () => _closed = true,
  );

  @override
  Stream<Uint8List> get stream => _delegate.stream;
  @override
  StreamSink<List<int>> get sink => _safeSink;

  @override
  Future<void> get done => _delegate.done;

  @override
  Future<void> close() => _delegate.close();

  @override
  void destroy() => _delegate.destroy();

  @override
  Future<void> flush() => _delegate.flush();

  @override
  String toString() => _delegate.toString();
}

class _SafeSshSink implements StreamSink<List<int>> {
  _SafeSshSink(this._delegate, this._isClosed, this._markClosed);

  final StreamSink<List<int>> _delegate;
  final bool Function() _isClosed;
  final void Function() _markClosed;

  @override
  void add(List<int> data) {
    if (_isClosed()) return;
    try {
      _delegate.add(data);
    } on StateError catch (error) {
      if (!error.toString().contains('StreamSink is bound to a stream')) {
        rethrow;
      }
      _markClosed();
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isClosed()) return;
    _delegate.addError(error, stackTrace);
  }

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<void> get done => _delegate.done;

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      _delegate.addStream(stream);
}

/// An SSH socket with Nagle's algorithm disabled.
///
/// Interactive terminals commonly send one small packet for each key press.
/// Waiting for an acknowledgement before transmitting a subsequent packet can
/// turn normal network round-trip time into very noticeable typing lag.
class _LowLatencySshSocket implements SSHSocket {
  _LowLatencySshSocket._(this._socket);

  final Socket _socket;

  static Future<SSHSocket> connect(
    String host,
    int port, {
    ServerProxy? proxy,
  }) async {
    if (proxy == null || proxy.type == ServerProxyType.none) {
      final socket = await Socket.connect(host, port);
      socket.setOption(SocketOption.tcpNoDelay, true);
      return _LowLatencySshSocket._(socket);
    }
    return connectThroughProxy(proxy, host, port);
  }

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  Future<void> flush() => _socket.flush();

  @override
  String toString() => _socket.toString();
}

/// Transport-only handle for one remote shell: byte streams in and out,
/// window-size changes and completion. It carries no emulator state.
class TerminalTransport {
  const TerminalTransport({
    required this.id,
    required this.columns,
    required this.rows,
    required this.stdout,
    required this.stderr,
    required this._write,
    required this._resize,
    required this.done,
    required this._close,
  });

  final String id;

  /// PTY size requested when the shell was opened.
  final int columns;
  final int rows;

  final Stream<Uint8List> stdout;
  final Stream<Uint8List> stderr;

  /// Completes when the remote shell ends, with or without an error.
  final Future<void> done;

  final void Function(Uint8List bytes) _write;
  final void Function(int columns, int rows, int pixelWidth, int pixelHeight)
  _resize;
  final Future<void> Function() _close;

  void write(Uint8List bytes) => _write(bytes);

  void resize(int columns, int rows, int pixelWidth, int pixelHeight) =>
      _resize(columns, rows, pixelWidth, pixelHeight);

  /// Closes the shell and its SSH client; safe to call after [done].
  Future<void> close() => _close();
}

class _TerminalConnection {
  const _TerminalConnection({
    required this.serverId,
    required this.jumpHostServerId,
    required this.client,
    required this.shell,
  });

  final int serverId;
  final int? jumpHostServerId;
  final SSHClient client;
  final SSHSession shell;
}

class _PortForwardingConnection {
  _PortForwardingConnection.local(this.info, this.localListener)
    : remoteForward = null;

  _PortForwardingConnection.remote(this.info, this.remoteForward)
    : localListener = null;

  final ActivePortForward info;
  final ServerSocket? localListener;
  final SSHRemoteForward? remoteForward;
  final traffic = _ForwardTraffic();
  StreamSubscription<Object?>? subscription;

  Future<void> close() async {
    await subscription?.cancel();
    await localListener?.close();
    remoteForward?.close();
  }
}

/// Mutable traffic counters for one forward; snapshots become
/// [PortForwardMetrics].
class _ForwardTraffic {
  final DateTime startedAt = DateTime.now();
  int activeConnections = 0;
  int totalConnections = 0;
  int bytesUp = 0;
  int bytesDown = 0;
  DateTime? lastActivityAt;

  void opened() {
    activeConnections++;
    totalConnections++;
    lastActivityAt = DateTime.now();
  }

  void closed() {
    if (activeConnections > 0) activeConnections--;
  }

  void addUp(int bytes) {
    bytesUp += bytes;
    lastActivityAt = DateTime.now();
  }

  void addDown(int bytes) {
    bytesDown += bytes;
    lastActivityAt = DateTime.now();
  }

  PortForwardMetrics snapshot() => PortForwardMetrics(
    startedAt: startedAt,
    activeConnections: activeConnections,
    totalConnections: totalConnections,
    bytesUp: bytesUp,
    bytesDown: bytesDown,
    lastActivityAt: lastActivityAt,
  );
}

class _CommandResult {
  const _CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}

String _windowsProcessCommand(int limit) => encodePowerShellCommand('''
\$ErrorActionPreference = 'Stop'
\$os = Get-CimInstance Win32_OperatingSystem
\$totalMemory = [double]\$os.TotalVisibleMemorySize * 1KB
Write-Output '--WINDOWS--'
Get-Process |
  Sort-Object WorkingSet64 -Descending |
  Select-Object -First $limit |
  ForEach-Object {
    \$memoryPercent = if (\$totalMemory -gt 0) {
      100 * \$_.WorkingSet64 / \$totalMemory
    } else { 0 }
    '{0} {1} 0 {2} {3} {4}' -f \$_.Id, \$env:USERNAME,
      ([math]::Round(\$memoryPercent, 2)),
      ([int64](\$_.WorkingSet64 / 1KB)), \$_.ProcessName
  }
''');

String _windowsSystemInfoCommand() => encodePowerShellCommand(r'''
$ErrorActionPreference = 'Stop'
$os = Get-CimInstance Win32_OperatingSystem
Write-Output '--WINDOWS--'
$os.Caption
Write-Output 'Windows NT'
''');
