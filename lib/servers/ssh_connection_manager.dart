import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:conduit/data/local/app_database.dart';
import 'activity_models.dart';
import 'package_models.dart';
import 'port_forwarding_models.dart';
import 'server_metrics_collector.dart';
import 'server_models.dart';
import 'ssh_proxy_connect.dart';
import 'socks5_protocol.dart';
import 'terminal_session_adapter.dart';

typedef HostKeyApproval = Future<bool> Function(HostKeyPrompt prompt);

/// Explains an authentication failure in terms of the credential that was
/// actually offered. [serverAuthMethods] is the `methodsLeft` list from the
/// server's userauth failure, so it names what the server still accepts —
/// not what Conduit tried.
String sshAuthFailureMessage({
  required CredentialType credentialType,
  String? serverAuthMethods,
}) {
  final usedKey = credentialType == CredentialType.privateKey;
  final methods = (serverAuthMethods ?? '')
      .split(',')
      .map((method) => method.trim())
      .where((method) => method.isNotEmpty)
      .toList();
  final buffer = StringBuffer(
    usedKey
        ? 'Conduit offered the private key and the server rejected it.'
        : 'Conduit offered the password and the server rejected it.',
  );
  if (methods.isNotEmpty) {
    buffer.write(' The server accepts: ${methods.join(', ')}.');
  }
  if (usedKey && methods.contains('publickey')) {
    buffer.write(
      ' Check that the matching public key is in authorized_keys for this '
      'user and that the home and .ssh directories are not group-writable.',
    );
  } else if (usedKey && methods.isNotEmpty) {
    buffer.write(' This server does not offer public key authentication.');
  } else if (!usedKey && methods.contains('publickey')) {
    buffer.write(
      ' This server also accepts public keys; switch the credential to a '
      'private key if password logins are restricted.',
    );
  }
  return buffer.toString();
}

/// Wraps an authentication failure so every caller — session card and
/// snackbar alike — reports [message] instead of dartssh2's generic
/// "All authentication methods failed".
class SshAuthenticationException implements Exception {
  const SshAuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SshConnectionManager {
  SshConnectionManager(
    this._terminalAdapterFactory, {
    ServerMetricsCollector? metricsCollector,
    this.onConnected,
  }) : _metricsCollector = metricsCollector ?? AutoServerMetricsCollector();

  final TerminalSessionAdapterFactory Function() _terminalAdapterFactory;
  final ServerMetricsCollector _metricsCollector;

  /// Fired after a server's SSH session becomes connected. Used to start
  /// saved port-forwarding presets that opted into auto-start. Failures are
  /// handled by the caller; the connection itself is unaffected.
  final void Function(Server server)? onConnected;

  /// These clients are used exclusively for collecting server information.
  /// Terminal shells keep their own clients so reconnecting statistics never
  /// interrupts an interactive session.
  final _sessions = <int, SSHClient>{};

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
        final info = existing.info;
        if (info.serverId == server.id &&
            info.direction == direction &&
            info.kind == kind &&
            info.bindHost == bindHost &&
            info.bindPort == bindPort &&
            info.targetHost == targetHost &&
            info.targetPort == targetPort) {
          return info;
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

  Future<TerminalSessionHandle> openTerminal(
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
        pty: const SSHPtyConfig(type: 'xterm-256color', width: 120, height: 36),
        environment: environment,
      );
    } catch (_) {
      client.close();
      rethrow;
    }
    final terminal = _terminalAdapterFactory().create();
    final terminalId = 'terminal-${_nextTerminalId++}';
    final binding = TerminalSessionBinding(
      adapter: terminal,
      stdout: shell.stdout,
      stderr: shell.stderr,
      send: shell.write,
      resize: (event) => shell.resizeTerminal(
        event.columns,
        event.rows,
        event.pixelWidth,
        event.pixelHeight,
      ),
    );
    _terminals[terminalId] = _TerminalConnection(
      serverId: server.id,
      jumpHostServerId: server.jumpHostServerId,
      client: client,
      shell: shell,
      binding: binding,
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
    return TerminalSessionHandle(
      id: terminalId,
      adapter: terminal,
      done: shell.done,
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
    try {
      await terminal.binding.close();
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

  Future<void> refreshServerInfo(Server server) async {
    final client = clientFor(server.id);
    final state = _states[server.id];
    if (client == null || client.isClosed || state == null) return;
    await _refreshNetworkLatency(server, state);
    if (server.collectStats) {
      await _refreshStats(client, _states[server.id] ?? state);
    }
    if (server.collectSystemInfo) {
      await _refreshSystemInfo(client, _states[server.id] ?? state);
    }
  }

  /// Refreshes only the dynamic, low-cost metrics used by server lists and
  /// background connections. Detail pages call [refreshServerInfo] instead.
  Future<void> refreshBasicServerInfo(Server server) async {
    final client = clientFor(server.id);
    final state = _states[server.id];
    if (client == null || client.isClosed || state == null) return;
    await _refreshNetworkLatency(server, state);
    if (server.collectStats) {
      await _refreshStats(client, _states[server.id] ?? state);
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
      final session = await client.execute(':');
      await session.done;
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
      final session = await client.execute('''sh -c '
if ps -eo pid=,user=,%cpu=,%mem=,rss=,comm= --sort=-%cpu >/dev/null 2>&1; then
  ps -eo pid=,user=,%cpu=,%mem=,rss=,comm= --sort=-%cpu | head -n $processListLimit
else
  ps -Ao pid=,user=,%cpu=,%mem=,rss=,comm= -r | head -n $processListLimit
fi
' ''');
      final output = await utf8.decoder.bind(session.stdout).join();
      await session.done;
      return output
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
          stdin: _rootStdin(false, sudoPassword),
        );
        if (elevated.exitCode == 0) return;
        result = elevated;
      }

      throw Exception(_commandError(result));
    });
  }

  /// Detects package tools available on the remote host and reads its pending
  /// update list with the preferred tool. No package indexes are changed.
  Future<PackageManagerStatus> getPackageManagerStatus(
    int serverId, {
    PackageManager? preferredManager,
  }) async {
    return withClient(serverId, (client) async {
      const managers = PackageManager.values;
      final detected = <PackageManager>[];
      for (final manager in managers) {
        final executable = _packageExecutable(manager);
        final result = await _execute(client, 'command -v $executable');
        if (result.exitCode == 0) detected.add(manager);
      }
      if (detected.isEmpty) {
        return const PackageManagerStatus(
          available: [],
          manager: null,
          installedPackageCount: null,
          outdatedPackages: [],
        );
      }
      final manager = detected.contains(preferredManager)
          ? preferredManager!
          : detected.first;
      final installed = await _execute(
        client,
        _installedPackageCountCommand(manager),
      );
      final updates = await _execute(client, _packageOutdatedCommand(manager));
      // Each package manager uses a non-zero exit status to describe an empty
      // update list in at least some releases, so parse stdout regardless.
      return PackageManagerStatus(
        available: detected,
        manager: manager,
        installedPackageCount: int.tryParse(installed.stdout.trim()),
        outdatedPackages: _parsePackageNames(updates.stdout),
      );
    });
  }

  Future<void> runPackageAction(
    int serverId, {
    required PackageManager manager,
    required PackageAction action,
    String? packageName,
    required bool sshUserIsRoot,
    String? sudoPassword,
    void Function(String chunk)? onOutput,
  }) async {
    final name = packageName?.trim();
    if ((action == PackageAction.install || action == PackageAction.remove) &&
        (name == null || !_safePackageName(name))) {
      throw ArgumentError.value(
        packageName,
        'packageName',
        'Invalid package name.',
      );
    }
    final display = _packageActionCommand(manager, action, name);
    await withClient(serverId, (client) async {
      onOutput?.call('\$ $display\n');
      final requiresElevation = manager.requiresElevation && !sshUserIsRoot;
      final prefix = !requiresElevation
          ? ''
          : (sudoPassword == null ? 'sudo -n ' : 'sudo -S -p "" ');
      final result = await _executeStreaming(
        client,
        '$prefix$display',
        stdin: requiresElevation ? sudoPassword : null,
        onOutput: onOutput,
      );
      if (result.exitCode != 0) {
        throw StateError(_commandError(result));
      }
    });
  }

  /// Runs a user-authored POSIX shell script through an existing SSH session.
  /// Output is streamed so callers can show the operation in the shared task
  /// terminal. The script is supplied on stdin, avoiding interpolation into a
  /// remote command string.
  Future<void> runScriptSnippet(
    int serverId, {
    required String script,
    void Function(String chunk)? onOutput,
    void Function(void Function())? onCancelReady,
  }) => _runScriptSnippet(
    serverId,
    command: 'sh -s',
    stdin: script,
    displayCommand: r'$ sh -s',
    onOutput: onOutput,
    onCancelReady: onCancelReady,
  );

  /// Runs a root-owned POSIX shell script through an existing SSH session.
  ///
  /// When the SSH user is not root, [sudoPassword] is sent only through the
  /// SSH channel to sudo's stdin; it is never interpolated into the command.
  Future<void> runPrivilegedScriptSnippet(
    int serverId, {
    required String script,
    required bool sshUserIsRoot,
    String? sudoPassword,
    void Function(String chunk)? onOutput,
    void Function(void Function())? onCancelReady,
  }) {
    final prefix = _rootPrefix(sshUserIsRoot, sudoPassword);
    final stdin = sshUserIsRoot || sudoPassword == null
        ? script
        : '$sudoPassword\n$script';
    return _runScriptSnippet(
      serverId,
      command: '${prefix}sh -s',
      stdin: stdin,
      displayCommand: r'$ sudo sh -s',
      onOutput: onOutput,
      onCancelReady: onCancelReady,
    );
  }

  Future<void> _runScriptSnippet(
    int serverId, {
    required String command,
    required String stdin,
    required String displayCommand,
    void Function(String chunk)? onOutput,
    void Function(void Function())? onCancelReady,
  }) async {
    if (stdin.trim().isEmpty) {
      throw ArgumentError.value(stdin, 'script', 'The script cannot be empty.');
    }
    await withClient(serverId, (client) async {
      onOutput?.call('$displayCommand\n');
      final result = await _executeStreaming(
        client,
        command,
        stdin: stdin,
        onOutput: onOutput,
        onSession: (session) => onCancelReady?.call(() {
          session.kill(SSHSignal.TERM);
          session.close();
        }),
        // A PTY is useful for interactive CLI progress, but it can keep a
        // shell open after its script input reaches EOF. Snippets need the
        // remote exit status to complete their task deterministically.
        usePty: false,
      );
      if (result.exitCode != 0) throw StateError(_commandError(result));
    });
  }

  /// Collects raw host counters for the Activity tab in a single SSH
  /// round-trip.
  Future<ActivityCounters> collectActivityCounters(int serverId) async {
    return withClient(serverId, (client) async {
      final result = await _execute(client, r'''
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
  nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total \
    --format=csv,noheader,nounits 2>/dev/null || true
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
      final windowsResult = await _execute(client, _windowsActivityCommand());
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
    String section(String name) {
      final start = output.indexOf('--$name--');
      if (start < 0) return '';
      final after = start + name.length + 4;
      final next = output.indexOf('--', after);
      return (next < 0
              ? output.substring(after)
              : output.substring(after, next))
          .trim();
    }

    final statLine = section('STAT');
    final rawStatFields = statLine.split(RegExp(r'\s+'));
    final statFields = statLine.startsWith('cpu')
        ? rawStatFields.skip(1).map(int.tryParse).whereType<int>().toList()
        : rawStatFields.map(int.tryParse).whereType<int>().toList();
    int? cpuIdle;
    int? cpuTotal;
    if (statFields.length >= 4) {
      // Linux: user nice system idle iowait irq softirq steal …
      // macOS: user nice system interrupt idle.
      final idleIndex = statLine.startsWith('cpu') ? 3 : statFields.length - 1;
      final idle =
          statFields[idleIndex] +
          (statLine.startsWith('cpu') && statFields.length > 4
              ? statFields[4]
              : 0);
      cpuIdle = idle;
      cpuTotal = statFields.fold<int>(0, (sum, value) => sum + value);
    }

    final loads = RegExp(r'[0-9]+(?:\.[0-9]+)?')
        .allMatches(section('LOAD'))
        .map((match) => double.tryParse(match.group(0)!))
        .whereType<double>()
        .toList();
    final directCpuPercent = double.tryParse(section('CPUUSAGE'));
    final memSection = section('MEM');
    int? memValue(String label) {
      final match = RegExp('$label:\\s+(\\d+)').firstMatch(memSection);
      return match == null ? null : int.tryParse(match.group(1)!);
    }

    final macTotalBytes = int.tryParse(memSection);
    int? macAvailableBytes() {
      final vmStat = section('VMSTAT');
      final pageSize = int.tryParse(
        RegExp(r'page size of (\d+) bytes').firstMatch(vmStat)?.group(1) ?? '',
      );
      if (pageSize == null) return null;
      int? pages(String label) => int.tryParse(
        RegExp('$label:\\s+(\\d+)').firstMatch(vmStat)?.group(1) ?? '',
      );
      final values = [
        pages('Pages free'),
        pages('Pages inactive'),
        pages('Pages speculative'),
      ].whereType<int>().toList();
      if (values.isEmpty) return null;
      return values.fold<int>(0, (sum, value) => sum + value) * pageSize;
    }

    int? macSwapValue(String label) {
      final match = RegExp(
        '$label\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)([KMGT])',
        caseSensitive: false,
      ).firstMatch(section('SWAP'));
      if (match == null) return null;
      final amount = double.tryParse(match.group(1)!);
      if (amount == null) return null;
      final multiplier = switch (match.group(2)!.toUpperCase()) {
        'K' => 1,
        'M' => 1024,
        'G' => 1024 * 1024,
        'T' => 1024 * 1024 * 1024,
        _ => 1,
      };
      return (amount * multiplier).round();
    }

    final diskLines = section('DISK')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final diskFields = diskLines.isEmpty
        ? const <String>[]
        : diskLines.last.split(RegExp(r'\s+'));
    var netRx = 0;
    var netTx = 0;
    var hasNet = false;
    for (final line in section('NET').split('\n')) {
      final trimmed = line.trim();
      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        if (parts.length < 2 || parts[0].trim() == 'lo') continue;
        final cols = parts[1].trim().split(RegExp(r'\s+'));
        if (cols.length < 9) continue;
        final rx = int.tryParse(cols[0]);
        final tx = int.tryParse(cols[8]);
        if (rx == null || tx == null) continue;
        netRx += rx;
        netTx += tx;
        hasNet = true;
        continue;
      }
      final fields = trimmed.split(RegExp(r'\s+'));
      if (fields.length < 10 ||
          fields[0] == 'Name' ||
          fields[0] == 'lo0' ||
          !fields[2].startsWith('<Link#')) {
        continue;
      }
      final rx = int.tryParse(fields[6]);
      final tx = int.tryParse(fields[9]);
      if (rx == null || tx == null) continue;
      netRx += rx;
      netTx += tx;
      hasNet = true;
    }
    final windowsRx = int.tryParse(
      RegExp(
            r'^RxBytes:\s*(\d+)',
            multiLine: true,
          ).firstMatch(section('NET'))?.group(1) ??
          '',
    );
    final windowsTx = int.tryParse(
      RegExp(
            r'^TxBytes:\s*(\d+)',
            multiLine: true,
          ).firstMatch(section('NET'))?.group(1) ??
          '',
    );
    if (windowsRx != null && windowsTx != null) {
      netRx = windowsRx;
      netTx = windowsTx;
      hasNet = true;
    }

    final windowsDiskTotal = int.tryParse(
      RegExp(
            r'^DiskTotal:\s*(\d+)',
            multiLine: true,
          ).firstMatch(section('DISK'))?.group(1) ??
          '',
    );
    final windowsDiskAvailable = int.tryParse(
      RegExp(
            r'^DiskAvailable:\s*(\d+)',
            multiLine: true,
          ).firstMatch(section('DISK'))?.group(1) ??
          '',
    );
    final uptimeText = section('UPTIME');
    var uptimeSeconds = int.tryParse(uptimeText);
    if (uptimeSeconds == null) {
      final boot = int.tryParse(
        RegExp(r'sec\s*=\s*(\d+)').firstMatch(uptimeText)?.group(1) ?? '',
      );
      if (boot != null) {
        uptimeSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - boot;
      }
    }
    double? gpuPercent;
    int? gpuMemoryUsedKb;
    int? gpuMemoryTotalKb;
    var gpuCount = 0;
    var gpuUtilSum = 0.0;
    var gpuUsedMb = 0;
    var gpuTotalMb = 0;
    var hasGpuMemory = false;
    for (final line in section('GPU').split('\n')) {
      final parts = line.split(',').map((part) => part.trim()).toList();
      final util = parts.isEmpty ? null : double.tryParse(parts[0]);
      if (util == null) continue;
      gpuCount++;
      gpuUtilSum += util;
      if (parts.length >= 3) {
        final used = int.tryParse(parts[1]);
        final total = int.tryParse(parts[2]);
        if (used != null && total != null) {
          gpuUsedMb += used;
          gpuTotalMb += total;
          hasGpuMemory = true;
        }
      }
    }
    if (gpuCount > 0) {
      gpuPercent = gpuUtilSum / gpuCount;
      if (hasGpuMemory) {
        gpuMemoryUsedKb = gpuUsedMb * 1024;
        gpuMemoryTotalKb = gpuTotalMb * 1024;
      }
    }
    return ActivityCounters(
      at: DateTime.now(),
      cpuIdle: cpuIdle,
      cpuTotal: cpuTotal,
      cpuPercent: directCpuPercent,
      load1: loads.isNotEmpty ? loads[0] : null,
      load5: loads.length > 1 ? loads[1] : null,
      load15: loads.length > 2 ? loads[2] : null,
      cpuCount: int.tryParse(section('CPU')),
      memoryTotalKb:
          memValue('MemTotal') ??
          (macTotalBytes == null ? null : macTotalBytes ~/ 1024),
      memoryAvailableKb:
          memValue('MemAvailable') ??
          (macAvailableBytes() == null ? null : macAvailableBytes()! ~/ 1024),
      swapTotalKb: memValue('SwapTotal') ?? macSwapValue('total'),
      swapFreeKb: memValue('SwapFree') ?? macSwapValue('free'),
      diskTotalKb:
          windowsDiskTotal ??
          (diskFields.length > 1 ? int.tryParse(diskFields[1]) : null),
      diskAvailableKb:
          windowsDiskAvailable ??
          (diskFields.length > 3 ? int.tryParse(diskFields[3]) : null),
      netRxBytes: hasNet ? netRx : null,
      netTxBytes: hasNet ? netTx : null,
      gpuPercent: gpuPercent,
      gpuMemoryUsedKb: gpuMemoryUsedKb,
      gpuMemoryTotalKb: gpuMemoryTotalKb,
      uptime: uptimeSeconds == null || uptimeSeconds < 0
          ? null
          : Duration(seconds: uptimeSeconds),
    );
  }

  String _rootPrefix(bool sshUserIsRoot, String? sudoPassword) {
    if (sshUserIsRoot) return '';
    return sudoPassword == null ? 'sudo -n ' : 'sudo -S -p "" ';
  }

  String? _rootStdin(bool sshUserIsRoot, String? sudoPassword) {
    if (sshUserIsRoot) return null;
    return sudoPassword;
  }

  Future<_CommandResult> _execute(
    SSHClient client,
    String command, {
    String? stdin,
  }) async {
    final session = await client.execute(_withRemoteToolPath(command));
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

  /// Streams stdout and stderr chunks while a remote command runs.
  ///
  /// When [usePty] is true (default for live task UIs), the remote process sees
  /// a terminal so tools like docker/podman emit ANSI colors and `\r` progress
  /// rewrites instead of non-interactive plain dumps.
  Future<_CommandResult> _executeStreaming(
    SSHClient client,
    String command, {
    String? stdin,
    void Function(String chunk)? onOutput,
    void Function(SSHSession session)? onSession,
    bool usePty = true,
  }) async {
    final session = await client.execute(
      _withRemoteToolPath(command),
      pty: usePty
          ? const SSHPtyConfig(type: 'xterm-256color', width: 120, height: 40)
          : null,
    );
    onSession?.call(session);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = utf8.decoder.bind(session.stdout).listen((chunk) {
      stdoutBuffer.write(chunk);
      onOutput?.call(chunk);
    }).asFuture<void>();
    final stderrDone = utf8.decoder.bind(session.stderr).listen((chunk) {
      stderrBuffer.write(chunk);
      onOutput?.call(chunk);
    }).asFuture<void>();
    if (stdin != null) {
      session.stdin.add(Uint8List.fromList(utf8.encode('$stdin\n')));
      await session.stdin.close();
    }
    await session.done;
    await Future.wait([stdoutDone, stderrDone]);
    return _CommandResult(
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      exitCode: session.exitCode ?? 1,
    );
  }

  String _withRemoteToolPath(String command) =>
      'export PATH="$_remoteToolPath:\$PATH"; $command';

  bool _safePackageName(String value) =>
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9+_.:@/-]*$').hasMatch(value);

  String _packageExecutable(PackageManager manager) => switch (manager) {
    PackageManager.apt => 'apt-get',
    PackageManager.dnf => 'dnf',
    PackageManager.yum => 'yum',
    PackageManager.pacman => 'pacman',
    PackageManager.zypper => 'zypper',
    PackageManager.apk => 'apk',
    PackageManager.xbps => 'xbps-install',
    PackageManager.brew => 'brew',
  };

  String _packageOutdatedCommand(PackageManager manager) => switch (manager) {
    PackageManager.apt =>
      "apt list --upgradable 2>/dev/null | sed '1d' | cut -d/ -f1",
    PackageManager.dnf =>
      'dnf -q check-update 2>/dev/null | awk \'NF >= 3 {print \$1}\'',
    PackageManager.yum =>
      'yum -q check-update 2>/dev/null | awk \'NF >= 3 {print \$1}\'',
    PackageManager.pacman => 'pacman -Qu 2>/dev/null | awk \'{print \$1}\'',
    PackageManager.zypper =>
      'zypper --non-interactive list-updates 2>/dev/null | awk \'/^v / {print \$3}\'',
    PackageManager.apk => 'apk version -l "<" 2>/dev/null | cut -d" " -f1',
    PackageManager.xbps =>
      'xbps-install -Mun 2>/dev/null | awk \'{print \$1}\'',
    PackageManager.brew => 'HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --formula',
  };

  String _installedPackageCountCommand(PackageManager manager) =>
      switch (manager) {
        PackageManager.apt => r"dpkg-query -W -f='${binary:Package}\n' | wc -l",
        PackageManager.dnf ||
        PackageManager.yum ||
        PackageManager.zypper => 'rpm -qa | wc -l',
        PackageManager.pacman => 'pacman -Qq | wc -l',
        PackageManager.apk => 'apk info | wc -l',
        PackageManager.xbps => 'xbps-query -l | wc -l',
        PackageManager.brew =>
          'HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula | wc -l',
      };

  String _packageActionCommand(
    PackageManager manager,
    PackageAction action,
    String? packageName,
  ) {
    final name = packageName ?? '';
    return switch ((manager, action)) {
      (PackageManager.apt, PackageAction.refresh) => 'apt-get update',
      (PackageManager.apt, PackageAction.upgrade) =>
        'env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade',
      (PackageManager.apt, PackageAction.install) =>
        'env DEBIAN_FRONTEND=noninteractive apt-get -y install $name',
      (PackageManager.apt, PackageAction.remove) =>
        'env DEBIAN_FRONTEND=noninteractive apt-get -y remove $name',
      (PackageManager.dnf, PackageAction.refresh) ||
      (
        PackageManager.yum,
        PackageAction.refresh,
      ) => '${_packageExecutable(manager)} makecache',
      (PackageManager.dnf, PackageAction.upgrade) ||
      (
        PackageManager.yum,
        PackageAction.upgrade,
      ) => '${_packageExecutable(manager)} -y upgrade',
      (PackageManager.dnf, PackageAction.install) ||
      (
        PackageManager.yum,
        PackageAction.install,
      ) => '${_packageExecutable(manager)} -y install $name',
      (PackageManager.dnf, PackageAction.remove) ||
      (
        PackageManager.yum,
        PackageAction.remove,
      ) => '${_packageExecutable(manager)} -y remove $name',
      (PackageManager.pacman, PackageAction.refresh) => 'pacman -Sy',
      (PackageManager.pacman, PackageAction.upgrade) =>
        'pacman --noconfirm -Syu',
      (PackageManager.pacman, PackageAction.install) =>
        'pacman --noconfirm -S $name',
      (PackageManager.pacman, PackageAction.remove) =>
        'pacman --noconfirm -R $name',
      (PackageManager.zypper, PackageAction.refresh) =>
        'zypper --non-interactive refresh',
      (PackageManager.zypper, PackageAction.upgrade) =>
        'zypper --non-interactive update',
      (PackageManager.zypper, PackageAction.install) =>
        'zypper --non-interactive install $name',
      (PackageManager.zypper, PackageAction.remove) =>
        'zypper --non-interactive remove $name',
      (PackageManager.apk, PackageAction.refresh) => 'apk update',
      (PackageManager.apk, PackageAction.upgrade) => 'apk upgrade',
      (PackageManager.apk, PackageAction.install) => 'apk add $name',
      (PackageManager.apk, PackageAction.remove) => 'apk del $name',
      (PackageManager.xbps, PackageAction.refresh) => 'xbps-install -S',
      (PackageManager.xbps, PackageAction.upgrade) => 'xbps-install -yu',
      (PackageManager.xbps, PackageAction.install) => 'xbps-install -y $name',
      (PackageManager.xbps, PackageAction.remove) => 'xbps-remove -y $name',
      (PackageManager.brew, PackageAction.refresh) => 'brew update',
      (PackageManager.brew, PackageAction.upgrade) =>
        'HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade',
      (PackageManager.brew, PackageAction.install) =>
        'HOMEBREW_NO_AUTO_UPDATE=1 brew install $name',
      (PackageManager.brew, PackageAction.remove) =>
        'HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall $name',
    };
  }

  List<String> _parsePackageNames(String output) => output
      .split('\n')
      .map((line) => line.trim().split(RegExp(r'\s+')).firstOrNull ?? '')
      .where((name) => _safePackageName(name))
      .toSet()
      .take(80)
      .toList();

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
      final stats = await _metricsCollector.collect(client);
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
      final session = await client.execute(r"""sh -c '
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
      final output = await utf8.decoder.bind(session.stdout).join();
      await session.done;
      final values = output.trim().split('\n');
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

  Future<void> connect(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    ServerProxy? proxy,
  }) async {
    await disconnect(server.id);
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
      _sessions[server.id] = client;
      _sessionJumpHosts[server.id] = server.jumpHostServerId;
      _set(_states[server.id]!.copyWith(status: SessionStatus.connected));
      onConnected?.call(server);
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
      final message = error is SSHAuthFailError
          ? sshAuthFailureMessage(
              credentialType: credential.type,
              serverAuthMethods: serverAuthMethods,
            )
          : error.toString();
      _set(
        _states[server.id]!.copyWith(
          status: SessionStatus.failed,
          error: message,
        ),
      );
      if (error is SSHAuthFailError) {
        throw SshAuthenticationException(message);
      }
      rethrow;
    }
  }

  void _handleClientClosed(Server server, SSHClient client, {Object? error}) {
    if (!identical(_sessions[server.id], client)) return;
    _sessions.remove(server.id);
    _sessionJumpHosts.remove(server.id);
    unawaited(_closeDependentSessions(server.id));
    unawaited(_closeTerminalsFor(server.id));
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

  Future<void> disconnect(int serverId) async {
    await _closeDependentSessions(serverId);
    await _stopPortForwardsFor(serverId);
    await _closeTerminalsForJumpHost(serverId);
    final client = _sessions.remove(serverId);
    _sessionJumpHosts.remove(serverId);
    client?.close();
    final state = _states[serverId];
    if (state != null) _set(state.copyWith(status: SessionStatus.closed));
  }

  void _set(SshSessionInfo value) {
    _states[value.serverId] = value;
    _controller.add(current);
  }

  Future<void> dispose() async {
    for (final terminalId in _terminals.keys.toList()) {
      await closeTerminal(terminalId);
    }
    for (final serverId in _sessions.keys.toList()) {
      await disconnect(serverId);
    }
    for (final id in _portForwards.keys.toList()) {
      await stopPortForward(id);
    }
    await _controller.close();
    await _portForwardController.close();
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

class TerminalSessionHandle {
  const TerminalSessionHandle({
    required this.id,
    required this.adapter,
    required this.done,
  });

  final String id;
  final TerminalSessionAdapter adapter;
  final Future<void> done;
}

class _TerminalConnection {
  const _TerminalConnection({
    required this.serverId,
    required this.jumpHostServerId,
    required this.client,
    required this.shell,
    required this.binding,
  });

  final int serverId;
  final int? jumpHostServerId;
  final SSHClient client;
  final SSHSession shell;
  final TerminalSessionBinding binding;
}

/// Handle for a live `logs -f` stream. Call [cancel] to stop the remote process.
class LogFollowHandle {
  LogFollowHandle._({required this.done, required this._cancel});

  /// Completes when the remote log process exits or is cancelled.
  final Future<void> done;
  final Future<void> Function() _cancel;
  var _cancelled = false;

  bool get isCancelled => _cancelled;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _cancel();
  }
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

String _windowsActivityCommand() => encodePowerShellCommand(r'''
$ErrorActionPreference = 'Stop'
$os = Get-CimInstance Win32_OperatingSystem
$processors = @(Get-CimInstance Win32_Processor)
$cpuCount = [int](($processors | Measure-Object NumberOfLogicalProcessors -Sum).Sum)
$loadPercent = [double](($processors | Measure-Object LoadPercentage -Average).Average)
$load = if ($cpuCount -gt 0) { $loadPercent * $cpuCount / 100 } else { 0 }
$pageFiles = @(Get-CimInstance Win32_PageFileUsage)
$swapTotalKb = [int64](($pageFiles | Measure-Object AllocatedBaseSize -Sum).Sum)
$swapUsedKb = [int64](($pageFiles | Measure-Object CurrentUsage -Sum).Sum)
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$net = @(Get-NetAdapterStatistics -ErrorAction SilentlyContinue)
$rx = [int64](($net | Measure-Object ReceivedBytes -Sum).Sum)
$tx = [int64](($net | Measure-Object SentBytes -Sum).Sum)
Write-Output '--WINDOWS--'
Write-Output '--CPUUSAGE--'
$loadPercent
Write-Output '--LOAD--'
$load
Write-Output '--CPU--'
$cpuCount
Write-Output '--MEM--'
"MemTotal: $($os.TotalVisibleMemorySize)"
"MemAvailable: $($os.FreePhysicalMemory)"
Write-Output '--SWAP--'
"SwapTotal: $swapTotalKb"
"SwapFree: $([math]::Max(0, $swapTotalKb - $swapUsedKb))"
Write-Output '--DISK--'
if ($null -ne $disk) {
  "DiskTotal: $([int64]($disk.Size / 1KB))"
  "DiskAvailable: $([int64]($disk.FreeSpace / 1KB))"
}
Write-Output '--NET--'
"RxBytes: $rx"
"TxBytes: $tx"
Write-Output '--UPTIME--'
[int64](([DateTime]::UtcNow - $os.LastBootUpTime.ToUniversalTime()).TotalSeconds)
''');

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
