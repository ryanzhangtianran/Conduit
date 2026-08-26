import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/github/github_workflow_strip.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'package:conduit/shared/presentation/collapsible_section.dart';
import 'package:conduit/shared/presentation/relative_time.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'server_connection_actions.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'privacy_preferences.dart';
import 'ssh_config_sync.dart';
import 'ssh_key_setup_dialog.dart';
import 'terminal_tabs_provider.dart';

class ServerDashboardTab extends ConsumerWidget {
  const ServerDashboardTab({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(serverRepositoryProvider);
    final servers = await repository.all();
    if (!context.mounted) return;
    final draft = await showDialog<ServerDraft>(
      context: context,
      builder: (_) => ServerEditorDialog(servers: servers),
    );
    if (draft == null || !context.mounted) return;
    try {
      final server = await ref.read(serverRepositoryProvider).create(draft);
      if (!context.mounted) return;
      await _connect(context, ref, server);
    } catch (_) {
      if (context.mounted) {
        showStyledSnackBar(
          message: 'serversSaveError'.tr(),
          title: 'serversSaveError'.tr(),
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    Server server,
  ) async {
    if (server.connectionType == ServerConnectionType.local.name) {
      await openLocalTerminalSession(context, ref, server);
    } else {
      await connectForStatistics(context, ref, server);
    }
  }

  Future<void> _reconnectAll(
    BuildContext context,
    WidgetRef ref,
    List<Server> servers,
  ) async {
    for (final server in servers) {
      if (!context.mounted) return;
      await _connect(context, ref, server);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Server server) async {
    try {
      final repository = ref.read(serverRepositoryProvider);
      final credential = server.credentialId == null
          ? null
          : await repository.credentialFor(server);
      final proxy = await repository.proxyFor(server);
      final servers = await repository.all();
      if (!context.mounted) return;
      final draft = await showDialog<ServerDraft>(
        context: context,
        builder: (_) => ServerEditorDialog(
          servers: servers,
          serverId: server.id,
          initial: ServerDraft(
            name: server.name,
            host: server.host,
            port: server.port,
            username: server.username,
            credential: credential,
            credentialId: server.credentialId,
            collectStats: server.collectStats,
            collectSystemInfo: server.collectSystemInfo,
            proxy: proxy,
            jumpHostServerId: server.jumpHostServerId,
            environment: decodeEnvironmentMap(server.environment),
            tags: decodeStringList(server.tags),
            connectionType:
                ServerConnectionType.values
                    .asNameMap()[server.connectionType] ??
                ServerConnectionType.ssh,
          ),
        ),
      );
      if (draft != null) {
        await repository.update(server, draft);
      }
    } catch (error) {
      if (context.mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'serversEditError'.tr(),
          icon: Symbols.error_outline,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _delete(WidgetRef ref, Server server) async {
    await ref.read(terminalTabsProvider.notifier).closeForServer(server.id);
    await ref.read(connectionManagerProvider).disconnect(server.id);
    await ref.read(serverRepositoryProvider).delete(server);
  }

  /// Closes the server's terminals, then the retained background session
  /// (which also tears down its port forwards and proxy tunnel).
  Future<void> _disconnect(WidgetRef ref, Server server) async {
    await ref.read(terminalTabsProvider.notifier).closeForServer(server.id);
    await ref.read(connectionManagerProvider).disconnect(server.id);
  }

  /// Persists the full dashboard order selected in arrange mode.
  Future<void> _reorderServers(WidgetRef ref, List<int> orderedIds) async {
    final repository = ref.read(serverRepositoryProvider);
    await repository.reorderServers(orderedIds);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
    return _ServersCatalog(
      servers: servers,
      sessions: sessions,
      onAdd: () => _add(context, ref),
      onConnect: (server) => _connect(context, ref, server),
      onReconnectAll: (disconnectedServers) =>
          _reconnectAll(context, ref, disconnectedServers),
      onEdit: (server) => _edit(context, ref, server),
      onDisconnect: (server) => _disconnect(ref, server),
      onDelete: (server) => _delete(ref, server),
      onReorder: (orderedIds) => _reorderServers(ref, orderedIds),
      onOpenDetail: (server) {
        ref.read(monitorSelectedServerIdProvider.notifier).select(server.id);
        AutoTabsRouter.of(context).setActiveIndex(2);
      },
      onRefresh: (server) =>
          server.connectionType == ServerConnectionType.local.name
          ? ref.read(localConnectionManagerProvider).refreshNow()
          : ref.read(connectionManagerProvider).refreshServerInfo(server),
    );
  }
}

@RoutePage()
class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) => const ServerDashboardTab();
}

class _ServersCatalog extends StatelessWidget {
  const _ServersCatalog({
    required this.servers,
    required this.sessions,
    required this.onAdd,
    required this.onConnect,
    required this.onReconnectAll,
    required this.onEdit,
    required this.onDisconnect,
    required this.onDelete,
    required this.onReorder,
    required this.onOpenDetail,
    required this.onRefresh,
  });

  final AsyncValue<List<Server>> servers;
  final List<SshSessionInfo> sessions;
  final VoidCallback onAdd;
  final ValueChanged<Server> onConnect;
  final Future<void> Function(List<Server>) onReconnectAll;
  final ValueChanged<Server> onEdit;
  final ValueChanged<Server> onDisconnect;
  final ValueChanged<Server> onDelete;
  final Future<void> Function(List<int> orderedIds) onReorder;
  final ValueChanged<Server> onOpenDetail;
  final ValueChanged<Server> onRefresh;

  @override
  Widget build(BuildContext context) {
    return ConduitAppScaffold(
      body: servers.when(
        data: (items) => items.isEmpty
            ? _EmptyServers(onAdd: onAdd)
            : _ServerGrid(
                servers: items,
                sessions: sessions,
                onConnect: onConnect,
                onReconnectAll: onReconnectAll,
                onEdit: onEdit,
                onDisconnect: onDisconnect,
                onDelete: onDelete,
                onReorder: onReorder,
                onOpenDetail: onOpenDetail,
                onRefresh: onRefresh,
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('serversLoadError'.tr(args: [error.toString()])),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'servers-create-fab',
        onPressed: onAdd,
        icon: const Icon(Symbols.add),
        label: Text('serversAddServer'.tr()),
      ),
    );
  }
}

class _ServerGrid extends ConsumerStatefulWidget {
  const _ServerGrid({
    required this.servers,
    required this.sessions,
    required this.onConnect,
    required this.onReconnectAll,
    required this.onEdit,
    required this.onDisconnect,
    required this.onDelete,
    required this.onReorder,
    required this.onOpenDetail,
    required this.onRefresh,
  });

  final List<Server> servers;
  final List<SshSessionInfo> sessions;
  final ValueChanged<Server> onConnect;
  final Future<void> Function(List<Server>) onReconnectAll;
  final ValueChanged<Server> onEdit;
  final ValueChanged<Server> onDisconnect;
  final ValueChanged<Server> onDelete;
  final Future<void> Function(List<int> orderedIds) onReorder;
  final ValueChanged<Server> onOpenDetail;
  final ValueChanged<Server> onRefresh;

  @override
  ConsumerState<_ServerGrid> createState() => _ServerGridState();
}

class _ServerGridState extends ConsumerState<_ServerGrid> {
  var _isReconnecting = false;
  var _isArranging = false;
  var _isSavingOrder = false;
  final _selectedTags = <String>{};
  List<int>? _pendingOrder;

  List<Server> get _orderedServers {
    final pendingOrder = _pendingOrder;
    if (!_isArranging || pendingOrder == null) return widget.servers;

    final byId = {for (final server in widget.servers) server.id: server};
    return [for (final id in pendingOrder) ?byId.remove(id), ...byId.values];
  }

  void _startArranging() {
    setState(() {
      _isArranging = true;
      _selectedTags.clear();
      _pendingOrder = [for (final server in widget.servers) server.id];
    });
  }

  Future<void> _moveBefore(int draggedId, int targetId) async {
    if (_isSavingOrder || draggedId == targetId) return;
    final reordered = [for (final server in _orderedServers) server.id];
    final oldIndex = reordered.indexOf(draggedId);
    final targetIndex = reordered.indexOf(targetId);
    if (oldIndex < 0 || targetIndex < 0) return;

    reordered.removeAt(oldIndex);
    final insertionIndex = reordered.indexOf(targetId);
    reordered.insert(insertionIndex, draggedId);
    setState(() {
      _pendingOrder = reordered;
      _isSavingOrder = true;
    });
    try {
      await widget.onReorder(reordered);
    } catch (_) {
      if (mounted) {
        setState(() => _pendingOrder = null);
      }
    } finally {
      if (mounted) setState(() => _isSavingOrder = false);
    }
  }

  Future<void> _reconnectAll(List<Server> servers) async {
    setState(() => _isReconnecting = true);
    try {
      await widget.onReconnectAll(servers);
    } finally {
      if (mounted) setState(() => _isReconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsByServerId = {
      for (final session in widget.sessions) session.serverId: session,
    };
    final allTags =
        widget.servers
            .expand((server) => decodeStringList(server.tags))
            .toSet()
            .toList()
          ..sort();
    final visibleServers = _orderedServers.where((server) {
      final tags = decodeStringList(server.tags).toSet();
      return _selectedTags.every(tags.contains);
    }).toList();
    final disconnectedServers = visibleServers.where((server) {
      // The local machine is always reachable and never participates in
      // reconnect-all.
      if (server.connectionType == ServerConnectionType.local.name) {
        return false;
      }
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
                    onPressed: () => _reconnectAll(disconnectedServers),
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
        if (visibleServers.isEmpty)
          Expanded(
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: GithubWorkflowStatusStrip()),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: _NoServersMatch()),
                ),
                SliverToBoxAdapter(child: _arrangeServersFooter(context)),
              ],
            ),
          )
        else
          Expanded(
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: GithubWorkflowStatusStrip()),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisExtent: 280,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final server = visibleServers[index];
                      final session = sessionsByServerId[server.id];
                      final card = _ServerCard(
                        server: server,
                        session: session,
                        onConnect: () => widget.onConnect(server),
                        onDisconnect: () => widget.onDisconnect(server),
                        onOpenDetail: () => widget.onOpenDetail(server),
                        onRefresh: () => widget.onRefresh(server),
                      );
                      // The local machine is a virtual server: it is not in
                      // the database, so it cannot be reordered, edited, or
                      // deleted, and gets no context menu.
                      final isLocal =
                          server.connectionType ==
                          ServerConnectionType.local.name;
                      if (isLocal) return card;
                      if (_isArranging) {
                        return _ReorderableServerTile(
                          server: server,
                          isSavingOrder: _isSavingOrder,
                          onMoveBefore: _moveBefore,
                          child: card,
                        );
                      }
                      final connected =
                          session?.status == SessionStatus.connected;
                      return ContextMenuWidget(
                        menuProvider: (_) => Menu(
                          children: [
                            MenuAction(
                              title: 'serversEditServer'.tr(),
                              callback: () => widget.onEdit(server),
                            ),
                            if (connected)
                              MenuAction(
                                title: 'serversDisconnectServer'.tr(),
                                callback: () => widget.onDisconnect(server),
                              ),
                            MenuSeparator(),
                            MenuAction(
                              title: 'serversDeleteServer'.tr(),
                              attributes: const MenuActionAttributes(
                                destructive: true,
                              ),
                              callback: () => widget.onDelete(server),
                            ),
                          ],
                        ),
                        child: card,
                      );
                    }, childCount: visibleServers.length),
                  ),
                ),
                SliverToBoxAdapter(child: _arrangeServersFooter(context)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _arrangeServersFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _ArrangeServersControl(
                isArranging: _isArranging,
                canArrange: widget.servers.length > 1,
                onPressed: _isArranging
                    ? () => setState(() => _isArranging = false)
                    : _startArranging,
              ),
            ],
          ),
          if (_isArranging) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'serversArrangeHint'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArrangeServersControl extends StatelessWidget {
  const _ArrangeServersControl({
    required this.isArranging,
    required this.canArrange,
    required this.onPressed,
  });

  final bool isArranging;
  final bool canArrange;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isArranging) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Symbols.check),
        label: Text('serversDoneArranging'.tr()),
      );
    }

    return OutlinedButton.icon(
      onPressed: canArrange ? onPressed : null,
      icon: const Icon(Symbols.drag_indicator),
      label: Text('serversArrange'.tr()),
    );
  }
}

class _ReorderableServerTile extends StatelessWidget {
  const _ReorderableServerTile({
    required this.server,
    required this.isSavingOrder,
    required this.onMoveBefore,
    required this.child,
  });

  final Server server;
  final bool isSavingOrder;
  final Future<void> Function(int draggedId, int targetId) onMoveBefore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          !isSavingOrder && details.data != server.id,
      onAcceptWithDetails: (details) => onMoveBefore(details.data, server.id),
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            border: Border.all(
              color: isDropTarget
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(child: child),
              Positioned(
                // Keep the handle in the trailing corner while sharing the
                // vertical center of the leading server icon row.
                right: 8,
                top: 5,
                child: MouseRegion(
                  cursor: isSavingOrder
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.grab,
                  child: Draggable<int>(
                    data: server.id,
                    maxSimultaneousDrags: isSavingOrder ? 0 : 1,
                    feedback: _ServerDragFeedback(name: server.name),
                    childWhenDragging: const Opacity(
                      opacity: 0.35,
                      child: _ServerDragHandle(),
                    ),
                    child: const _ServerDragHandle(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerDragHandle extends StatelessWidget {
  const _ServerDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Symbols.drag_indicator, size: 20),
      ),
    );
  }
}

class _ServerDragFeedback extends StatelessWidget {
  const _ServerDragFeedback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.drag_indicator, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(name, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ),
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
    final hideAddresses = ref.watch(hideServerAddressesProvider);
    final isLocal = server.connectionType == ServerConnectionType.local.name;
    // The local machine is always reachable; its session may lag one refresh
    // behind, so never surface it as disconnected.
    final connected = isLocal || session?.status == SessionStatus.connected;
    final connecting = session?.status == SessionStatus.connecting;
    final failed = session?.status == SessionStatus.failed;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // The local machine has no SSH details page.
        onTap: isLocal ? null : onOpenDetail,
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
                      isLocal ? Symbols.computer : Symbols.dns,
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
                                  serverAddressLabel(
                                    server,
                                    hideAddresses: hideAddresses,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (isLocal) ...[
                                const SizedBox(width: 6),
                                _BadgeChip(label: 'localMachineBadge'.tr()),
                              ],
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
                    if (!isLocal) ...[
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

/// Small label chip shared by the local-machine badge and tag chips.
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
                      : '${_formatBytes(usedMemoryKb * 1024)} / ${_formatBytes(stats!.memoryTotalKb! * 1024)}',
                  progress: memoryRatio,
                  progressColor: _memoryColor(memoryRatio, colorScheme),
                  valueColor: _memoryColor(memoryRatio, colorScheme),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'detailUptime'.tr(),
                  value: _formatUptime(stats!.uptime),
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

String _formatBytes(int bytes) {
  const megabyte = 1024 * 1024;
  const gigabyte = 1024 * megabyte;
  return bytes >= gigabyte
      ? '${(bytes / gigabyte).toStringAsFixed(1)} GB'
      : '${(bytes / megabyte).toStringAsFixed(0)} MB';
}

String _formatUptime(Duration? uptime) {
  if (uptime == null || uptime.inSeconds == 0) return '—';
  final days = uptime.inDays;
  final hours = uptime.inHours.remainder(24);
  final minutes = uptime.inMinutes.remainder(60);
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
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

class ServerEditorDialog extends ConsumerStatefulWidget {
  const ServerEditorDialog({
    super.key,
    this.servers = const [],
    this.serverId,
    this.initial,
  });

  final ServerDraft? initial;
  final int? serverId;
  final List<Server> servers;
  @override
  ConsumerState<ServerEditorDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends ConsumerState<ServerEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  late final _port = TextEditingController(text: 'serverDefaultPort'.tr());
  final _user = TextEditingController();
  // Password and private key keep separate controllers: sharing one made
  // switching the credential type carry the password over into the key
  // field, which was then saved and later failed to parse as a PEM.
  final _password = TextEditingController();
  var _showPassword = false;
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();
  CredentialType _type = CredentialType.password;

  /// True while the user pastes a private key by hand; otherwise a set key is
  /// shown masked.
  bool _pastingKey = false;

  /// On-disk path of the current private key, once generated or exported in
  /// this editing session, so "sync to ssh config" can reference it.
  String? _localPrivateKeyPath;
  bool _collectStats = true;
  bool _collectSystemInfo = true;

  // Per-server proxy configuration.
  ServerProxyType _proxyType = ServerProxyType.none;
  final _proxyHost = TextEditingController();
  late final _proxyPort = TextEditingController(
    text: 'serverDefaultProxyPort'.tr(),
  );
  final _proxyUsername = TextEditingController();
  final _proxyPassword = TextEditingController();
  int? _jumpHostServerId;

  // Per-server environment variables and tags.
  final _envRows =
      <({TextEditingController name, TextEditingController value})>[];
  final _tags = <String>[];
  final _tagInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _name.text = initial.name;
    _host.text = initial.host;
    _port.text = initial.port.toString();
    _user.text = initial.username;
    final credential = initial.credential;
    if (credential != null) {
      _type = credential.type;
      _password.text = credential.password ?? '';
      // A stored key that is not a PEM block cannot be used; show the field
      // empty rather than a masked card claiming a key is set.
      final storedKey = credential.privateKey ?? '';
      _privateKey.text = storedKey.trimLeft().startsWith('-----BEGIN')
          ? storedKey
          : '';
      _passphrase.text = credential.keyPassphrase ?? '';
    }
    _jumpHostServerId = initial.jumpHostServerId;
    _collectStats = initial.collectStats;
    _collectSystemInfo = initial.collectSystemInfo;
    final proxy = initial.proxy;
    if (proxy != null) {
      _proxyType = proxy.type;
      _proxyHost.text = proxy.host;
      _proxyPort.text = proxy.port.toString();
      _proxyUsername.text = proxy.username ?? '';
      // The stored password is not decrypted into the form; leaving the field
      // blank keeps the existing password when saving.
    }
    _tags.addAll(initial.tags);
    for (final entry in initial.environment.entries) {
      _envRows.add((
        name: TextEditingController(text: entry.key),
        value: TextEditingController(text: entry.value),
      ));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _host,
      _port,
      _user,
      _password,
      _privateKey,
      _passphrase,
      _proxyHost,
      _proxyPort,
      _proxyUsername,
      _proxyPassword,
      _tagInput,
    ]) {
      controller.dispose();
    }
    for (final row in _envRows) {
      row.name.dispose();
      row.value.dispose();
    }
    super.dispose();
  }

  Future<void> _pickKey() async {
    final result = await FilePicker.pickFiles(withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes != null) {
      setState(() {
        _privateKey.text = String.fromCharCodes(bytes);
        _pastingKey = false;
      });
    }
  }

  void _addEnvRow() {
    setState(() {
      _envRows.add((
        name: TextEditingController(),
        value: TextEditingController(),
      ));
    });
  }

  void _removeEnvRow(
    ({TextEditingController name, TextEditingController value}) row,
  ) {
    setState(() => _envRows.remove(row));
    row.name.dispose();
    row.value.dispose();
  }

  void _addTag() {
    final candidates = _tagInput.text
        .split(RegExp(r'[,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return;
    setState(() {
      for (final tag in candidates) {
        if (!_tags.contains(tag)) _tags.add(tag);
      }
      _tagInput.clear();
    });
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'serverPortRequired'.tr() : null;

  /// Rejects anything that is not a PEM block before it reaches the vault:
  /// a bad key otherwise only surfaces at connect time as a FormatException.
  String? _privateKeyPem(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'serverPortRequired'.tr();
    return text.startsWith('-----BEGIN')
        ? null
        : 'serverPrivateKeyInvalid'.tr();
  }

  String? _validPort(String? value) {
    final port = int.tryParse(value ?? '');
    return port != null && port > 0 && port < 65536
        ? null
        : 'serverPortInvalid'.tr();
  }

  String _jumpHostSummary() {
    if (_jumpHostServerId == null) return 'serverJumpHostNone'.tr();
    final names = <String>[];
    final visited = <int>{};
    var current = _jumpHostServerId;
    while (current != null && visited.add(current)) {
      final host = widget.servers
          .where((server) => server.id == current)
          .firstOrNull;
      if (host == null) {
        names.add('serverJumpHostMissing'.tr());
        break;
      }
      names.add(host.name);
      current = host.jumpHostServerId;
    }
    return names.reversed.join(' → ');
  }

  /// Generates a key pair and installs it on the server described by the
  /// form, then switches the form to private-key authentication.
  Future<void> _setUpKeyPair() async {
    final host = _host.text.trim();
    final username = _user.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || username.isEmpty || port == null) {
      showStyledSnackBar(
        message: 'sshKeyNeedHost'.tr(),
        title: 'sshKeyDialogTitle'.tr(),
        icon: Symbols.key,
        accentColor: Theme.of(context).colorScheme.error,
      );
      return;
    }
    // A live session (present when editing an already-connected server)
    // carries the install through jump hosts and proxies, which the
    // dialog's direct dial cannot reach.
    var sessionClient = widget.serverId == null
        ? null
        : ref.read(connectionManagerProvider).clientFor(widget.serverId!);
    Future<SSHSocket> Function()? dialSocket;
    if (sessionClient == null &&
        (_jumpHostServerId != null || _proxyType != ServerProxyType.none)) {
      if (widget.serverId != null) {
        // A saved server: bring the jump chain and the server up first,
        // then reuse that session for the install.
        final server = (await ref.read(serverRepositoryProvider).all())
            .where((server) => server.id == widget.serverId)
            .firstOrNull;
        if (server == null || !mounted) return;
        final loading = showConduitLoadingModal(
          context,
          message: 'commonConnecting'.tr(),
        );
        try {
          final connected = await connectForStatistics(context, ref, server);
          if (!connected) return;
        } finally {
          loading.dismiss();
        }
        if (!mounted) return;
        sessionClient = ref
            .read(connectionManagerProvider)
            .clientFor(widget.serverId!);
        if (sessionClient == null) return;
      } else if (_jumpHostServerId != null) {
        // An unsaved draft behind a jump host: connect the (saved) jump
        // chain and dial the target through it, no save needed.
        final jumpServer = (await ref.read(serverRepositoryProvider).all())
            .where((server) => server.id == _jumpHostServerId)
            .firstOrNull;
        if (jumpServer == null || !mounted) return;
        if (ref.read(connectionManagerProvider).clientFor(jumpServer.id) ==
            null) {
          final loading = showConduitLoadingModal(
            context,
            message: 'commonConnecting'.tr(),
          );
          try {
            final connected = await connectForStatistics(
              context,
              ref,
              jumpServer,
            );
            if (!connected) return;
          } finally {
            loading.dismiss();
          }
        }
        if (!mounted) return;
        final jumpClient = ref
            .read(connectionManagerProvider)
            .clientFor(_jumpHostServerId!);
        if (jumpClient == null) return;
        dialSocket = () => jumpClient.forwardLocal(host, port);
      } else {
        // An unsaved draft that needs a proxy has no dialable path yet.
        showStyledSnackBar(
          message: 'sshKeyConnectFirst'.tr(),
          title: 'sshKeyDialogTitle'.tr(),
          icon: Symbols.key,
          accentColor: Theme.of(context).colorScheme.error,
        );
        return;
      }
    }
    final result = await showSshKeySetupDialog(
      context,
      serverName: _name.text.trim().isEmpty ? host : _name.text.trim(),
      host: host,
      port: port,
      username: username,
      initialPassword: _password.text.isEmpty ? null : _password.text,
      sessionClient: sessionClient,
      dialSocket: dialSocket,
    );
    if (result == null || !mounted) return;
    setState(() {
      _type = CredentialType.privateKey;
      _privateKey.text = result.keyPair.privateKey;
      _passphrase.text = result.passphrase ?? '';
      _pastingKey = false;
      _localPrivateKeyPath = result.keyPair.privateKeyPath;
    });
    showStyledSnackBar(
      message: 'sshKeyInstalled'.tr(args: [result.keyPair.privateKeyPath]),
      title: 'sshKeyDialogTitle'.tr(),
      icon: Symbols.check_circle,
    );
  }

  /// Writes or updates this server's `Host` entry in the local ssh config.
  /// A private key that only lives in the form/vault is first exported to
  /// the local key directory (mode 600) so `IdentityFile` can point at it.
  Future<void> _syncToSshConfig() async {
    final host = _host.text.trim();
    final username = _user.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || username.isEmpty || port == null) {
      showStyledSnackBar(
        message: 'sshKeyNeedHost'.tr(),
        title: 'sshConfigSyncEntry'.tr(),
        icon: Symbols.description,
        accentColor: Theme.of(context).colorScheme.error,
      );
      return;
    }
    final serverName = _name.text.trim().isEmpty ? host : _name.text.trim();
    final alias = sshConfigAliasFor(serverName);
    final config = ref.read(sshKeyStorageConfigProvider);
    try {
      String? identityFile;
      if (_type == CredentialType.privateKey && _privateKey.text.isNotEmpty) {
        final path = _localPrivateKeyPath ??= await ref
            .read(sshKeyServiceProvider)
            .ensurePrivateKeyFile(
              privateKey: _privateKey.text,
              fileStem:
                  'conduit_${sshConfigAliasFor(serverName).toLowerCase()}',
              config: config,
            );
        identityFile = tildePath(path);
      }
      final written = await syncSshConfigFile(
        SshConfigEntry(
          alias: alias,
          hostName: host,
          user: username,
          port: port,
          identityFile: identityFile,
        ),
        configPath: config.sshConfigPath,
      );
      if (!mounted) return;
      showStyledSnackBar(
        message: 'sshKeyConfigSynced'.tr(args: [alias, written, alias]),
        title: 'sshConfigSyncEntry'.tr(),
        icon: Symbols.check_circle,
      );
    } catch (error) {
      if (!mounted) return;
      showStyledSnackBar(
        message: 'sshKeyConfigSyncFailed'.tr(args: ['$error']),
        title: 'sshConfigSyncEntry'.tr(),
        icon: Symbols.warning,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
  }

  bool _hasJumpHostCycle() {
    if (_jumpHostServerId == null) return false;
    var current = _jumpHostServerId;
    final visited = <int>{};
    while (current != null) {
      if (!visited.add(current) || current == widget.serverId) return true;
      current = widget.servers
          .where((server) => server.id == current)
          .firstOrNull
          ?.jumpHostServerId;
    }
    return false;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_hasJumpHostCycle()) {
      showStyledSnackBar(
        message: 'serverJumpHostCycle'.tr(),
        title: 'serverJumpHostLabel'.tr(),
        icon: Symbols.account_tree,
        accentColor: Theme.of(context).colorScheme.error,
      );
      return;
    }
    // The masked key card has no form field, so the PEM check runs here too.
    if (_type == CredentialType.privateKey &&
        _privateKeyPem(_privateKey.text) != null) {
      showStyledSnackBar(
        message: 'serverPrivateKeyInvalid'.tr(),
        title: 'serverAuthPrivateKey'.tr(),
        icon: Symbols.key_off,
        accentColor: Theme.of(context).colorScheme.error,
      );
      return;
    }
    // The credential is part of the server itself: always saved from the
    // inline fields, never picked from a shared pool.
    final credential = _type == CredentialType.password
        ? ServerCredential.password(_password.text)
        : ServerCredential.privateKey(
            privateKey: _privateKey.text,
            keyPassphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          );
    Navigator.pop(
      context,
      ServerDraft(
        name: _name.text,
        host: _host.text,
        port: int.parse(_port.text),
        jumpHostServerId: _jumpHostServerId,
        username: _user.text,
        credential: credential,
        credentialName: _name.text,
        collectStats: _collectStats,
        collectSystemInfo: _collectSystemInfo,
        proxy: _proxyType == ServerProxyType.none
            ? null
            : ServerProxy(
                type: _proxyType,
                host: _proxyHost.text.trim(),
                port: int.parse(_proxyPort.text),
                username: _proxyUsername.text.trim().isEmpty
                    ? null
                    : _proxyUsername.text.trim(),
                password: _proxyPassword.text.isEmpty
                    ? null
                    : _proxyPassword.text,
              ),
        environment: {
          for (final row in _envRows)
            if (row.name.text.trim().isNotEmpty)
              row.name.text.trim(): row.value.text,
        },
        tags: List.of(_tags),
        connectionType: ServerConnectionType.ssh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A floating dialog rather than a bottom sheet: the form hugs its
    // content up to a maximum height and scrolls inside.
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (widget.serverId == null
                              ? 'serversAddSheetTitle'
                              : 'serversEditServer')
                          .tr(),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'commonCancel'.tr(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Symbols.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Form(
                key: _form,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'serverNameLabel'.tr(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _host,
                            decoration: InputDecoration(
                              labelText: 'serverHostLabel'.tr(),
                            ),
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _port,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'serverPortLabel'.tr(),
                            ),
                            validator: _validPort,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _user,
                      decoration: InputDecoration(
                        labelText: 'serverUsernameLabel'.tr(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    ConduitCollapsibleSection(
                      initiallyExpanded: _jumpHostServerId != null,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text('serverJumpHostLabel'.tr()),
                      subtitle: Text(_jumpHostSummary()),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DropdownButtonFormField<int?>(
                            initialValue: _jumpHostServerId,
                            decoration: InputDecoration(
                              labelText: 'serverJumpHostLabel'.tr(),
                              helperText: 'serverJumpHostHint'.tr(),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('serverJumpHostNone'.tr()),
                              ),
                              if (_jumpHostServerId != null &&
                                  !widget.servers.any(
                                    (server) => server.id == _jumpHostServerId,
                                  ))
                                DropdownMenuItem<int?>(
                                  value: _jumpHostServerId,
                                  child: Text('serverJumpHostMissing'.tr()),
                                ),
                              for (final candidate in widget.servers)
                                if (candidate.id != widget.serverId &&
                                    candidate.connectionType ==
                                        ServerConnectionType.ssh.name)
                                  DropdownMenuItem<int?>(
                                    value: candidate.id,
                                    child: Text(candidate.name),
                                  ),
                            ],
                            onChanged: (value) =>
                                setState(() => _jumpHostServerId = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConduitCollapsibleSection(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text('serverProxyLabel'.tr()),
                      subtitle: Text(switch (_proxyType) {
                        ServerProxyType.none => 'serverProxyNone'.tr(),
                        ServerProxyType.http => 'serverProxyHttp'.tr(),
                        ServerProxyType.socks5 => 'serverProxySocks5'.tr(),
                      }),
                      children: [
                        SegmentedButton<ServerProxyType>(
                          segments: [
                            ButtonSegment(
                              value: ServerProxyType.none,
                              label: Text('serverProxyNone'.tr()),
                            ),
                            ButtonSegment(
                              value: ServerProxyType.http,
                              label: Text('serverProxyHttp'.tr()),
                            ),
                            ButtonSegment(
                              value: ServerProxyType.socks5,
                              label: Text('serverProxySocks5'.tr()),
                            ),
                          ],
                          selected: {_proxyType},
                          onSelectionChanged: (value) =>
                              setState(() => _proxyType = value.first),
                        ),
                        if (_proxyType != ServerProxyType.none) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _proxyHost,
                                  decoration: InputDecoration(
                                    labelText: 'serverProxyHostLabel'.tr(),
                                  ),
                                  validator: _required,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: _proxyPort,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'serverProxyPortLabel'.tr(),
                                  ),
                                  validator: _validPort,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _proxyUsername,
                            decoration: InputDecoration(
                              labelText: 'serverProxyUsernameLabel'.tr(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _proxyPassword,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'serverProxyPasswordLabel'.tr(),
                              helperText: widget.initial?.proxy != null
                                  ? 'serverProxyPasswordKeepHint'.tr()
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<CredentialType>(
                      segments: [
                        ButtonSegment(
                          value: CredentialType.password,
                          label: Text('serverAuthPassword'.tr()),
                        ),
                        ButtonSegment(
                          value: CredentialType.privateKey,
                          label: Text('serverAuthPrivateKey'.tr()),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (value) =>
                          setState(() => _type = value.first),
                    ),
                    const SizedBox(height: 12),
                    if (_type == CredentialType.password)
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'serverPasswordLabel'.tr(),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Symbols.visibility_off
                                  : Symbols.visibility,
                            ),
                          ),
                        ),
                        validator: _required,
                      )
                    else ...[
                      // A stored or generated key is never echoed back: only
                      // a masked card with replace actions. The editable text
                      // field appears when no key is set or the user opts to
                      // paste one.
                      if (_privateKey.text.isNotEmpty && !_pastingKey)
                        _PrivateKeyCard(
                          onPickFile: _pickKey,
                          onPaste: () => setState(() {
                            _privateKey.clear();
                            _pastingKey = true;
                          }),
                        )
                      else
                        TextFormField(
                          controller: _privateKey,
                          minLines: 4,
                          maxLines: 8,
                          validator: _privateKeyPem,
                          decoration: InputDecoration(
                            labelText: 'serverPrivateKeyLabel'.tr(),
                            suffixIcon: IconButton(
                              onPressed: _pickKey,
                              icon: const Icon(Symbols.upload_file),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passphrase,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'serverKeyPassphraseLabel'.tr(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Both actions share the row so their outer edges line up
                    // with the fields and the private key card above.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setUpKeyPair,
                            icon: const Icon(Symbols.key, size: 18),
                            label: Text('sshKeyGenerateEntry'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _syncToSshConfig,
                            icon: const Icon(Symbols.description, size: 18),
                            label: Text('sshConfigSyncEntry'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConduitCollapsibleSection(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text('serverEnvironmentLabel'.tr()),
                      subtitle: Text('serverEnvironmentHint'.tr()),
                      children: [
                        for (final row in _envRows) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: row.name,
                                  decoration: InputDecoration(
                                    labelText: 'serverEnvNameLabel'.tr(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: row.value,
                                  decoration: InputDecoration(
                                    labelText: 'serverEnvValueLabel'.tr(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'serverRemoveVariable'.tr(),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _removeEnvRow(row),
                                icon: const Icon(Symbols.close, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addEnvRow,
                            icon: const Icon(Symbols.add, size: 18),
                            label: Text('serverAddEnvVar'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConduitCollapsibleSection(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text('serverTagsLabel'.tr()),
                      subtitle: Text('serverTagsAddHint'.tr()),
                      children: [
                        if (_tags.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in _tags)
                                  InputChip(
                                    label: Text(tag),
                                    onDeleted: () =>
                                        setState(() => _tags.remove(tag)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tagInput,
                                decoration: InputDecoration(
                                  labelText: 'serverTagAdd'.tr(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _addTag(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _addTag,
                              icon: const Icon(Symbols.add, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('serverCollectStats'.tr()),
                      subtitle: Text('serverCollectStatsHint'.tr()),
                      value: _collectStats,
                      onChanged: (value) =>
                          setState(() => _collectStats = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('serverDiscoverSystemInfo'.tr()),
                      subtitle: Text('serverDiscoverSystemInfoHint'.tr()),
                      value: _collectSystemInfo,
                      onChanged: (value) =>
                          setState(() => _collectSystemInfo = value),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('commonCancel'.tr()),
                        ),
                        FilledButton(
                          onPressed: _save,
                          child: Text('serverSaveAndConnect'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Masked stand-in for a private key that is already set. The key material
/// itself is never rendered; the user can replace it from a file or paste a
/// new one.
class _PrivateKeyCard extends StatelessWidget {
  const _PrivateKeyCard({required this.onPickFile, required this.onPaste});

  final VoidCallback onPickFile;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.lock, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'serverPrivateKeySet'.tr(),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '••••••••••••••••••••••••',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onPickFile,
                  icon: const Icon(Symbols.upload_file, size: 18),
                  label: Text('serverPrivateKeyReplaceFile'.tr()),
                ),
                TextButton.icon(
                  onPressed: onPaste,
                  icon: const Icon(Symbols.content_paste, size: 18),
                  label: Text('serverPrivateKeyPaste'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
