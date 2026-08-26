import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/shared/presentation/conduit_dropdown.dart';
import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/formatters.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'package:conduit/shared/presentation/relative_time.dart';
import 'port_forward_supervisor.dart';
import 'proxy_environment.dart';
import 'port_forwarding_models.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'server_reorder.dart';

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

  /// Supervisor status changes (retrying, paused…) are not database rows,
  /// so the table re-renders on the supervisor's own change stream.
  StreamSubscription<void>? _supervisorChanges;

  @override
  void initState() {
    super.initState();
    _supervisorChanges = ref.read(portForwardSupervisorProvider).changes.listen(
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    unawaited(_supervisorChanges?.cancel());
    _bindHost.dispose();
    _bindPort.dispose();
    _targetHost.dispose();
    _targetPort.dispose();
    super.dispose();
  }

  List<Server> _sshServers() =>
      ref.read(serversProvider).asData?.value ?? const <Server>[];

  bool _isConnected(int serverId) =>
      ref.read(connectionManagerProvider).clientFor(serverId) != null;

  /// Probes this Mac's loopback for a running proxy (Surge's HTTP and SOCKS5
  /// listeners) and fills the form with what it finds: the proxy port becomes
  /// the forward's target.
  Future<void> _detectProxy() async {
    setState(() => _detecting = true);
    try {
      final port = await detectLocalProxyPort();
      if (!mounted) return;
      if (port == null) {
        showStyledSnackBar(message: 'portForwardingDetectProxyNone'.tr());
        return;
      }
      setState(() {
        _kind = PortForwardKind.tcp;
        _direction = PortForwardDirection.remote;
        _targetHost.text = '127.0.0.1';
        _targetPort.text = '$port';
        // The server-side port only has to be free on the server; offsetting
        // keeps it recognisable next to the local one.
        if (_bindPort.text.trim().isEmpty) {
          _bindPort.text = '${port + 10000}';
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
      showStyledSnackBar(message: 'portForwardingPickServer'.tr());
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
      if (mounted) showStyledSnackBar(message: 'portForwardingCreated'.tr());
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: 'portForwardingStartError'.tr(args: ['$error']),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Start on a preset row. A keep-alive preset is the supervisor's: resuming
  /// it lifts a pause and brings the forward up (retrying with backoff if the
  /// port is busy, which the status column shows). Any other preset is
  /// started directly so failures surface right here.
  Future<void> _startConfig(PortForwardConfig config) async {
    if (_starting) return;
    final server = _sshServers()
        .where((server) => server.id == config.serverId)
        .firstOrNull;
    if (server == null || !_isConnected(server.id)) {
      showStyledSnackBar(message: 'portForwardingConnectToConfigure'.tr());
      return;
    }
    if (config.keepAlive) {
      ref.read(portForwardSupervisorProvider).resume(config.id);
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
        showStyledSnackBar(message: 'portForwardingStarted'.tr());
      }
    } on PortForwardRefusedException {
      if (mounted) {
        showStyledSnackBar(
          message: 'portForwardingRemoteRefused'.tr(
            args: ['${config.bindHost}:${config.bindPort}'],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: 'portForwardingStartError'.tr(args: ['$error']),
        );
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
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
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
                        ConduitDropdown<int>(
                          value:
                              sshServers.any(
                                (server) => server.id == _selectedServerId,
                              )
                              ? _selectedServerId
                              : null,
                          entries: [
                            for (final server in sshServers)
                              DropdownMenuEntry(
                                value: server.id,
                                label: connectedIds.contains(server.id)
                                    ? server.name
                                    : 'portForwardingServerOffline'.tr(
                                        args: [server.name],
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
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) =>
                                  Material(
                                    color: Colors.transparent,
                                    child: child,
                                  ),
                              onReorderItem: (from, to) => _reorderConfigs(
                                _orderedConfigs(savedConfigs),
                                from,
                                to,
                              ),
                              children: [
                                for (final (index, entry) in _monitorEntries(
                                  _orderedConfigs(savedConfigs),
                                  forwards,
                                ).indexed)
                                  Column(
                                    key: ValueKey(
                                      entry.$1 != null
                                          ? 'config-${entry.$1!.id}'
                                          : 'forward-${entry.$2!.id}',
                                    ),
                                    children: [
                                      const Divider(height: 1),
                                      _monitorRow(
                                        config: entry.$1,
                                        forward: entry.$2,
                                        dragIndex: entry.$1 == null
                                            ? null
                                            : index,
                                        serverName:
                                            entry.$2?.serverName ??
                                            servers[entry.$1!.serverId]?.name ??
                                            'portForwardingUnknownServer'.tr(),
                                        metrics: entry.$2 == null
                                            ? null
                                            : forwardMetrics[entry.$2!.id],
                                        connected:
                                            entry.$1 == null ||
                                            connectedIds.contains(
                                              entry.$1!.serverId,
                                            ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
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

  /// Preset order shown between a drop and the database echoing it back.
  List<int>? _pendingConfigOrder;

  List<PortForwardConfig> _orderedConfigs(List<PortForwardConfig> configs) {
    final pending = _pendingConfigOrder;
    if (pending == null) return configs;
    final ids = [for (final config in configs) config.id];
    if (listEquals(ids, pending)) {
      _pendingConfigOrder = null;
      return configs;
    }
    final byId = {for (final config in configs) config.id: config};
    return [for (final id in pending) ?byId.remove(id), ...byId.values];
  }

  /// Drag from a preset row's grip; ad-hoc forwards always trail the presets,
  /// so a drop past them lands at the end of the presets.
  Future<void> _reorderConfigs(
    List<PortForwardConfig> configs,
    int from,
    int to,
  ) async {
    if (from >= configs.length) return;
    final ids = [for (final config in configs) config.id];
    final target = to.clamp(0, ids.length - 1);
    if (from == target) return;
    ids.insert(target, ids.removeAt(from));
    setState(() => _pendingConfigOrder = ids);
    try {
      await ref.read(serverRepositoryProvider).reorderPortForwardConfigs(ids);
    } catch (error) {
      if (!mounted) return;
      setState(() => _pendingConfigOrder = null);
      showConduitErrorAlert(error);
    }
  }

  /// Stop on a row: a preset is paused through the supervisor (which stops
  /// its forward and, for keep-alive, holds the restart until Start or the
  /// next connect); an unsaved forward is simply stopped.
  Future<void> _stopRow(PortForwardConfig? config, ActivePortForward forward) {
    if (config != null) {
      ref.read(portForwardSupervisorProvider).pause(config.id);
    }
    return ref.read(connectionManagerProvider).stopPortForward(forward.id);
  }

  Future<void> _deleteConfig(PortForwardConfig config) {
    ref.read(portForwardSupervisorProvider).forget(config.id);
    return ref
        .read(serverRepositoryProvider)
        .deletePortForwardConfig(config.id);
  }

  /// Pairs every saved preset with its running forward (the supervisor's
  /// identity rule), then appends unsaved ad-hoc forwards.
  List<(PortForwardConfig?, ActivePortForward?)> _monitorEntries(
    List<PortForwardConfig> configs,
    List<ActivePortForward> forwards,
  ) {
    final entries = <(PortForwardConfig?, ActivePortForward?)>[];
    final matched = <String>{};
    for (final config in configs) {
      final forward = forwards
          .where((forward) => activeForwardMatches(forward, config))
          .firstOrNull;
      if (forward != null) matched.add(forward.id);
      entries.add((config, forward));
    }
    for (final forward in forwards) {
      if (!matched.contains(forward.id)) entries.add((null, forward));
    }
    return entries;
  }

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
    required int? dragIndex,
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
    // "Retrying" is the supervisor's verdict, not an inference from the
    // keep-alive flag: a paused preset is stopped even though it is keep-alive.
    final presetStatus = config == null
        ? PortForwardPresetStatus.unsupervised
        : ref.read(portForwardSupervisorProvider).statusOf(config.id);
    final (statusKey, statusColor) = switch ((
      connected,
      forward != null,
      presetStatus,
    )) {
      (_, true, _) => ('portForwardingStatusRunning', scheme.primary),
      (false, false, _) => (
        'portForwardingStatusOffline',
        scheme.onSurfaceVariant,
      ),
      (true, false, PortForwardPresetStatus.retrying) => (
        'portForwardingStatusRetrying',
        scheme.tertiary,
      ),
      (true, false, _) => (
        'portForwardingStatusStopped',
        scheme.onSurfaceVariant,
      ),
    };
    final text = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final tabular = text?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final repository = ref.read(serverRepositoryProvider);
    final flexes = [for (final (flex, _) in _monitorColumns) flex];
    final cells = <Widget>[
      Text(serverName, style: text, overflow: TextOverflow.ellipsis),
      Text(localPort, style: tabular),
      Text(serverPort, style: tabular),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          if (metrics != null)
            Text(
              [
                'portForwardingSince'.tr(args: [_clockTime(metrics.startedAt)]),
                if (metrics.lastActivityAt case final at?)
                  'portForwardingLastActivity'.tr(
                    args: [relativeTimeLabel(at)],
                  ),
              ].join(' · '),
              style: muted,
              overflow: TextOverflow.ellipsis,
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
            : '↑ ${formatBytes(metrics.bytesUp)} '
                  '↓ ${formatBytes(metrics.bytesDown)}',
        style: tabular,
        overflow: TextOverflow.ellipsis,
      ),
      // Scales the whole control group down a notch when the cell is narrow.
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config != null) ...[
              _RowSwitch(
                tooltip: 'portForwardingAutoStart'.tr(),
                icon: Symbols.bolt,
                value: config.autoStart,
                onChanged: (value) =>
                    repository.setPortForwardConfigAutoStart(config.id, value),
              ),
              _RowSwitch(
                tooltip: 'portForwardingKeepAlive'.tr(),
                icon: Symbols.autorenew,
                value: config.keepAlive,
                onChanged: (value) =>
                    repository.setPortForwardConfigKeepAlive(config.id, value),
              ),
            ],
            if (forward != null)
              IconButton(
                tooltip: 'portForwardingStop'.tr(),
                onPressed: () => _stopRow(config, forward),
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
                onPressed: () => _deleteConfig(config),
                icon: const Icon(Symbols.delete_outline),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            if (dragIndex case final index?)
              ReorderableDragStartListener(
                index: index,
                child: const ServerDragHandle(),
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

/// Compact preset toggle for the actions cell: a small icon labels the
/// switch so auto-start and keep-alive stay distinguishable side by side.
class _RowSwitch extends StatelessWidget {
  const _RowSwitch({
    required this.tooltip,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String tooltip;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        SizedBox(
          height: 30,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ),
      ],
    ),
  );
}

/// Local wall-clock time of [time] ("12:04") for the "since" label.
String _clockTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
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
