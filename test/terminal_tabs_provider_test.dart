import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/servers/ssh_connection_manager.dart';
import 'package:conduit/servers/terminal_session_adapter.dart';
import 'package:conduit/servers/terminal_tabs_provider.dart';

const _server = Server(
  id: 7,
  name: 'box',
  host: 'example.com',
  port: 22,
  username: 'root',
  collectStats: false,
  collectSystemInfo: false,
  connectionType: 'ssh',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeConnectionManager manager;
  late _FakeAdapterFactory factory;
  late ProviderContainer container;

  setUp(() {
    manager = _FakeConnectionManager();
    factory = _FakeAdapterFactory();
    container = ProviderContainer(
      overrides: [
        connectionManagerProvider.overrideWithValue(manager),
        terminalSessionAdapterFactoryProvider.overrideWithValue(factory),
      ],
    );
    addTearDown(container.dispose);
  });

  TerminalTabsNotifier notifier() =>
      container.read(terminalTabsProvider.notifier);

  Future<TerminalTab> openTab() async {
    await notifier().open(
      _server,
      const ServerCredential.password('secret'),
      (_) async => true,
    );
    return container.read(terminalTabsProvider).tabs.last as TerminalTab;
  }

  test('binds an adapter sized like the PTY to the transport', () async {
    final tab = await openTab();
    final adapter = factory.created.single;

    expect(tab.terminal, same(adapter));
    expect(adapter.columns, SshConnectionManager.terminalColumns);
    expect(adapter.rows, SshConnectionManager.terminalRows);
    expect(container.read(terminalTabsProvider).selectedId, tab.id);

    manager.shells.single.stdout.add(Uint8List.fromList([1, 2, 3]));
    adapter.emitInput(Uint8List.fromList([4]));
    await Future<void>.delayed(const Duration(milliseconds: 12));
    expect(adapter.received, [
      Uint8List.fromList([1, 2, 3]),
    ]);
    expect(manager.shells.single.written, [
      Uint8List.fromList([4]),
    ]);
  });

  test('home deselects without closing tabs', () async {
    final tab = await openTab();

    notifier().selectHome();
    final home = container.read(terminalTabsProvider);
    expect(home.selectedId, isNull);
    expect(home.selectedTab, isNull);
    expect(home.tabs, hasLength(1));

    notifier().select(tab.id);
    expect(container.read(terminalTabsProvider).selectedId, tab.id);

    // Closing another tab while on home keeps showing home.
    notifier().openFileManagement(_server);
    notifier().selectHome();
    await notifier().close(container.read(terminalTabsProvider).tabs.last.id);
    expect(container.read(terminalTabsProvider).selectedId, isNull);
    expect(container.read(terminalTabsProvider).tabs, hasLength(1));
  });

  test('closing removes the tab before the adapter is torn down', () async {
    final tab = await openTab();
    final adapter = factory.created.single;
    var disposedWhenRemoved = true;
    container.listen(terminalTabsProvider, (_, state) {
      if (state.tabs.isEmpty) disposedWhenRemoved = adapter.disposed;
    });

    await notifier().close(tab.id);

    expect(disposedWhenRemoved, isFalse);
    expect(adapter.disposed, isTrue);
    expect(manager.shells.single.closed, isTrue);
    expect(container.read(terminalTabsProvider).isEmpty, isTrue);
  });

  test('a shell ending closes its tab through the notifier', () async {
    final tab = await openTab();
    final adapter = factory.created.single;

    manager.shells.single.done.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(terminalTabsProvider).tabs, isEmpty);
    expect(adapter.disposed, isTrue);
    expect(manager.shells.single.closed, isTrue);
    // A later user close of the same id is harmless.
    await notifier().close(tab.id);
  });

  test('closeAll closes every tab and shell', () async {
    await openTab();
    await openTab();
    notifier().openFileManagement(_server);

    await notifier().closeAll();

    expect(container.read(terminalTabsProvider).isEmpty, isTrue);
    expect(factory.created.every((adapter) => adapter.disposed), isTrue);
    expect(manager.shells.every((shell) => shell.closed), isTrue);
  });
}

class _FakeShell {
  final stdout = StreamController<Uint8List>();
  final stderr = StreamController<Uint8List>();
  final written = <Uint8List>[];
  final done = Completer<void>();
  var closed = false;
}

class _FakeConnectionManager extends SshConnectionManager {
  final shells = <_FakeShell>[];
  var _nextId = 0;

  @override
  Future<TerminalTransport> openTerminal(
    Server server,
    ServerCredential credential,
    HostKeyApproval approve, {
    String? knownHostKeyFingerprint,
    String? initialDirectory,
    ServerProxy? proxy,
    Map<String, String>? environment,
    List<String>? initialScripts,
  }) async {
    final shell = _FakeShell();
    shells.add(shell);
    return TerminalTransport(
      id: 'fake-${_nextId++}',
      columns: SshConnectionManager.terminalColumns,
      rows: SshConnectionManager.terminalRows,
      stdout: shell.stdout.stream,
      stderr: shell.stderr.stream,
      write: shell.written.add,
      resize: (_, _, _, _) {},
      done: shell.done.future,
      close: () async {
        shell.closed = true;
        if (!shell.done.isCompleted) shell.done.complete();
      },
    );
  }
}

class _FakeAdapterFactory implements TerminalSessionAdapterFactory {
  final created = <_FakeAdapter>[];

  @override
  TerminalSessionAdapter create({required int columns, required int rows}) {
    final adapter = _FakeAdapter(columns, rows);
    created.add(adapter);
    return adapter;
  }
}

class _FakeAdapter implements TerminalSessionAdapter {
  _FakeAdapter(this.columns, this.rows);

  final int columns;
  final int rows;
  final received = <Uint8List>[];
  final _outgoing = StreamController<Uint8List>.broadcast();
  var disposed = false;

  void emitInput(Uint8List bytes) => _outgoing.add(bytes);

  @override
  Stream<Uint8List> get outgoingBytes => _outgoing.stream;

  @override
  Stream<TerminalResize> get resizeEvents => const Stream.empty();

  @override
  Stream<void> get outputChanges => const Stream.empty();

  @override
  Stream<TerminalTaskActivity> get taskActivity => const Stream.empty();

  @override
  TerminalTaskActivity get currentTaskActivity =>
      const TerminalTaskActivity(running: false);

  @override
  String? get currentDirectory => null;

  @override
  void write(Uint8List bytes) => received.add(bytes);

  @override
  void sendInput(String text) {}

  @override
  void showKeyboard() {}

  @override
  void hideKeyboard() {}

  @override
  Widget buildView({
    bool autofocus = false,
    VoidCallback? onOpenFileManagement,
    FocusOnKeyEventCallback? onKeyEvent,
  }) => const SizedBox();

  @override
  int find(String query, {bool caseSensitive = false}) => 0;

  @override
  void findJump(int index) {}

  @override
  void findClear() {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _outgoing.close();
  }
}
