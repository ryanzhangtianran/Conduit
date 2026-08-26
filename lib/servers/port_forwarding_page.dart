import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'proxy_environment.dart';
import 'port_forwarding_models.dart';
import 'server_models.dart';
import 'server_providers.dart';

/// Monitor table columns as (flex, header key); rows share the same flexes,
/// so the table always fills the card exactly.
const _monitorColumns = [
  (3, 'portForwardingColumnServer'),
  (2, 'portForwardingColumnLocalPort'),
  (3, 'portForwardingColumnServerPort'),
  (3, 'portForwardingColumnStatus'),
  (2, 'portForwardingColumnConnections'),
  (4, 'portForwardingColumnTraffic'),
  (4, 'portForwardingColumnActions'),
];

/// Top-level tunneling workspace. Every tunnel — including a local proxy
/// (Surge) reverse tunnel — is one saved forward: it can start on connect,
/// stay supervised, and export the proxy environment into new terminals.
@RoutePage()
class PortForwardingPage extends ConsumerStatefulWidget {
  const PortForwardingPage({super.key});

  @override
  ConsumerState<PortForwardingPage> createState() => _PortForwardingPageState();
}

class _PortForwardingPageState extends ConsumerState<PortForwardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _bindHost = TextEditingController(text: '127.0.0.1');
  final _bindPort = TextEditingController();
  final _targetHost = TextEditingController(text: '127.0.0.1');
  final _targetPort = TextEditingController();
  int? _selectedServerId;
  var _direction = PortForwardDirection.local;
  var _kind = PortForwardKind.tcp;
  var _autoStartConfig = false;
  var _keepAlive = false;
  var _starting = false;
  var _detecting = false;

  @override
  void dispose() {
    _bindHost.dispose();
    _bindPort.dispose();
    _targetHost.dispose();
    _targetPort.dispose();
    super.dispose();
  }

  List<Server> _sshServers() =>
      (ref.read(serversProvider).asData?.value ?? const <Server>[])
          .where(
            (server) => server.connectionType == ServerConnectionType.ssh.name,
          )
          .toList();

  bool _isConnected(int serverId) =>
      ref.read(connectionManagerProvider).clientFor(serverId) != null;

  /// Probes this Mac's loopback for a running proxy (Surge's HTTP and SOCKS5
  /// listeners) and fills the form with what it finds: the proxy port becomes
  /// the forward's target, and the scheme marks it as the proxy endpoint.
  Future<void> _detectProxy() async {
    setState(() => _detecting = true);
    try {
      final found = await detectLocalProxy();
      if (!mounted) return;
      if (found == null) {
        showSnackBar('portForwardingDetectProxyNone'.tr());
        return;
      }
      setState(() {
        _kind = PortForwardKind.tcp;
        _direction = PortForwardDirection.remote;
        _targetHost.text = '127.0.0.1';
        _targetPort.text = '${found.port}';
        // The server-side port only has to be free on the server; offsetting
        // keeps it recognisable next to the local one.
        if (_bindPort.text.trim().isEmpty) {
          _bindPort.text = '${found.port + 10000}';
        }
        _autoStartConfig = true;
        _keepAlive = true;
      });
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  /// Creates the forward as a saved preset for the selected server. The
  /// monitor table below is the one place forwards are started and stopped;
  /// a connected server with auto-start or keep-alive comes up right away
  /// via the supervisor.
  Future<void> _create() async {
    final server = _sshServers()
        .where((server) => server.id == _selectedServerId)
        .firstOrNull;
    if (server == null) {
      showSnackBar('portForwardingPickServer'.tr());
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _starting = true);
    final kind = _kind;
    final targetHost = kind == PortForwardKind.tcp
        ? _targetHost.text.trim()
        : '';
    final targetPort = kind == PortForwardKind.tcp
        ? int.parse(_targetPort.text)
        : 0;
    try {
      await ref
          .read(serverRepositoryProvider)
          .savePortForwardConfig(
            serverId: server.id,
            direction: _direction,
            kind: kind,
            bindHost: _bindHost.text.trim(),
            bindPort: int.parse(_bindPort.text),
            targetHost: targetHost,
            targetPort: targetPort,
            autoStart: _autoStartConfig,
            keepAlive: _keepAlive,
          );
      if (_isConnected(server.id) && (_autoStartConfig || _keepAlive)) {
        await ref.read(portForwardSupervisorProvider).onConnected(server);
      }
      if (mounted) showSnackBar('portForwardingCreated'.tr());
    } catch (error) {
      if (mounted) {
        showSnackBar('portForwardingStartError'.tr(args: ['$error']));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _startConfig(PortForwardConfig config) async {
    if (_starting) return;
    final server = _sshServers()
        .where((server) => server.id == config.serverId)
        .firstOrNull;
    if (server == null || !_isConnected(server.id)) {
      showSnackBar('portForwardingConnectToConfigure'.tr());
      return;
    }
    setState(() => _starting = true);
    try {
      await ref
          .read(connectionManagerProvider)
          .startPortForward(
            server: server,
            direction: PortForwardDirection.values.byName(config.direction),
            kind: PortForwardKind.values.byName(config.kind),
            bindHost: config.bindHost,
            bindPort: config.bindPort,
            targetHost: config.targetHost,
            targetPort: config.targetPort,
          );
      if (mounted) {
        showSnackBar('portForwardingStarted'.tr());
      }
    } on PortForwardRefusedException {
      if (mounted) {
        showSnackBar(
          'portForwardingRemoteRefused'.tr(
            args: ['${config.bindHost}:${config.bindPort}'],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showSnackBar('portForwardingStartError'.tr(args: ['$error']));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final servers = _serversByIdOf(
      ref.watch(serversProvider).asData?.value ?? const <Server>[],
    );
    final sshServers =
        (ref.watch(serversProvider).asData?.value ?? const <Server>[])
            .where(
              (server) =>
                  server.connectionType == ServerConnectionType.ssh.name,
            )
            .toList();
    final sessions =
        ref.watch(sessionsProvider).asData?.value ?? const <SshSessionInfo>[];
    final connectedIds = {
      for (final session in sessions)
        if (session.status == SessionStatus.connected) session.serverId,
    };
    final forwards =
        ref.watch(portForwardsProvider).asData?.value ??
        const <ActivePortForward>[];
    final forwardMetrics =
        ref.watch(portForwardMetricsProvider).asData?.value ??
        const <String, PortForwardMetrics>{};
    final savedConfigs =
        ref.watch(allPortForwardConfigsProvider).asData?.value ??
        const <PortForwardConfig>[];
    final directionDescription = switch ((_kind, _direction)) {
      (PortForwardKind.tcp, PortForwardDirection.local) =>
        'portForwardingLocalDesc',
      (PortForwardKind.tcp, PortForwardDirection.remote) =>
        'portForwardingRemoteDesc',
      (PortForwardKind.socks5, _) => 'portForwardingSocks5Desc',
    }.tr();

    return ConduitAppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text('portForwardingNew', style: theme.textTheme.titleMedium).tr(),
          const SizedBox(height: 8),
          Text(
            directionDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'portForwardingServerLabel'.tr(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue:
                              sshServers.any(
                                (server) => server.id == _selectedServerId,
                              )
                              ? _selectedServerId
                              : null,
                          items: [
                            for (final server in sshServers)
                              DropdownMenuItem(
                                value: server.id,
                                child: Text(
                                  connectedIds.contains(server.id)
                                      ? server.name
                                      : 'portForwardingServerOffline'.tr(
                                          args: [server.name],
                                        ),
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedServerId = value),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'portForwardingKindLabel'.tr(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<PortForwardKind>(
                                expandedInsets: EdgeInsets.zero,
                                segments: [
                                  ButtonSegment(
                                    value: PortForwardKind.tcp,
                                    icon: const Icon(Symbols.swap_horiz),
                                    label: Text('portForwardingTcp').tr(),
                                  ),
                                  ButtonSegment(
                                    value: PortForwardKind.socks5,
                                    icon: const Icon(Symbols.vpn_lock),
                                    label: Text('portForwardingSocks5').tr(),
                                  ),
                                ],
                                selected: {_kind},
                                onSelectionChanged: (value) => setState(() {
                                  _kind = value.first;
                                  // SOCKS5 is a local listener only.
                                  if (_kind == PortForwardKind.socks5) {
                                    _direction = PortForwardDirection.local;
                                  }
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _kind == PortForwardKind.tcp
                                  ? SegmentedButton<PortForwardDirection>(
                                      expandedInsets: EdgeInsets.zero,
                                      segments: [
                                        ButtonSegment(
                                          value: PortForwardDirection.local,
                                          icon: const Icon(Symbols.laptop_mac),
                                          label: Text(
                                            'portForwardingLocal',
                                          ).tr(),
                                        ),
                                        ButtonSegment(
                                          value: PortForwardDirection.remote,
                                          icon: const Icon(Symbols.dns),
                                          label: Text(
                                            'portForwardingRemote',
                                          ).tr(),
                                        ),
                                      ],
                                      selected: {_direction},
                                      onSelectionChanged: (value) => setState(
                                        () => _direction = value.first,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_kind == PortForwardKind.tcp)
                          _ForwardFields(
                            bindHost: _bindHost,
                            bindPort: _bindPort,
                            targetHost: _targetHost,
                            targetPort: _targetPort,
                            direction: _direction,
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _HostPortFields(
                                  label: 'portForwardingThisComputerListens',
                                  host: _bindHost,
                                  port: _bindPort,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                        const SizedBox(height: 16),
                        ...[
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            value: _autoStartConfig,
                            onChanged: (value) => setState(
                              () => _autoStartConfig = value ?? false,
                            ),
                            title: Text('portForwardingAutoStart').tr(),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            value: _keepAlive,
                            onChanged: (value) =>
                                setState(() => _keepAlive = value ?? false),
                            title: Text('portForwardingKeepAlive').tr(),
                            subtitle: Text('portForwardingKeepAliveHint').tr(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _starting ? null : _create,
                              icon: _starting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Symbols.play_arrow),
                              label: Text('portForwardingCreate').tr(),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _detecting ? null : _detectProxy,
                              icon: _detecting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Symbols.travel_explore),
                              label: Text('portForwardingDetectProxy').tr(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'portForwardingMonitorTitle',
            style: theme.textTheme.titleSmall,
          ).tr(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: savedConfigs.isEmpty && forwards.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'portForwardingMonitorEmpty',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ).tr(),
                          ),
                        )
                      : Column(
                          children: [
                            _monitorHeader(),
                            for (final entry in _monitorEntries(
                              savedConfigs,
                              forwards,
                            )) ...[
                              const Divider(height: 1),
                              _monitorRow(
                                config: entry.$1,
                                forward: entry.$2,
                                serverName:
                                    entry.$2?.serverName ??
                                    servers[entry.$1!.serverId]?.name ??
                                    'portForwardingUnknownServer'.tr(),
                                metrics: entry.$2 == null
                                    ? null
                                    : forwardMetrics[entry.$2!.id],
                                connected:
                                    entry.$1 == null ||
                                    connectedIds.contains(entry.$1!.serverId),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<int, Server> _serversByIdOf(List<Server> servers) => {
    for (final server in servers) server.id: server,
  };

  /// Pairs every saved preset with its running forward (matched on server,
  /// kind, and listen address), then appends unsaved ad-hoc forwards.
  List<(PortForwardConfig?, ActivePortForward?)> _monitorEntries(
    List<PortForwardConfig> configs,
    List<ActivePortForward> forwards,
  ) {
    final entries = <(PortForwardConfig?, ActivePortForward?)>[];
    final matched = <String>{};
    for (final config in configs) {
      final forward = forwards
          .where(
            (forward) =>
                forward.serverId == config.serverId &&
                forward.kind.name == config.kind &&
                forward.bindHost == config.bindHost &&
                forward.bindPort == config.bindPort,
          )
          .firstOrNull;
      if (forward != null) matched.add(forward.id);
      entries.add((config, forward));
    }
    for (final forward in forwards) {
      if (!matched.contains(forward.id)) entries.add((null, forward));
    }
    return entries;
  }

  /// One monitor-table row: a saved preset, its running forward, or an
  /// unsaved ad-hoc forward.
  /// Header row of the monitor table; flexes match [_monitorRow]'s cells.
  Widget _monitorHeader() {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          for (final (flex, key) in _monitorColumns)
            Expanded(
              flex: flex,
              child: Center(
                child: key == 'portForwardingColumnConnections'
                    ? Tooltip(
                        message: 'portForwardingColumnConnectionsTooltip'.tr(),
                        child: Text(key, style: style).tr(),
                      )
                    : Text(key, style: style).tr(),
              ),
            ),
        ],
      ),
    );
  }

  /// One monitor-table row: a saved preset, its running forward, or an
  /// unsaved ad-hoc forward.
  Widget _monitorRow({
    required PortForwardConfig? config,
    required ActivePortForward? forward,
    required String serverName,
    required PortForwardMetrics? metrics,
    required bool connected,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final direction =
        forward?.direction ??
        PortForwardDirection.values.byName(config!.direction);
    final kind = forward?.kind ?? PortForwardKind.values.byName(config!.kind);
    final bindPort = '${forward?.bindPort ?? config!.bindPort}';
    final targetPort = kind == PortForwardKind.socks5
        ? '—'
        : '${forward?.targetPort ?? config!.targetPort}';
    // The bind side is where the listener lives: this Mac for local (and
    // SOCKS5) forwards, the SSH server for remote forwards.
    final (localPort, serverPort) = direction == PortForwardDirection.local
        ? (bindPort, targetPort)
        : (targetPort, bindPort);
    final (statusKey, statusColor) = switch ((connected, forward != null)) {
      (_, true) => ('portForwardingStatusRunning', scheme.primary),
      (false, false) => (
        'portForwardingStatusOffline',
        scheme.onSurfaceVariant,
      ),
      (true, false) when config?.keepAlive ?? false => (
        'portForwardingStatusRetrying',
        scheme.tertiary,
      ),
      (true, false) => ('portForwardingStatusStopped', scheme.onSurfaceVariant),
    };
    final text = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface);
    final tabular = text?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final repository = ref.read(serverRepositoryProvider);
    final flexes = [for (final (flex, _) in _monitorColumns) flex];
    final cells = <Widget>[
      Text(serverName, style: text, overflow: TextOverflow.ellipsis),
      Text(localPort, style: tabular),
      Text(serverPort, style: tabular),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              config == null
                  ? '${statusKey.tr()} · ${'portForwardingUnsaved'.tr()}'
                  : statusKey.tr(),
              style: text,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Text(
        metrics == null
            ? '—'
            : '${metrics.activeConnections} / ${metrics.totalConnections}',
        style: tabular,
      ),
      Text(
        metrics == null
            ? '—'
            : '↑ ${_formatTraffic(metrics.bytesUp)} '
                  '↓ ${_formatTraffic(metrics.bytesDown)}',
        style: tabular,
        overflow: TextOverflow.ellipsis,
      ),
      // Scales the whole control group down a notch when the cell is narrow.
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config != null)
              Tooltip(
                message: 'portForwardingAutoStart'.tr(),
                child: SizedBox(
                  height: 30,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Switch(
                      value: config.autoStart,
                      onChanged: (value) => repository
                          .setPortForwardConfigAutoStart(config.id, value),
                    ),
                  ),
                ),
              ),
            if (forward != null)
              IconButton(
                tooltip: 'portForwardingStop'.tr(),
                onPressed: () => ref
                    .read(connectionManagerProvider)
                    .stopPortForward(forward.id),
                icon: const Icon(Symbols.stop_circle),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              )
            else if (config != null)
              IconButton(
                tooltip: 'portForwardingStart'.tr(),
                onPressed: () => _startConfig(config),
                icon: const Icon(Symbols.play_arrow),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            if (config != null)
              IconButton(
                tooltip: 'portForwardingDelete'.tr(),
                onPressed: () => repository.deletePortForwardConfig(config.id),
                icon: const Icon(Symbols.delete_outline),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final (index, cell) in cells.indexed)
            Expanded(
              flex: flexes[index],
              child: Center(child: cell),
            ),
        ],
      ),
    );
  }
}

class _ForwardFields extends StatelessWidget {
  const _ForwardFields({
    required this.bindHost,
    required this.bindPort,
    required this.targetHost,
    required this.targetPort,
    required this.direction,
  });

  final TextEditingController bindHost;
  final TextEditingController bindPort;
  final TextEditingController targetHost;
  final TextEditingController targetPort;
  final PortForwardDirection direction;

  @override
  Widget build(BuildContext context) {
    final listener = direction == PortForwardDirection.local
        ? 'portForwardingThisComputerListens'
        : 'portForwardingServerListens';
    final target = direction == PortForwardDirection.local
        ? 'portForwardingServerTarget'
        : 'portForwardingThisComputerTarget';
    // The two groups share the row like the type/direction selectors above.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _HostPortFields(
            label: listener,
            host: bindHost,
            port: bindPort,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HostPortFields(
            label: target,
            host: targetHost,
            port: targetPort,
          ),
        ),
      ],
    );
  }
}

class _HostPortFields extends StatelessWidget {
  const _HostPortFields({
    required this.label,
    required this.host,
    required this.port,
  });

  final String label;
  final TextEditingController host;
  final TextEditingController port;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr(label),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: host,
              decoration: InputDecoration(
                labelText: 'portForwardingHostLabel'.tr(),
              ),
              validator: _hostValidator,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: TextFormField(
              controller: port,
              decoration: InputDecoration(
                labelText: 'portForwardingPortLabel'.tr(),
              ),
              keyboardType: TextInputType.number,
              validator: _portValidator,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Compact byte count for the forward monitor line: 0 B → 1023 B → 1.0 KB →
/// 1.0 MB → 1.0 GB.
String _formatTraffic(int bytes) {
  const kilobyte = 1024;
  const megabyte = 1024 * kilobyte;
  const gigabyte = 1024 * megabyte;
  return switch (bytes) {
    >= gigabyte => '${(bytes / gigabyte).toStringAsFixed(1)} GB',
    >= megabyte => '${(bytes / megabyte).toStringAsFixed(1)} MB',
    >= kilobyte => '${(bytes / kilobyte).toStringAsFixed(1)} KB',
    _ => '$bytes B',
  };
}

String? _hostValidator(String? value) => value == null || value.trim().isEmpty
    ? 'portForwardingHostRequired'.tr()
    : null;

String? _portValidator(String? value) {
  final port = int.tryParse(value ?? '');
  return port == null || port < 1 || port > 65535
      ? 'portForwardingPortRequired'.tr()
      : null;
}
