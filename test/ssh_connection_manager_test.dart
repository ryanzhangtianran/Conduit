import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/ssh_connection_manager.dart';

Server _server(
  int id, {
  int? jumpHostServerId,
  String host = '127.0.0.1',
  int port = 22,
}) => Server(
  id: id,
  name: 'server-$id',
  host: host,
  port: port,
  username: 'root',
  collectStats: false,
  collectSystemInfo: false,
  connectionType: 'ssh',
  jumpHostServerId: jumpHostServerId,
);

SshConnectionManager _manager() => SshConnectionManager();

void main() {
  group('connect', () {
    test(
      'a second connect joins the in-flight one and disconnect cancels it',
      () async {
        // A listener that accepts and never speaks SSH keeps the handshake
        // pending until the test decides how it ends.
        final listener = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(listener.close);
        final accepted = <Socket>[];
        listener.listen(accepted.add);
        final manager = _manager();
        addTearDown(manager.dispose);
        final server = _server(1, port: listener.port);
        const credential = ServerCredential.password('secret');

        final first = manager.connect(server, credential, (_) async => true);
        final second = manager.connect(server, credential, (_) async => true);
        expect(identical(first, second), isTrue);
        await pumpEventQueue();
        expect(manager.current.single.status, SessionStatus.connecting);
        // Only one transport was opened for the two calls.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(accepted, hasLength(1));

        await manager.disconnect(server.id);
        expect(manager.current.single.status, SessionStatus.closed);

        // The handshake now ends (here: in failure); the cancelled connect must
        // neither throw nor flip the status.
        accepted.single.destroy();
        await first;
        expect(manager.current.single.status, SessionStatus.closed);
        expect(manager.clientFor(server.id), isNull);
      },
    );

    test('a failed handshake after a fresh connect reports failed', () async {
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(listener.close);
      listener.listen((socket) => socket.destroy());
      final manager = _manager();
      addTearDown(manager.dispose);
      final server = _server(1, port: listener.port);

      await expectLater(
        manager.connect(
          server,
          const ServerCredential.password('x'),
          (_) async => true,
        ),
        throwsA(anything),
      );
      expect(manager.current.single.status, SessionStatus.failed);
      expect(manager.current.single.error, isNotNull);
    });
  });

  test('forgetServer drops the session state', () async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(listener.close);
    listener.listen((socket) => socket.destroy());
    final manager = _manager();
    addTearDown(manager.dispose);
    final server = _server(1, port: listener.port);
    await manager
        .connect(
          server,
          const ServerCredential.password('x'),
          (_) async => true,
        )
        .catchError((_) {});
    expect(manager.current, hasLength(1));
    await manager.forgetServer(server.id);
    expect(manager.current, isEmpty);
  });

  group('connectJumpHosts', () {
    test('connects the chain root first and skips the target', () async {
      final manager = _manager();
      addTearDown(manager.dispose);
      final root = _server(1);
      final middle = _server(2, jumpHostServerId: 1);
      final target = _server(3, jumpHostServerId: 2);
      final hops = <int>[];
      await manager.connectJumpHosts(target, [
        root,
        middle,
        target,
      ], connectHop: (hop) async => hops.add(hop.id));
      expect(hops, [1, 2]);
    });

    test('rejects a missing hop and a cycle', () async {
      final manager = _manager();
      addTearDown(manager.dispose);
      final orphan = _server(3, jumpHostServerId: 9);
      await expectLater(
        manager.connectJumpHosts(orphan, [orphan], connectHop: (_) async {}),
        throwsA(isA<StateError>()),
      );
      final a = _server(1, jumpHostServerId: 2);
      final b = _server(2, jumpHostServerId: 1);
      await expectLater(
        manager.connectJumpHosts(a, [a, b], connectHop: (_) async {}),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('copyWith clears a stale error only when asked', () {
    final failed = SshSessionInfo(
      serverId: 1,
      serverName: 'x',
      connectedAt: DateTime(2026),
      status: SessionStatus.failed,
      error: 'boom',
    );
    expect(failed.copyWith(status: SessionStatus.connected).error, 'boom');
    expect(
      failed.copyWith(status: SessionStatus.connected, clearError: true).error,
      isNull,
    );
  });
}
