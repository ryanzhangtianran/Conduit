import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/routing/app_router.gr.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';

/// The settings categories, one nested route each, in rail/tab order.
enum SettingsCategory {
  terminal('settingsTerminal', Symbols.terminal),
  connections('settingsConnections', Symbols.lan),
  sync('settingsSync', Symbols.sync),
  security('settingsSecurity', Symbols.lock),
  about('settingsAbout', Symbols.info);

  const SettingsCategory(this.titleKey, this.icon);

  final String titleKey;
  final IconData icon;

  PageRouteInfo get route => switch (this) {
    terminal => const TerminalSettingsRoute(),
    connections => const ConnectionsSettingsRoute(),
    sync => const SyncSettingsRoute(),
    security => const SecuritySettingsRoute(),
    about => const AboutSettingsRoute(),
  };
}

/// The settings shell: a category rail on wide layouts, tabs on narrow
/// ones, with each category's content on its own nested route.
@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConduitAppScaffold(
      body: AutoTabsRouter.tabBar(
        routes: [
          for (final category in SettingsCategory.values) category.route,
        ],
        physics: const NeverScrollableScrollPhysics(),
        builder: (context, child, controller) => LayoutBuilder(
          builder: (context, constraints) {
            final tabsRouter = AutoTabsRouter.of(context);
            if (constraints.maxWidth > 768) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 232,
                    child: _SettingsCategoryRail(
                      selectedIndex: tabsRouter.activeIndex,
                      onSelected: tabsRouter.setActiveIndex,
                    ),
                  ),
                  Expanded(child: child),
                ],
              );
            }
            return Column(
              children: [
                _SettingsCategoryTabs(
                  selectedIndex: tabsRouter.activeIndex,
                  onSelected: tabsRouter.setActiveIndex,
                ),
                Expanded(child: child),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsCategoryRail extends StatelessWidget {
  const _SettingsCategoryRail({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          for (final category in SettingsCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                selected: category.index == selectedIndex,
                selectedTileColor: scheme.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(
                  category.icon,
                  color: category.index == selectedIndex
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                title: Text(category.titleKey).tr(),
                visualDensity: VisualDensity.compact,
                onTap: () => onSelected(category.index),
              ),
            ),
        ],
      ),
    );
  }
}

/// The narrow-layout category strip. The tab controller mirrors the tab
/// router's active index so the indicator follows navigation from anywhere.
class _SettingsCategoryTabs extends StatefulWidget {
  const _SettingsCategoryTabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_SettingsCategoryTabs> createState() => _SettingsCategoryTabsState();
}

class _SettingsCategoryTabsState extends State<_SettingsCategoryTabs>
    with SingleTickerProviderStateMixin {
  late final _controller = TabController(
    length: SettingsCategory.values.length,
    vsync: this,
    initialIndex: widget.selectedIndex,
  );

  @override
  void didUpdateWidget(covariant _SettingsCategoryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _controller.index) {
      _controller.index = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: scheme.outlineVariant.withValues(alpha: 0.7),
          dividerHeight: 1,
          indicatorColor: scheme.primary,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          onTap: widget.onSelected,
          tabs: [
            for (final category in SettingsCategory.values)
              Tab(
                icon: Icon(category.icon, size: 18),
                text: category.titleKey.tr(),
              ),
          ],
        ),
      ),
    );
  }
}
