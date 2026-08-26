import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/routing/app_router.dart';
import 'package:conduit/routing/app_router.gr.dart';
import 'package:conduit/servers/port_forwarding_models.dart';
import 'package:conduit/servers/server_connection_actions.dart';
import 'package:conduit/servers/server_editor_dialog.dart';
import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/servers/terminal_tabs_provider.dart';
import 'shared/services/app_tray.dart';

/// The live [AppTrayController], so other parts of the app (the updater)
/// can quit through the same clean shutdown as the menu bar's Quit. Null
/// until the app registers it and on platforms without a menu bar item.
final appTrayControllerProvider =
    NotifierProvider<AppTrayControllerNotifier, AppTrayController?>(
      AppTrayControllerNotifier.new,
    );

class AppTrayControllerNotifier extends Notifier<AppTrayController?> {
  @override
  AppTrayController? build() => null;

  void register(AppTrayController? controller) => state = controller;
}

/// Owns the menu bar item for the app's lifetime: keeps its menu in step
/// with the saved servers, sessions and forwards, and carries out the
/// actions picked from it (connect, open a terminal, toggle a forward, add
/// a server, show the window, quit).
///
/// Closing the window only hides it; everything keeps running until the
/// app is quit from here or with ⌘Q.
class AppTrayController with WindowListener {
  AppTrayController(this._ref);

  final WidgetRef _ref;
  AppTray? _tray;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  Future<void> init() async {
    windowManager.addListener(this);
    final tray = _tray = AppTray(
      onShowWindow: showWindow,
      onQuit: quit,
      onOpenTerminal: _openTerminal,
      onToggleForward: _toggleForward,
      onToggleConnection: _toggleConnection,
      onNewConnection: _newConnection,
      onNewForward: _newForward,
    );
    await tray.init();
    // Any change to servers, sessions, or forwards refreshes the menu.
    for (final provider in [
      serversProvider,
      sessionsProvider,
      portForwardsProvider,
      allPortForwardConfigsProvider,
    ]) {
      _subscriptions.add(
        _ref.listenManual(
          provider,
          (_, _) => _refresh(),
          fireImmediately: true,
        ),
      );
    }
  }

  Future<void> dispose() async {
    windowManager.removeListener(this);
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    await _tray?.dispose();
    _tray = null;
  }

  /// Closing the window only hides it; everything keeps running.
  @override
  void onWindowClose() => windowManager.hide();

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Closes every terminal and shuts the SSH sessions (and their forwards)
  /// down cleanly before the process exits.
  Future<void> quit() async {
    await dispose();
    await _ref.read(terminalTabsProvider.notifier).closeAll();
    _ref.read(portForwardSupervisorProvider).dispose();
    await _ref.read(connectionManagerProvider).dispose();
    exit(0);
  }

  List<Server> get _servers =>
      _ref.read(serversProvider).asData?.value ?? const [];

  Server? _server(int id) => _servers.where((s) => s.id == id).firstOrNull;

  void _refresh() {
    final tray = _tray;
    if (tray == null) return;
    final sessions = _ref.read(sessionsProvider).asData?.value ?? const [];
    final connectedIds = {
      for (final s in sessions)
        if (s.status == SessionStatus.connected) s.serverId,
    };
    final forwards = _ref.read(portForwardsProvider).asData?.value ?? const [];
    final configs =
        _ref.read(allPortForwardConfigsProvider).asData?.value ?? const [];
    final names = {for (final s in _servers) s.id: s.name};
    tray.update(
      connections: connectedIds.length,
      activeForwards: forwards.length,
      servers: [
        for (final s in _servers)
          (id: s.id, name: s.name, connected: connectedIds.contains(s.id)),
      ],
      forwards: [
        for (final c in configs)
          (
            configId: c.id,
            label: '${names[c.serverId] ?? '?'} · ${_forwardSummary(c)}',
            running: forwards.any((f) => _matches(f, c)),
          ),
      ],
    );
  }

  static String _forwardSummary(PortForwardConfig c) =>
      c.kind == PortForwardKind.socks5.name
      ? 'socks5://${c.bindHost}:${c.bindPort}'
      : '${c.bindPort} → ${c.targetPort}';

  static bool _matches(ActivePortForward f, PortForwardConfig c) =>
      f.serverId == c.serverId &&
      f.kind.name == c.kind &&
      f.bindHost == c.bindHost &&
      f.bindPort == c.bindPort;

  Future<void> _openTerminal(int serverId) async {
    final server = _server(serverId);
    if (server == null) return;
    await showWindow();
    await _ref.read(appRouterProvider).navigate(const TerminalRoute());
    final context = conduitNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await openTerminalSession(context, _ref, server);
  }

  Future<void> _toggleConnection(int serverId) async {
    final server = _server(serverId);
    if (server == null) return;
    final manager = _ref.read(connectionManagerProvider);
    if (manager.clientFor(serverId) != null) {
      await manager.disconnect(serverId);
      return;
    }
    // Silent from the menu bar: the window only appears if an unknown host
    // key needs approval.
    final context = conduitNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await connectForStatistics(
      context,
      _ref,
      server,
      onHostKeyPrompt: showWindow,
    );
  }

  Future<void> _newConnection() async {
    await showWindow();
    await _ref.read(appRouterProvider).navigate(ConnectionsTab());
    final context = conduitNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showServerEditor(context, _ref);
  }

  Future<void> _newForward() async {
    await showWindow();
    await _ref.read(appRouterProvider).navigate(const PortForwardingRoute());
  }

  Future<void> _toggleForward(int configId) async {
    final config =
        (_ref.read(allPortForwardConfigsProvider).asData?.value ??
                const <PortForwardConfig>[])
            .where((c) => c.id == configId)
            .firstOrNull;
    if (config == null) return;
    final manager = _ref.read(connectionManagerProvider);
    final running =
        (_ref.read(portForwardsProvider).asData?.value ??
                const <ActivePortForward>[])
            .where((f) => _matches(f, config))
            .firstOrNull;
    if (running != null) {
      await manager.stopPortForward(running.id);
      return;
    }
    final server = _server(config.serverId);
    if (server == null) return;
    if (manager.clientFor(server.id) == null) {
      // Silent from the menu bar: the window only appears if an unknown
      // host key needs approval.
      final context = conduitNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final connected = await connectForStatistics(
        context,
        _ref,
        server,
        onHostKeyPrompt: showWindow,
      );
      if (!connected) return;
    }
    try {
      await manager.startPortForward(
        server: server,
        direction: PortForwardDirection.values.byName(config.direction),
        kind: PortForwardKind.values.byName(config.kind),
        bindHost: config.bindHost,
        bindPort: config.bindPort,
        targetHost: config.targetHost,
        targetPort: config.targetPort,
      );
    } catch (_) {
      // Surfaced in the forward manager table; the tray stays quiet.
    }
  }
}
