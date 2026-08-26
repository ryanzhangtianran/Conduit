import 'package:easy_localization/easy_localization.dart';
import 'package:tray_manager/tray_manager.dart';

/// A saved SSH server as listed under the tray's "new terminal" submenu.
typedef TrayServer = ({int id, String name, bool connected});

/// A saved forward preset as listed under the tray's "forwards" submenu.
typedef TrayForward = ({int configId, String label, bool running});

/// The menu bar (status bar) item shown while Conduit runs. Left click brings
/// the window back; right click opens a menu with the live counts, a "new
/// terminal" submenu per server, a forwards submenu that starts and stops
/// presets, show, and quit.
class AppTray with TrayListener {
  AppTray({
    required this.onShowWindow,
    required this.onQuit,
    required this.onOpenTerminal,
    required this.onToggleForward,
    required this.onToggleConnection,
    required this.onNewConnection,
    required this.onNewForward,
  });

  final Future<void> Function() onShowWindow;
  final Future<void> Function() onQuit;
  final Future<void> Function(int serverId) onOpenTerminal;
  final Future<void> Function(int configId) onToggleForward;
  final Future<void> Function(int serverId) onToggleConnection;
  final Future<void> Function() onNewConnection;
  final Future<void> Function() onNewForward;

  static const _terminalPrefix = 'terminal:';
  static const _forwardPrefix = 'forward:';
  static const _connectionPrefix = 'connection:';

  var _connections = 0;
  var _activeForwards = 0;
  var _servers = const <TrayServer>[];
  var _forwards = const <TrayForward>[];

  Future<void> init() async {
    await trayManager.setIcon('assets/icons/tray_icon.png', isTemplate: true);
    await trayManager.setToolTip('Conduit');
    trayManager.addListener(this);
    await _rebuildMenu();
  }

  Future<void> update({
    int? connections,
    int? activeForwards,
    List<TrayServer>? servers,
    List<TrayForward>? forwards,
  }) async {
    _connections = connections ?? _connections;
    _activeForwards = activeForwards ?? _activeForwards;
    _servers = servers ?? _servers;
    _forwards = forwards ?? _forwards;
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() => trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(
          key: 'status',
          label: 'trayStatus'.tr(args: ['$_connections', '$_activeForwards']),
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem.submenu(
          key: 'connections',
          label: 'trayConnections'.tr(),
          submenu: Menu(
            items: [
              for (final server in _servers)
                MenuItem(
                  key: '$_connectionPrefix${server.id}',
                  label: server.name,
                  icon: _light(server.connected),
                ),
              if (_servers.isNotEmpty) MenuItem.separator(),
              MenuItem(key: 'newConnection', label: 'trayNewConnection'.tr()),
            ],
          ),
        ),
        MenuItem.submenu(
          key: 'terminals',
          label: 'trayTerminal'.tr(),
          disabled: _servers.isEmpty,
          submenu: Menu(
            items: [
              for (final server in _servers)
                MenuItem(
                  key: '$_terminalPrefix${server.id}',
                  label: server.name,
                  icon: _light(server.connected),
                ),
            ],
          ),
        ),
        MenuItem.submenu(
          key: 'forwards',
          label: 'trayForwards'.tr(),
          submenu: Menu(
            items: [
              for (final forward in _forwards)
                MenuItem(
                  key: '$_forwardPrefix${forward.configId}',
                  label: forward.label,
                  icon: _light(forward.running),
                ),
              if (_forwards.isNotEmpty) MenuItem.separator(),
              MenuItem(key: 'newForward', label: 'trayNewForward'.tr()),
            ],
          ),
        ),
        MenuItem.separator(),
        MenuItem(key: 'show', label: 'trayShow'.tr()),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'trayQuit'.tr()),
      ],
    ),
  );

  /// Small bright status dot rendered as the item's native icon.
  static String _light(bool on) =>
      on ? 'assets/icons/tray_dot_green.png' : 'assets/icons/tray_dot_red.png';

  @override
  void onTrayIconMouseDown() => onShowWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key ?? '';
    if (key.startsWith(_terminalPrefix)) {
      final id = int.tryParse(key.substring(_terminalPrefix.length));
      if (id != null) onOpenTerminal(id);
      return;
    }
    if (key.startsWith(_forwardPrefix)) {
      final id = int.tryParse(key.substring(_forwardPrefix.length));
      if (id != null) onToggleForward(id);
      return;
    }
    if (key.startsWith(_connectionPrefix)) {
      final id = int.tryParse(key.substring(_connectionPrefix.length));
      if (id != null) onToggleConnection(id);
      return;
    }
    switch (key) {
      case 'newConnection':
        onNewConnection();
      case 'newForward':
        onNewForward();
      case 'show':
        onShowWindow();
      case 'quit':
        onQuit();
    }
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
