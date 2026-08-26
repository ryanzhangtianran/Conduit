import 'package:flutter/foundation.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'server_providers.dart';

/// The full order after a visible subset was reordered: servers hidden by a
/// filter keep their slots, the visible ones take the remaining slots in
/// their new order.
List<int> applyVisibleOrder({
  required List<int> all,
  required List<int> visibleBefore,
  required List<int> visibleAfter,
}) {
  final visible = visibleBefore.toSet();
  final slots = [
    for (final (index, id) in all.indexed)
      if (visible.contains(id)) index,
  ];
  final result = [...all];
  for (final (k, slot) in slots.indexed) {
    if (k < visibleAfter.length) result[slot] = visibleAfter[k];
  }
  return result;
}

/// The grip icon marking a card or row as draggable.
class ServerDragHandle extends StatelessWidget {
  const ServerDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Symbols.drag_indicator,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Persists [orderedIds] as the dashboard order. Ids the repository does not
/// own (the local machine) are ignored.
Future<void> persistServerOrder(WidgetRef ref, List<int> orderedIds) =>
    ref.read(serverRepositoryProvider).reorderServers(orderedIds);

/// A grid of server cards that can be reordered by dragging a card; the
/// other cards slide out of the way, and the new order is persisted when the
/// card is released.
///
/// [servers] are the cards shown (already filtered, in display order);
/// [allServers] is the full dashboard order the persisted result is derived
/// from, so hidden servers keep their place.
class ReorderableServerGrid extends ConsumerStatefulWidget {
  const ReorderableServerGrid({
    super.key,
    required this.servers,
    required this.gridDelegate,
    required this.itemBuilder,
    List<Server>? allServers,
    this.padding = EdgeInsets.zero,
  }) : allServers = allServers ?? servers;

  final List<Server> servers;
  final List<Server> allServers;
  final SliverGridDelegate gridDelegate;
  final EdgeInsetsGeometry padding;
  final Widget Function(BuildContext context, Server server) itemBuilder;

  @override
  ConsumerState<ReorderableServerGrid> createState() =>
      _ReorderableServerGridState();
}

class _ReorderableServerGridState extends ConsumerState<ReorderableServerGrid> {
  final _scrollController = ScrollController();

  /// The order shown between a drop and the database echoing it back.
  List<int>? _pendingOrder;

  @override
  void didUpdateWidget(covariant ReorderableServerGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pendingOrder;
    if (pending != null &&
        listEquals(pending, [for (final s in widget.servers) s.id])) {
      _pendingOrder = null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Server> get _ordered {
    final pending = _pendingOrder;
    if (pending == null) return widget.servers;
    final byId = {for (final server in widget.servers) server.id: server};
    return [for (final id in pending) ?byId.remove(id), ...byId.values];
  }

  void _onReorder(ReorderedListFunction<Server> reorder, List<Server> shown) {
    final after = reorder(shown);
    final afterIds = [for (final server in after) server.id];
    setState(() => _pendingOrder = afterIds);
    persistServerOrder(
      ref,
      applyVisibleOrder(
        all: [for (final server in widget.allServers) server.id],
        visibleBefore: [for (final server in shown) server.id],
        visibleAfter: afterIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _ordered;
    return ReorderableBuilder<Server>.builder(
      itemCount: shown.length,
      scrollController: _scrollController,
      // Drag starts as soon as the pointer moves; no long press.
      longPressDelay: Duration.zero,
      onReorder: (reorder) => _onReorder(reorder, shown),
      childBuilder: (itemBuilder) => GridView.builder(
        controller: _scrollController,
        padding: widget.padding,
        gridDelegate: widget.gridDelegate,
        itemCount: shown.length,
        itemBuilder: (context, index) {
          final server = shown[index];
          return itemBuilder(
            KeyedSubtree(
              // The package reads keys as `ValueKey<String>`.
              key: ValueKey('${server.id}'),
              child: widget.itemBuilder(context, server),
            ),
            index,
          );
        },
      ),
    );
  }
}
