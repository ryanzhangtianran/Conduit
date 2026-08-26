import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/github/github_workflow_strip.dart';
import 'package:conduit/shared/formatters.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'package:conduit/shared/presentation/relative_time.dart';
import 'server_address_label.dart';
import 'server_connection_actions.dart';
import 'server_editor_dialog.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'server_reorder.dart';
import 'server_workspace_page.dart';
import 'terminal_tabs_provider.dart';

/// The dashboard: every saved server as a card with its live statistics.
@RoutePage()
class ServersPage extends ConsumerWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    return ConduitAppScaffold(
      body: servers.when(
        data: (items) => items.isEmpty
            ? _EmptyServers(onAdd: () => _addServer(context, ref))
            : _ServerGrid(servers: items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('serversLoadError'.tr(args: [error.toString()])),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'servers-create-fab',
        onPressed: () => _addServer(context, ref),
        icon: const Icon(Symbols.add),
        label: Text('serversAddServer'.tr()),
      ),
    );
  }
}

/// Adds a server from the dashboard and connects it straight away.
Future<void> _addServer(BuildContext context, WidgetRef ref) async {
  final server = await showServerEditor(context, ref);
  if (server == null || !context.mounted) return;
  await connectForStatistics(context, ref, server);
}

Future<void> _reconnectAll(
  BuildContext context,
  WidgetRef ref,
  List<Server> servers,
) async {
  for (final server in servers) {
    if (!context.mounted) return;
    await connectForStatistics(context, ref, server);
  }
}

Future<void> _delete(WidgetRef ref, Server server) async {
  await _disconnect(ref, server);
  await ref.read(serverRepositoryProvider).delete(server);
}

/// Closes the server's terminals, then the retained background session
/// (which also tears down its port forwards and proxy tunnel).
Future<void> _disconnect(WidgetRef ref, Server server) async {
  await ref.read(terminalTabsProvider.notifier).closeForServer(server.id);
  await ref.read(connectionManagerProvider).disconnect(server.id);
}

void _openDetail(BuildContext context, WidgetRef ref, Server server) {
  ref.read(monitorSelectedServerIdProvider.notifier).select(server.id);
  AutoTabsRouter.of(context).setActiveIndex(WorkspaceTab.monitor.index);
}

class _ServerGrid extends ConsumerStatefulWidget {
  const _ServerGrid({required this.servers});

  final List<Server> servers;

  @override
  ConsumerState<_ServerGrid> createState() => _ServerGridState();
}

class _ServerGridState extends ConsumerState<_ServerGrid> {
  var _isReconnecting = false;
  final _selectedTags = <String>{};

  Future<void> _reconnectAllServers(List<Server> servers) async {
    setState(() => _isReconnecting = true);
    try {
      await _reconnectAll(context, ref, servers);
    } finally {
      if (mounted) setState(() => _isReconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    final sessionsByServerId = {
      for (final session in sessions) session.serverId: session,
    };
    final allTags =
        widget.servers
            .expand((server) => decodeStringList(server.tags))
            .toSet()
            .toList()
          ..sort();
    final visibleServers = widget.servers.where((server) {
      final tags = decodeStringList(server.tags).toSet();
      return _selectedTags.every(tags.contains);
    }).toList();
    final disconnectedServers = visibleServers.where((server) {
      final status = sessionsByServerId[server.id]?.status;
      return status != SessionStatus.connected &&
          status != SessionStatus.connecting;
    }).toList();

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: disconnectedServers.length > 1
              ? Padding(
                  key: const ValueKey('servers-reconnect-all'),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: _ReconnectAllCard(
                    count: disconnectedServers.length,
                    isReconnecting: _isReconnecting,
                    onPressed: () => _reconnectAllServers(disconnectedServers),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('servers-reconnect-none')),
        ),
        if (allTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in allTags)
                    FilterChip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      selected: _selectedTags.contains(tag),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        const GithubWorkflowStatusStrip(),
        Expanded(
          child: visibleServers.isEmpty
              ? const Center(child: _NoServersMatch())
              : ReorderableServerGrid(
                  servers: visibleServers,
                  allServers: widget.servers,
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 280,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemBuilder: (context, server) {
                    final session = sessionsByServerId[server.id];
                    final card = _ServerCard(
                      server: server,
                      session: session,
                      onConnect: () =>
                          connectForStatistics(context, ref, server),
                      onDisconnect: () => _disconnect(ref, server),
                      onOpenDetail: () => _openDetail(context, ref, server),
                      onRefresh: () => ref
                          .read(connectionManagerProvider)
                          .refreshServerInfo(server),
                    );
                    final connected =
                        session?.status == SessionStatus.connected;
                    return ContextMenuWidget(
                      menuProvider: (_) => Menu(
                        children: [
                          MenuAction(
                            title: 'serversEditServer'.tr(),
                            callback: () =>
                                showServerEditor(context, ref, server: server),
                          ),
                          if (connected)
                            MenuAction(
                              title: 'serversDisconnectServer'.tr(),
                              callback: () => _disconnect(ref, server),
                            ),
                          MenuSeparator(),
                          MenuAction(
                            title: 'serversDeleteServer'.tr(),
                            attributes: const MenuActionAttributes(
                              destructive: true,
                            ),
                            callback: () => _delete(ref, server),
                          ),
                        ],
                      ),
                      child: card,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NoServersMatch extends StatelessWidget {
  const _NoServersMatch();

  @override
  Widget build(BuildContext context) => Text(
    'serversNoMatches'.tr(),
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _ReconnectAllCard extends StatelessWidget {
  const _ReconnectAllCard({
    required this.count,
    required this.isReconnecting,
    required this.onPressed,
  });

  final int count;
  final bool isReconnecting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              Symbols.cloud_off,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'serversDisconnectedCount'.plural(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: isReconnecting ? null : onPressed,
              icon: isReconnecting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : const Icon(Symbols.sync, size: 18),
              label: Text('serversReconnectAll'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerCard extends ConsumerWidget {
  const _ServerCard({
    required this.server,
    required this.session,
    required this.onConnect,
    required this.onDisconnect,
    required this.onOpenDetail,
    required this.onRefresh,
  });

  final Server server;
  final SshSessionInfo? session;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onOpenDetail;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final connected = session?.status == SessionStatus.connected;
    final connecting = session?.status == SessionStatus.connecting;
    final failed = session?.status == SessionStatus.failed;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    Icon(
                      Symbols.dns,
                      fill: connected ? 1 : 0,
                      size: 22,
                      color: connected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            server.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  serverAddressLabel(server),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _ServerBadges(server: server),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'serversRefreshStatistics'.tr(),
                      visualDensity: VisualDensity.compact,
                      onPressed: connected ? onRefresh : null,
                      icon: const Icon(Symbols.refresh),
                    ),
                    const ServerDragHandle(),
                  ],
                ),
              ),
              SizedBox(height: 4),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: connected
                      ? _ServerStats(
                          stats: session?.stats,
                          systemInfo: session?.systemInfo,
                          collectStats: server.collectStats,
                          collectSystemInfo: server.collectSystemInfo,
                        )
                      : _DisconnectedStats(
                          connecting: connecting,
                          error: session?.error,
                        ),
                ),
              ),
              SizedBox(height: 8),
              const Divider(height: 1),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _ConnectionStatus(
                      connected: connected,
                      connecting: connecting,
                      failed: failed,
                      networkLatency: session?.networkLatency,
                    ),
                    const Spacer(),
                    if (connecting) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.tonal(
                      onPressed: connected || connecting ? null : onConnect,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text('serversConnect'.tr()),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: connected ? onDisconnect : null,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text('serversDisconnectServer'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small label chip for server tags.
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Tag chips shown under a server card's title.
class _ServerBadges extends StatelessWidget {
  const _ServerBadges({required this.server});

  final Server server;

  @override
  Widget build(BuildContext context) {
    final tags = decodeStringList(server.tags);
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tag in tags.take(3)) _BadgeChip(label: tag),
          if (tags.length > 3) _BadgeChip(label: '+${tags.length - 3}'),
        ],
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    required this.connected,
    required this.connecting,
    required this.failed,
    this.networkLatency,
  });

  final bool connected;
  final bool connecting;
  final bool failed;
  final Duration? networkLatency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final latency = networkLatency;

    if (connected) {
      final latencyColor = latency == null
          ? colorScheme.onSurfaceVariant
          : latency.inMilliseconds >= 250
          ? colorScheme.error
          : latency.inMilliseconds >= 100
          ? colorScheme.tertiary
          : colorScheme.onSurfaceVariant;
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'serversNetworkPingTooltip'.tr(),
            child: Text(
              latency == null ? '—' : '${latency.inMilliseconds} ms',
              style: textTheme.labelLarge?.copyWith(color: latencyColor),
            ),
          ),
        ],
      );
    }

    final (label, color) = switch ((connecting, failed)) {
      (true, _) => ('serversConnecting'.tr(), colorScheme.tertiary),
      (_, true) => ('serversFailed'.tr(), colorScheme.error),
      _ => ('serversNotConnected'.tr(), colorScheme.onSurfaceVariant),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
        ),
      ],
    );
  }
}

class _DisconnectedStats extends StatelessWidget {
  const _DisconnectedStats({required this.connecting, this.error});

  final bool connecting;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message = connecting
        ? 'serversEstablishingSession'.tr()
        : (error ?? 'serversConnectToViewStats'.tr());

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Icon(
              connecting ? Symbols.hourglass_top : Symbols.insights,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            // A SelectionArea rather than a SelectableText: the card keeps
            // its three-line ellipsis, which SelectableText cannot do.
            Expanded(
              child: SelectionArea(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerStats extends StatelessWidget {
  const _ServerStats({
    required this.stats,
    required this.systemInfo,
    required this.collectStats,
    required this.collectSystemInfo,
  });

  final ServerStats? stats;
  final ServerSystemInfo? systemInfo;
  final bool collectStats;
  final bool collectSystemInfo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!collectStats && !collectSystemInfo) {
      return _StatsMessage(
        icon: Symbols.visibility_off,
        message: 'serversCollectionDisabled'.tr(),
      );
    }
    if (stats == null && systemInfo == null) {
      return _StatsMessage(
        icon: Symbols.sync,
        message: 'serversFetchingInfo'.tr(),
      );
    }

    final usedMemoryKb =
        stats?.memoryTotalKb == null || stats?.memoryAvailableKb == null
        ? null
        : stats!.memoryTotalKb! - stats!.memoryAvailableKb!;
    final memoryRatio =
        usedMemoryKb == null ||
            stats?.memoryTotalKb == null ||
            stats!.memoryTotalKb == 0
        ? null
        : (usedMemoryKb / stats!.memoryTotalKb!).clamp(0.0, 1.0);
    final memoryPercent = memoryRatio == null
        ? null
        : (memoryRatio * 100).round();
    final gpus = stats?.gpus ?? const <ServerGpuStats>[];
    final gpuUtilization = _averageGpuUtilization(gpus);
    final gpuMemoryUsedKb = _sumGpuMemory(gpus, used: true);
    final gpuMemoryTotalKb = _sumGpuMemory(gpus, used: false);
    // Distribution and version only; the kernel name is still collected
    // but too noisy for a dashboard card.
    final systemLabel = systemInfo?.distribution ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'detailLoadAverage'.tr(),
                  value: stats!.loadAverage?.toStringAsFixed(2) ?? '—',
                  detail: _loadDetail(stats!.loadAverage),
                  valueColor: _loadColor(stats!.loadAverage, colorScheme),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'detailMemory'.tr(),
                  value: memoryPercent == null ? '—' : '$memoryPercent%',
                  detail: usedMemoryKb == null || stats!.memoryTotalKb == null
                      ? null
                      : '${formatKilobytes(usedMemoryKb)} / ${formatKilobytes(stats!.memoryTotalKb!)}',
                  progress: memoryRatio,
                  progressColor: _memoryColor(memoryRatio, colorScheme),
                  valueColor: _memoryColor(memoryRatio, colorScheme),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'detailUptime'.tr(),
                  value: formatUptime(stats!.uptime),
                  detail: _uptimeDetail(stats!.uptime),
                ),
              ),
              // GPU joins the same row as a fourth tile: a second row does
              // not fit the card's fixed height.
              if (gpus.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'detailGpu'.tr(),
                    value: gpuUtilization == null
                        ? '—'
                        : '${gpuUtilization.toStringAsFixed(0)}%',
                    detail: 'detailGpuCount'.tr(args: ['${gpus.length}']),
                    progress:
                        gpuMemoryUsedKb == null || gpuMemoryTotalKb == null
                        ? null
                        : (gpuMemoryUsedKb / gpuMemoryTotalKb).clamp(0.0, 1.0),
                    progressColor: _memoryColor(
                      gpuMemoryUsedKb == null || gpuMemoryTotalKb == null
                          ? null
                          : (gpuMemoryUsedKb / gpuMemoryTotalKb).clamp(
                              0.0,
                              1.0,
                            ),
                      colorScheme,
                    ),
                  ),
                ),
              ],
            ],
          )
        else if (collectStats)
          _StatsMessage(
            icon: Symbols.query_stats,
            message: 'serversStatsUnavailable'.tr(),
          ),
        if (systemLabel.isNotEmpty) ...[
          const SizedBox(height: 8),

          Text(
            systemLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ).padding(horizontal: 4),
        ],
        if (stats?.updatedAt != null) ...[
          Text(
            'detailRefreshDetailsAt'.tr(
              args: [relativeTimeLabel(stats!.updatedAt)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
          ).padding(horizontal: 4),
        ],
      ],
    );
  }

  static double? _averageGpuUtilization(List<ServerGpuStats> gpus) {
    final values = gpus
        .map((gpu) => gpu.utilizationPercent)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static int? _sumGpuMemory(List<ServerGpuStats> gpus, {required bool used}) {
    final values = gpus
        .map((gpu) => used ? gpu.memoryUsedKb : gpu.memoryTotalKb)
        .whereType<int>()
        .toList();
    if (values.isEmpty) return null;
    return values.fold<int>(0, (sum, value) => sum + value);
  }

  static String? _loadDetail(double? load) {
    if (load == null) return null;
    if (load < 1) return 'serversLoadIdle'.tr();
    if (load < 2) return 'serversLoadNormal'.tr();
    if (load < 4) return 'serversLoadBusy'.tr();
    return 'serversLoadHigh'.tr();
  }

  static String? _uptimeDetail(Duration? uptime) {
    if (uptime == null || uptime.inSeconds == 0) return null;
    if (uptime.inDays >= 30) return 'serversUptimeStable'.tr();
    if (uptime.inHours < 1) return 'serversUptimeRecent'.tr();
    return null;
  }

  static Color? _loadColor(double? load, ColorScheme scheme) {
    if (load == null) return null;
    if (load >= 4) return scheme.error;
    if (load >= 2) return scheme.tertiary;
    return null;
  }

  static Color? _memoryColor(double? ratio, ColorScheme scheme) {
    if (ratio == null) return null;
    if (ratio >= 0.9) return scheme.error;
    if (ratio >= 0.75) return scheme.tertiary;
    return null;
  }
}

class _StatsMessage extends StatelessWidget {
  const _StatsMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.detail,
    this.progress,
    this.progressColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? detail;
  final double? progress;
  final Color? progressColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final resolvedValueColor = valueColor ?? colorScheme.onSurface;
    final resolvedProgressColor = progressColor ?? colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (textTheme.titleMedium)?.copyWith(
                color: resolvedValueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: 8),
            if (progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  color: resolvedProgressColor,
                ),
              )
            else
              SizedBox(height: 4),
            ...[
              const SizedBox(height: 6),
              Text(
                detail ?? ' ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyServers extends StatelessWidget {
  const _EmptyServers({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.dns,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'serversEmpty'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('serversEmptyHint'.tr()),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Symbols.add),
            label: Text('serversAddServer'.tr()),
          ),
        ],
      ),
    ),
  );
}
