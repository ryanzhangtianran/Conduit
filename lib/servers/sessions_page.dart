import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/formatters.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'server_connection_actions.dart';
import 'terminal_command_palette.dart';
import 'file_editor_tab.dart';
import 'file_management_tab.dart';
import 'server_address_label.dart';
import 'server_reorder.dart';
import 'server_workspace_page.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'terminal_find_host.dart';
import 'terminal_session_adapter.dart';
import 'terminal_tabs_provider.dart';

/// The terminal workspace as a top-level sidebar page: live terminal,
/// file-management and editor sessions listed in a left rail.
@RoutePage()
class TerminalPage extends StatelessWidget {
  const TerminalPage({super.key});

  @override
  Widget build(BuildContext context) => const SessionsWorkspace();
}

/// Unified server workspace: a fixed left rail lists every open session plus
/// a home entry back to the server grid; the content pane keeps all sessions
/// mounted so switching never resets terminal state.
class SessionsWorkspace extends ConsumerWidget {
  const SessionsWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(terminalTabsProvider);
    final sessions = ref.watch(sessionsProvider);
    final servers = ref.watch(serversProvider);
    // No selection (including "no tabs") shows the server grid while any
    // open sessions keep running in the background.
    final selectedTab = tabs.selectedTab;
    final showHome = selectedTab == null;
    final focusedTerminal = selectedTab is TerminalTab ? selectedTab : null;
    final focusedSession = _sessionForTab(sessions, selectedTab);

    return ConduitAppScaffold(
      topSafeArea: false,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              top: true,
              bottom: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SessionSidebar(
                    tabs: tabs,
                    homeSelected: showHome,
                    onShowHome: () =>
                        ref.read(terminalTabsProvider.notifier).selectHome(),
                    onSelectTab: (tab) =>
                        ref.read(terminalTabsProvider.notifier).select(tab.id),
                    onCloseTab: (tab) =>
                        ref.read(terminalTabsProvider.notifier).close(tab.id),
                    onNewSession: () =>
                        showTerminalCommandPalette(context, ref),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        for (final tab in tabs.tabs)
                          _AnimatedPaneTabContent(
                            key: ValueKey(tab.id),
                            active: tab.id == selectedTab?.id,
                            child: _SessionTabBody(
                              tab: tab,
                              autofocus: tab.id == selectedTab?.id,
                            ),
                          ),
                        if (showHome)
                          ColoredBox(
                            color: Theme.of(context).colorScheme.surface,
                            child: _SessionIntro(
                              servers: servers,
                              tabs: tabs,
                              onOpenTerminal: (server) =>
                                  openTerminalSession(context, ref, server),
                              onOpenFiles: (server) =>
                                  openFileManagementFor(context, ref, server),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _AnimatedTerminalStatusBar(
            session: focusedSession,
            terminal: focusedTerminal?.terminal,
            terminalId: focusedTerminal?.id,
          ),
        ],
      ),
    );
  }
}

/// Fixed-width session list: a home entry back to the server grid plus one
/// row per open session.
class _SessionSidebar extends StatelessWidget {
  const _SessionSidebar({
    required this.tabs,
    required this.homeSelected,
    required this.onShowHome,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onNewSession,
  });

  final TerminalTabsState tabs;
  final bool homeSelected;
  final VoidCallback onShowHome;
  final ValueChanged<SessionTab> onSelectTab;
  final ValueChanged<SessionTab> onCloseTab;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedId = tabs.selectedTab?.id;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: 232,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'tabTerminal'.tr(),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'sessionsSessionActions'.tr(),
                    visualDensity: VisualDensity.compact,
                    onPressed: onNewSession,
                    icon: const Icon(Symbols.add, size: 20),
                  ),
                ],
              ),
            ),
            _SidebarEntry(
              icon: Symbols.grid_view,
              label: 'sessionsHome'.tr(),
              selected: homeSelected,
              onTap: onShowHome,
            ),
            const Divider(height: 17, indent: 12, endIndent: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final tab in tabs.tabs)
                    _SidebarEntry(
                      key: ValueKey(tab.id),
                      leading: _TabActivityIcon(
                        tab: tab,
                        color: !homeSelected && tab.id == selectedId
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      label: _tabLabel(tab),
                      selected: !homeSelected && tab.id == selectedId,
                      onTap: () => onSelectTab(tab),
                      onClose: () => onCloseTab(tab),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarEntry extends StatelessWidget {
  const _SidebarEntry({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClose,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Listener(
          onPointerDown: onClose == null
              ? null
              : (event) {
                  if (event.buttons & kMiddleMouseButton != 0) onClose!();
                },
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: Row(
                  children: [
                    leading ?? Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected ? scheme.onSecondaryContainer : null,
                        ),
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: 'sessionsCloseTab'.tr(),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        onPressed: onClose,
                        icon: Icon(Symbols.close, size: 15, color: foreground),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

SshSessionInfo? _sessionForTab(
  AsyncValue<List<SshSessionInfo>> sessions,
  SessionTab? tab,
) {
  if (tab == null) return null;
  return sessions.asData?.value
      .where((item) => item.serverId == tab.serverId)
      .firstOrNull;
}

Future<void> _openFilesForTerminal(
  BuildContext context,
  WidgetRef ref,
  TerminalTab tab,
) async {
  final server = ref
      .read(serversProvider)
      .asData
      ?.value
      .where((item) => item.id == tab.serverId)
      .firstOrNull;
  if (server == null || !context.mounted) return;
  await openFileManagementFor(
    context,
    ref,
    server,
    initialPath: tab.terminal.currentDirectory,
  );
}

class _TabActivityIcon extends StatelessWidget {
  const _TabActivityIcon({required this.tab, this.color});

  final SessionTab tab;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (tab case TerminalTab(:final terminal)) {
      return StreamBuilder<TerminalTaskActivity>(
        stream: terminal.taskActivity,
        initialData: terminal.currentTaskActivity,
        builder: (context, snapshot) {
          final activity = snapshot.data!;
          if (activity.running) {
            return SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: activity.progress,
                strokeWidth: 2,
                color: color,
              ),
            );
          }
          return Icon(Symbols.terminal, size: 16, color: color);
        },
      );
    }
    return Icon(_tabIcon(tab), size: 16, color: color);
  }
}

/// Keeps inactive views mounted while animating the visible pane tab in and
/// the previous tab out, so terminal and file-management state is retained.
class _AnimatedPaneTabContent extends StatelessWidget {
  const _AnimatedPaneTabContent({
    required this.active,
    required this.child,
    super.key,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !active,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      opacity: active ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: active ? Offset.zero : const Offset(0.02, 0),
        child: child,
      ),
    ),
  );
}

class _SessionTabBody extends ConsumerWidget {
  const _SessionTabBody({required this.tab, required this.autofocus});

  final SessionTab tab;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = sessionTabViewKey(tab.id);
    if (tab is FileManagementTab) {
      return FileManagementTabView(key: key, tab: tab as FileManagementTab);
    }
    if (tab is FileEditorTab) {
      return FileEditorTabView(key: key, tab: tab as FileEditorTab);
    }
    final terminalTab = tab as TerminalTab;
    // The surround matches the terminal palette so the padding around the
    // grid is invisible in both light and dark schemes.
    return ColoredBox(
      color: ref.watch(terminalColorSchemeProvider).background,
      child: ClipRect(
        child: TerminalFindHost(
          key: key,
          adapter: terminalTab.terminal,
          autofocus: autofocus,
          onOpenFileManagement: () =>
              unawaited(_openFilesForTerminal(context, ref, terminalTab)),
        ),
      ),
    );
  }
}

IconData _tabIcon(SessionTab tab) => switch (tab.type) {
  SessionTabType.terminal => Symbols.terminal,
  SessionTabType.fileManagement => Symbols.folder,
  SessionTabType.fileEditor => Symbols.edit_document,
};
String _tabLabel(SessionTab tab) {
  if (tab is FileEditorTab) {
    return tab.isRemote ? '${tab.fileName} · ${tab.serverName}' : tab.fileName;
  }
  if (tab is FileManagementTab) {
    return 'tabFiles'.tr(args: [tab.serverName]);
  }
  return tab.serverName;
}

class _AnimatedTerminalStatusBar extends StatelessWidget {
  const _AnimatedTerminalStatusBar({
    required this.session,
    required this.terminal,
    required this.terminalId,
  });

  final SshSessionInfo? session;
  final TerminalSessionAdapter? terminal;
  final String? terminalId;

  @override
  Widget build(BuildContext context) {
    final activeTerminal = terminal;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
      transitionBuilder: (child, animation) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return ClipRect(
          child: SizeTransition(
            sizeFactor: curve,
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(opacity: curve, child: child),
            ),
          ),
        );
      },
      child: activeTerminal == null
          ? const SizedBox.shrink(key: ValueKey('no-session'))
          : _TerminalStatusBar(
              key: ValueKey(activeTerminal),
              session: session,
              terminal: activeTerminal,
              terminalId: terminalId!,
            ),
    );
  }
}

class _TerminalStatusBar extends ConsumerStatefulWidget {
  const _TerminalStatusBar({
    required this.session,
    required this.terminal,
    required this.terminalId,
    super.key,
  });

  final SshSessionInfo? session;
  final TerminalSessionAdapter terminal;
  final String terminalId;

  @override
  ConsumerState<_TerminalStatusBar> createState() => _TerminalStatusBarState();
}

class _TerminalStatusBarState extends ConsumerState<_TerminalStatusBar> {
  static const _pingInterval = Duration(seconds: 5);

  Timer? _pingTimer;
  Duration? _latency;
  var _measuringLatency = false;

  @override
  void initState() {
    super.initState();
    _measureLatency();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _measureLatency());
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _measureLatency() async {
    if (_measuringLatency) return;
    _measuringLatency = true;
    try {
      final latency = await ref
          .read(connectionManagerProvider)
          .measureTerminalLatency(widget.terminalId);
      if (mounted) setState(() => _latency = latency);
    } finally {
      _measuringLatency = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final stats = widget.session?.stats;
    final memoryTotalKb = stats?.memoryTotalKb;
    final memoryAvailableKb = stats?.memoryAvailableKb;
    final usedMemoryKb = memoryTotalKb == null || memoryAvailableKb == null
        ? null
        : memoryTotalKb - memoryAvailableKb;
    final memoryRatio =
        usedMemoryKb == null || memoryTotalKb == null || memoryTotalKb == 0
        ? null
        : (usedMemoryKb / memoryTotalKb).clamp(0.0, 1.0);
    final systemLabel = [
      widget.session?.systemInfo?.distribution,
      widget.session?.systemInfo?.kernel,
    ].whereType<String>().join(' · ');

    final segments = <Widget>[
      if (widget.session case final activeSession?)
        _StatusBarIdentity(session: activeSession),
      if (_latency case final latency?)
        _StatusBarMetric(
          icon: Symbols.network_ping,
          tooltip: 'terminalSshPing'.tr(),
          value: '${latency.inMilliseconds} ms',
          valueColor: _statusBarPingColor(latency, scheme),
          mutedStyle: mutedStyle,
          valueStyle: valueStyle,
        ),
      if (stats?.loadAverage case final load?)
        _StatusBarMetric(
          icon: Symbols.speed,
          tooltip: 'detailLoadAverage'.tr(),
          value: load.toStringAsFixed(2),
          valueColor: _statusBarLoadColor(load, scheme),
          mutedStyle: mutedStyle,
          valueStyle: valueStyle,
        ),
      if (usedMemoryKb != null && memoryTotalKb != null)
        _StatusBarMetric(
          icon: Symbols.memory_alt,
          tooltip: 'detailMemory'.tr(),
          value: _formatMemory(usedMemoryKb, memoryTotalKb),
          valueColor: _statusBarMemoryColor(memoryRatio, scheme),
          mutedStyle: mutedStyle,
          valueStyle: valueStyle,
        ),
      if (stats?.uptime case final uptime?)
        _StatusBarMetric(
          icon: Symbols.schedule,
          tooltip: 'detailUptime'.tr(),
          value: formatUptime(uptime),
          mutedStyle: mutedStyle,
          valueStyle: valueStyle,
        ),
      if (systemLabel.isNotEmpty)
        Tooltip(
          message: systemLabel,
          waitDuration: const Duration(milliseconds: 400),
          child: Text(systemLabel, style: mutedStyle),
        ),
    ];

    return Material(
      color: scheme.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android)
                _TerminalQuickKeys(terminal: widget.terminal),
              if (segments.isNotEmpty)
                SizedBox(
                  height: 28,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: segments.length,
                    separatorBuilder: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: Container(
                          width: 1,
                          height: 12,
                          color: scheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    itemBuilder: (context, index) =>
                        Center(child: segments[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalQuickKeys extends StatefulWidget {
  const _TerminalQuickKeys({required this.terminal});

  final TerminalSessionAdapter terminal;

  @override
  State<_TerminalQuickKeys> createState() => _TerminalQuickKeysState();
}

class _TerminalQuickKeysState extends State<_TerminalQuickKeys> {
  static const _commonKeys = [
    ('Ctrl+C', '\u0003'),
    ('Ctrl+D', '\u0004'),
    ('Ctrl+L', '\u000c'),
    ('Tab', '\t'),
    ('Esc', '\u001b'),
    ('↑', '\u001b[A'),
    ('↓', '\u001b[B'),
    ('←', '\u001b[D'),
    ('→', '\u001b[C'),
    ('Enter', '\r'),
  ];

  static const _extraKeys = [
    ('Ctrl+Z', '\u001a'),
    ('Ctrl+A', '\u0001'),
    ('Ctrl+E', '\u0005'),
    ('Ctrl+U', '\u0015'),
    ('PgUp', '\u001b[5~'),
    ('PgDn', '\u001b[6~'),
  ];

  static const _allKeys = [..._commonKeys, ..._extraKeys];

  final _scrollController = ScrollController();
  var _expanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle() {
    final expanded = !_expanded;
    setState(() => _expanded = expanded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(
        expanded ? _scrollController.position.maxScrollExtent : 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final terminal = widget.terminal;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final keys = _expanded ? _allKeys : _commonKeys;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: ListView.separated(
                key: ValueKey(_expanded),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                scrollDirection: Axis.horizontal,
                itemCount: keys.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final (label, input) = keys[index];
                  return TextButton(
                    onPressed: () => terminal.sendInput(input),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(label),
                  );
                },
              ),
            ),
          ),
          IconButton(
            tooltip: keyboardVisible
                ? 'terminalKeyboardHide'.tr()
                : 'terminalKeyboardShow'.tr(),
            onPressed: keyboardVisible
                ? terminal.hideKeyboard
                : terminal.showKeyboard,
            icon: Icon(
              keyboardVisible
                  ? Symbols.keyboard_arrow_down
                  : Symbols.keyboard_arrow_up,
            ),
          ),
          IconButton(
            tooltip: _expanded
                ? 'terminalKeysFewer'.tr()
                : 'terminalKeysMore'.tr(),
            onPressed: _toggle,
            icon: Icon(_expanded ? Symbols.expand_less : Symbols.expand_more),
          ),
        ],
      ),
    );
  }
}

class _StatusBarIdentity extends StatelessWidget {
  const _StatusBarIdentity({required this.session});

  final SshSessionInfo session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (label, color) = switch (session.status) {
      SessionStatus.connected => ('commonConnected'.tr(), scheme.primary),
      SessionStatus.connecting => ('commonConnecting'.tr(), scheme.tertiary),
      SessionStatus.failed => ('commonFailed'.tr(), scheme.error),
      SessionStatus.closed => (
        'commonNotConnected'.tr(),
        scheme.onSurfaceVariant,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        const SizedBox(width: 8),
        Text(
          session.serverName,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusBarMetric extends StatelessWidget {
  const _StatusBarMetric({
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.mutedStyle,
    required this.valueStyle,
    this.valueColor,
  });

  final IconData icon;
  final String tooltip;
  final String value;
  final TextStyle? mutedStyle;
  final TextStyle? valueStyle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            value,
            style: (valueStyle ?? mutedStyle)?.copyWith(
              color: valueColor ?? valueStyle?.color ?? mutedStyle?.color,
            ),
          ),
        ],
      ),
    );
  }
}

Color? _statusBarLoadColor(double? load, ColorScheme scheme) {
  if (load == null) return null;
  if (load >= 4) return scheme.error;
  if (load >= 2) return scheme.tertiary;
  return null;
}

Color? _statusBarMemoryColor(double? ratio, ColorScheme scheme) {
  if (ratio == null) return null;
  if (ratio >= 0.9) return scheme.error;
  if (ratio >= 0.75) return scheme.tertiary;
  return null;
}

Color? _statusBarPingColor(Duration latency, ColorScheme scheme) {
  if (latency >= const Duration(milliseconds: 250)) return scheme.error;
  if (latency >= const Duration(milliseconds: 100)) return scheme.tertiary;
  return null;
}

String _formatMemory(int usedKb, int totalKb) =>
    '${(usedKb / 1024 / 1024).toStringAsFixed(1)} / ${(totalKb / 1024 / 1024).toStringAsFixed(1)} GB';

/// Home view of the terminal workspace: a server grid for opening sessions.
class _SessionIntro extends StatelessWidget {
  const _SessionIntro({
    required this.servers,
    required this.tabs,
    required this.onOpenTerminal,
    required this.onOpenFiles,
  });

  final AsyncValue<List<Server>> servers;
  final TerminalTabsState tabs;
  final Future<void> Function(Server server) onOpenTerminal;
  final Future<void> Function(Server server) onOpenFiles;

  @override
  Widget build(BuildContext context) => servers.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) =>
        Center(child: Text('serversLoadError'.tr(args: [error.toString()]))),
    data: (servers) => servers.isEmpty
        ? Center(
            child: FilledButton.icon(
              onPressed: () => AutoTabsRouter.of(
                context,
              ).setActiveIndex(WorkspaceTab.dashboard.index),
              icon: const Icon(Symbols.add),
              label: Text('serversAddServer'.tr()),
            ),
          )
        : _TerminalServerGrid(
            servers: servers,
            tabs: tabs,
            onOpenTerminal: onOpenTerminal,
            onOpenFiles: onOpenFiles,
          ),
  );
}

class _TerminalServerGrid extends ConsumerWidget {
  const _TerminalServerGrid({
    required this.servers,
    required this.tabs,
    required this.onOpenTerminal,
    required this.onOpenFiles,
  });

  final List<Server> servers;
  final TerminalTabsState tabs;
  final Future<void> Function(Server server) onOpenTerminal;
  final Future<void> Function(Server server) onOpenFiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableServerGrid(
      servers: servers,
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (context, server) {
        final openCount = tabs.tabs
            .where((tab) => tab.serverId == server.id)
            .length;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Symbols.terminal, size: 22),
                    const Spacer(),
                    const ServerDragHandle(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  server.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  serverAddressLabel(server),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                _ServerCardActions(
                  openCount: openCount,
                  onOpenTerminal: () => onOpenTerminal(server),
                  onOpenFiles: () => onOpenFiles(server),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Action row that collapses to icon buttons when the card is narrow.
class _ServerCardActions extends StatelessWidget {
  const _ServerCardActions({
    required this.openCount,
    required this.onOpenTerminal,
    required this.onOpenFiles,
  });

  final int openCount;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenFiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Split panes often leave cards under ~260px — use icon-only actions.
        final narrow = constraints.maxWidth < 260;
        if (narrow) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  'sessionsOpenCount'.tr(args: ['$openCount']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'sessionsNewTerminal'.tr(),
                visualDensity: VisualDensity.compact,
                onPressed: onOpenTerminal,
                icon: const Icon(Symbols.add, size: 20),
              ),
              IconButton(
                tooltip: 'sessionsOpenFileManagement'.tr(),
                visualDensity: VisualDensity.compact,
                onPressed: onOpenFiles,
                icon: const Icon(Symbols.folder, size: 20),
              ),
            ],
          );
        }
        return Row(
          children: [
            Text(
              'sessionsOpenCount'.tr(args: ['$openCount']),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: onOpenTerminal,
              icon: const Icon(Symbols.add),
              label: Text('sessionsNewTerminal'.tr()),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'sessionsOpenFileManagement'.tr(),
              onPressed: onOpenFiles,
              icon: const Icon(Symbols.folder),
            ),
          ],
        );
      },
    );
  }
}
