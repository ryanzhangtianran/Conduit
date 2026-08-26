import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/github/github_providers.dart';
import 'package:conduit/routing/app_router.dart';
import 'package:conduit/routing/app_router.gr.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'package:styled_widget/styled_widget.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

/// The workspace tabs, in route order: [index] is the tab's position in the
/// [AutoTabsRouter] and the value the persisted navigation order stores.
/// Settings stays pinned at the bottom of the rail; the rest can be dragged
/// into a custom order.
enum WorkspaceTab {
  dashboard(Symbols.dashboard, 'tabDashboard'),
  terminal(Symbols.terminal, 'tabTerminal'),
  monitor(Symbols.monitoring, 'tabMonitor'),
  connections(Symbols.dns, 'assetsConnections'),
  github(Symbols.rocket_launch, 'tabGithub', badged: true),
  portForwarding(Symbols.swap_horiz, 'tabPortForwarding'),
  settings(Symbols.settings, 'tabSettings');

  const WorkspaceTab(this.icon, this.labelKey, {this.badged = false});

  final IconData icon;
  final String labelKey;

  /// Shows the GitHub failure badge on this destination.
  final bool badged;

  PageRouteInfo get route => switch (this) {
    dashboard => ServersTab(),
    terminal => const TerminalRoute(),
    monitor => const MonitorRoute(),
    connections => ConnectionsTab(),
    github => GithubTab(),
    portForwarding => const PortForwardingRoute(),
    settings => const SettingsRoute(),
  };

  /// The tab router's routes, one per value in order.
  static List<PageRouteInfo> get routes => [
    for (final tab in values) tab.route,
  ];
}

@RoutePage()
class ServerWorkspacePage extends StatelessWidget {
  const ServerWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: WorkspaceTab.routes,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transitionBuilder: (context, child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      builder: (context, child) => _ServerTabsShell(child: child),
    );
  }
}

class _ServerTabsShell extends ConsumerWidget {
  const _ServerTabsShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsRouter = AutoTabsRouter.of(context);
    // Hide the mobile bottom bar while a session tab is focused so the
    // terminal keeps the full height.
    final immersiveSession =
        tabsRouter.activeIndex == WorkspaceTab.terminal.index &&
        ref.watch(
          terminalTabsProvider.select((tabs) => tabs.selectedTab != null),
        );
    final githubHasFailures = ref.watch(githubHasFailuresProvider);
    final order = ref.watch(navigationOrderProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 768;

        return ConduitAppScaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          // Each tab page is its own page scaffold; let it manage the top
          // safe area so its surface paints edge-to-edge behind the status bar.
          topSafeArea: false,
          body: isWide
              ? Row(
                  children: [
                    _ReorderableNavRail(
                      order: order,
                      activeIndex: tabsRouter.activeIndex,
                      githubHasFailures: githubHasFailures,
                      onSelected: tabsRouter.setActiveIndex,
                      onReorder: (from, to) => ref
                          .read(navigationOrderProvider.notifier)
                          .move(from, to),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                        ),
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: child,
                        ),
                      ),
                    ),
                  ],
                )
              : child,
          bottomNavigationBar: isWide || immersiveSession
              ? null
              : Material(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    height: 56,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                    selectedIndex:
                        tabsRouter.activeIndex == WorkspaceTab.settings.index
                        ? order.length
                        : order.indexOf(tabsRouter.activeIndex),
                    onDestinationSelected: (index) => tabsRouter.setActiveIndex(
                      index == order.length
                          ? WorkspaceTab.settings.index
                          : order[index],
                    ),
                    destinations: [
                      for (final tab in order.map(
                        (routeIndex) => WorkspaceTab.values[routeIndex],
                      ))
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: tab.badged && githubHasFailures,
                            child: Icon(tab.icon),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible: tab.badged && githubHasFailures,
                            child: Icon(tab.icon, fill: 1),
                          ),
                          label: tab.labelKey.tr(),
                        ),
                      NavigationDestination(
                        icon: const Icon(Symbols.settings),
                        selectedIcon: const Icon(Symbols.settings, fill: 1),
                        label: 'tabSettings'.tr(),
                      ),
                    ],
                  ).padding(horizontal: 16),
                ),
        );
      },
    );
  }
}

/// The desktop navigation rail: destinations can be dragged into a custom
/// order, which is persisted; settings stays pinned at the bottom.
class _ReorderableNavRail extends StatelessWidget {
  const _ReorderableNavRail({
    required this.order,
    required this.activeIndex,
    required this.githubHasFailures,
    required this.onSelected,
    required this.onReorder,
  });

  final List<int> order;
  final int activeIndex;
  final bool githubHasFailures;
  final ValueChanged<int> onSelected;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            // Dragging a destination must reorder, never start a text
            // selection from the app-wide SelectionArea.
            child: SelectionContainer.disabled(
              child: ReorderableListView(
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) =>
                    Material(color: Colors.transparent, child: child),
                onReorderItem: (from, to) {
                  if (to != from) onReorder(from, to);
                },
                children: [
                  for (final (position, routeIndex) in order.indexed)
                    ReorderableDragStartListener(
                      key: ValueKey(routeIndex),
                      index: position,
                      child: _RailDestination(
                        tab: WorkspaceTab.values[routeIndex],
                        selected: activeIndex == routeIndex,
                        showBadge:
                            WorkspaceTab.values[routeIndex].badged &&
                            githubHasFailures,
                        onTap: () => onSelected(routeIndex),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'tabSettings'.tr(),
                  onPressed: () => onSelected(WorkspaceTab.settings.index),
                  icon: Icon(
                    Symbols.settings,
                    fill: activeIndex == WorkspaceTab.settings.index ? 1 : 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.tab,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  final WorkspaceTab tab;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(
      tab.icon,
      fill: selected ? 1 : 0,
      color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 32,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: selected ? scheme.secondaryContainer : null,
              ),
              child: Badge(isLabelVisible: showBadge, child: icon),
            ),
            const SizedBox(height: 4),
            Text(
              tab.labelKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
