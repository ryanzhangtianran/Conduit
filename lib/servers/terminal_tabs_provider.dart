import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/data/local/app_database.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'ssh_connection_manager.dart';
import 'terminal_session_adapter.dart';

/// Stable keys so session tab views keep their [State] while the workspace
/// rebuilds around them.
final Map<String, GlobalKey> _sessionTabViewKeys = {};

/// Global key for the interactive body of [tabId] (terminal or file transfer).
GlobalKey sessionTabViewKey(String tabId) => _sessionTabViewKeys.putIfAbsent(
  tabId,
  () => GlobalKey(debugLabel: 'session-tab-$tabId'),
);

void _releaseSessionTabViewKey(String tabId) {
  _sessionTabViewKeys.remove(tabId);
}

enum SessionTabType { terminal, fileManagement, fileEditor }

sealed class SessionTab {
  const SessionTab({
    required this.id,
    required this.serverId,
    required this.serverName,
  });

  final String id;
  final int serverId;
  final String serverName;
  SessionTabType get type;
}

class TerminalTab extends SessionTab {
  const TerminalTab({
    required super.id,
    required super.serverId,
    required super.serverName,
    required this.terminal,
  });

  final TerminalSessionAdapter terminal;

  @override
  SessionTabType get type => SessionTabType.terminal;
}

class FileManagementTab extends SessionTab {
  const FileManagementTab({
    required super.id,
    required super.serverId,
    required super.serverName,
    this.initialPath,
  });

  /// Remote directory to show on first load (e.g. a linked project folder).
  final String? initialPath;

  @override
  SessionTabType get type => SessionTabType.fileManagement;
}

/// In-pane text editor for a local or remote file.
class FileEditorTab extends SessionTab {
  const FileEditorTab({
    required super.id,
    required super.serverId,
    required super.serverName,
    required this.fileName,
    required this.path,
    required this.isRemote,
  });

  final String fileName;
  final String path;
  final bool isRemote;

  @override
  SessionTabType get type => SessionTabType.fileEditor;
}

class TerminalTabsState {
  const TerminalTabsState({this.tabs = const [], this.selectedId});

  final List<SessionTab> tabs;

  /// Id of the tab shown in the workspace (drives status bar, palette, etc.).
  /// Null shows the workspace home while any open tabs keep running.
  final String? selectedId;

  SessionTab? get selectedTab =>
      selectedId == null ? null : _tabById(selectedId!);

  bool get isEmpty => tabs.isEmpty;
  bool get isNotEmpty => tabs.isNotEmpty;

  SessionTab? _tabById(String id) =>
      tabs.where((tab) => tab.id == id).firstOrNull;
}

final terminalTabsProvider =
    NotifierProvider<TerminalTabsNotifier, TerminalTabsState>(
      TerminalTabsNotifier.new,
    );

/// Holds live terminal tabs for the entire app lifetime.
///
/// This provider deliberately is not auto-disposed, so terminals continue to
/// receive output while the user visits another workspace page.
///
/// Each terminal tab owns an emulator adapter bound to a transport-only
/// shell handle from [SshConnectionManager]. Tearing a terminal down always
/// removes the tab from state first so its view unmounts before the adapter
/// releases the native terminal.
class TerminalTabsNotifier extends Notifier<TerminalTabsState> {
  /// Close confirmations registered by mounted file-editor views, keyed by
  /// tab id. A guard that returns false keeps the tab open (dirty buffer).
  final Map<String, Future<bool> Function()> _closeGuards = {};

  /// Registers [guard] to be consulted before [close] removes [tabId].
  void registerCloseGuard(String tabId, Future<bool> Function() guard) {
    _closeGuards[tabId] = guard;
  }

  /// Removes the guard registered for [tabId], if any.
  void unregisterCloseGuard(String tabId) {
    _closeGuards.remove(tabId);
  }

  final _terminals = <String, _LiveTerminal>{};

  @override
  TerminalTabsState build() => const TerminalTabsState();

  Future<void> open(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    String? initialDirectory,
    List<String>? initialScripts,
    ServerProxy? proxy,
  }) async {
    final transport = await ref
        .read(connectionManagerProvider)
        .openTerminal(
          server,
          credential,
          approve,
          knownHostKeyFingerprint: knownHostKeyFingerprint,
          initialDirectory: initialDirectory,
          proxy: proxy,
          environment: decodeEnvironmentMap(server.environment),
          initialScripts: initialScripts ?? const <String>[],
        );
    final adapter = ref
        .read(terminalSessionAdapterFactoryProvider)
        .create(columns: transport.columns, rows: transport.rows);
    final binding = TerminalSessionBinding(
      adapter: adapter,
      stdout: transport.stdout,
      stderr: transport.stderr,
      send: transport.write,
      resize: (event) => transport.resize(
        event.columns,
        event.rows,
        event.pixelWidth,
        event.pixelHeight,
      ),
    );
    _terminals[transport.id] = _LiveTerminal(transport, binding);
    _insertTab(
      TerminalTab(
        id: transport.id,
        serverId: server.id,
        serverName: server.name,
        terminal: adapter,
      ),
    );
    // A shell ending (`exit`, logout, SSH drop) closes its tab through the
    // same path as a user close, so teardown order stays identical.
    unawaited(
      transport.done.then<void>(
        (_) => _closeTerminal(transport.id),
        onError: (_, _) => _closeTerminal(transport.id),
      ),
    );
  }

  void openFileManagement(Server server, {String? initialPath}) {
    final tab = FileManagementTab(
      id: 'files-${DateTime.now().microsecondsSinceEpoch}',
      serverId: server.id,
      serverName: server.name,
      initialPath: initialPath,
    );
    _insertTab(tab);
  }

  /// Opens [path] in a session editor tab. Reuses an existing tab for the same
  /// server + path + local/remote side.
  void openFileEditor({
    required Server server,
    required String path,
    required String fileName,
    required bool isRemote,
  }) {
    final existing = state.tabs.whereType<FileEditorTab>().where((tab) {
      return tab.serverId == server.id &&
          tab.path == path &&
          tab.isRemote == isRemote;
    }).firstOrNull;
    if (existing != null) {
      select(existing.id);
      return;
    }
    final side = isRemote ? 'remote' : 'local';
    _insertTab(
      FileEditorTab(
        id: 'editor-$side-${server.id}-$path',
        serverId: server.id,
        serverName: server.name,
        fileName: fileName,
        path: path,
        isRemote: isRemote,
      ),
    );
  }

  /// Shows [tabId] in the workspace.
  void select(String tabId) {
    if (state._tabById(tabId) == null) return;
    state = TerminalTabsState(tabs: state.tabs, selectedId: tabId);
  }

  /// Shows the workspace home (server grid) while tabs stay open.
  void selectHome() {
    if (state.selectedId == null) return;
    state = TerminalTabsState(tabs: state.tabs);
  }

  Future<void> close(String tabId) async {
    final tab = state._tabById(tabId);
    if (tab is FileEditorTab) {
      final guard = _closeGuards[tabId];
      if (guard != null && !await guard()) return;
    }
    _closeGuards.remove(tabId);
    if (tab is TerminalTab) {
      await _closeTerminal(tabId);
    } else {
      _removeTab(tabId);
    }
  }

  Future<void> closeForServer(int serverId) async {
    final tabIds = state.tabs
        .where((tab) => tab.serverId == serverId)
        .map((tab) => tab.id)
        .toList();
    await Future.wait(tabIds.map(close));
  }

  /// Closes every tab and shuts its shell down cleanly (app quit).
  Future<void> closeAll() async {
    // Editor close guards are skipped: quitting is the user's decision.
    _closeGuards.clear();
    final tabIds = state.tabs.map((tab) => tab.id).toList();
    await Future.wait(tabIds.map(close));
  }

  /// Removes the tab first, then tears the terminal down once the frame that
  /// unmounts its view has run. Idempotent: the shell-ended path and a user
  /// close can race.
  Future<void> _closeTerminal(String tabId) async {
    _removeTab(tabId);
    final live = _terminals.remove(tabId);
    if (live == null) return;
    await _afterCurrentFrame();
    await live.binding.close();
    try {
      await live.transport.close();
    } catch (_) {
      // The shell may already have closed its channel.
    }
  }

  /// Lets the frame reacting to the state change (which unmounts the tab's
  /// view) finish before native teardown. Immediate when no frame is pending.
  static Future<void> _afterCurrentFrame() {
    final binding = WidgetsBinding.instance;
    if (!binding.hasScheduledFrame) return Future.value();
    final completer = Completer<void>();
    binding.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  /// Appends [tab] and makes it the selected tab.
  void _insertTab(SessionTab tab) {
    state = TerminalTabsState(tabs: [...state.tabs, tab], selectedId: tab.id);
  }

  void _removeTab(String tabId) {
    final tabIndex = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (tabIndex < 0) return;
    _releaseSessionTabViewKey(tabId);

    final tabs = [...state.tabs]..removeAt(tabIndex);
    if (tabs.isEmpty) {
      state = const TerminalTabsState();
      return;
    }
    // Closing the selected tab falls back to its left neighbour; closing any
    // other tab (or closing while on home) keeps the current selection.
    final String? selectedId;
    if (state.selectedId == tabId) {
      selectedId = tabs[(tabIndex - 1).clamp(0, tabs.length - 1)].id;
    } else {
      selectedId = state.selectedId;
    }
    state = TerminalTabsState(tabs: tabs, selectedId: selectedId);
  }
}

class _LiveTerminal {
  const _LiveTerminal(this.transport, this.binding);

  final TerminalTransport transport;
  final TerminalSessionBinding binding;
}
