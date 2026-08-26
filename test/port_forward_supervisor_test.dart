import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/port_forward_supervisor.dart';
import 'package:conduit/servers/port_forwarding_models.dart';
import 'package:conduit/servers/ssh_connection_manager.dart';

PortForwardConfig _config(
  int id, {
  int serverId = 1,
  String direction = 'local',
  String kind = 'tcp',
  String bindHost = '127.0.0.1',
  int bindPort = 8080,
  String targetHost = '127.0.0.1',
  int targetPort = 80,
  bool keepAlive = true,
  bool autoStart = false,
}) => PortForwardConfig(
  id: id,
  serverId: serverId,
  direction: direction,
  kind: kind,
  bindHost: bindHost,
  bindPort: bindPort,
  targetHost: targetHost,
  targetPort: targetPort,
  autoStart: autoStart,
  keepAlive: keepAlive,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _forward = ActivePortForward(
  id: 'forward-1',
  serverId: 1,
  serverName: 'server',
  direction: PortForwardDirection.local,
  kind: PortForwardKind.tcp,
  bindHost: '127.0.0.1',
  bindPort: 8080,
  targetHost: '127.0.0.1',
  targetPort: 80,
);

void main() {
  group('activeForwardMatches', () {
    test('matches on kind, bind address, direction and destination', () {
      expect(activeForwardMatches(_forward, _config(1)), isTrue);
      expect(
        activeForwardMatches(_forward, _config(1, targetPort: 81)),
        isFalse,
      );
      expect(
        activeForwardMatches(_forward, _config(1, bindPort: 9090)),
        isFalse,
      );
      expect(activeForwardMatches(_forward, _config(1, serverId: 2)), isFalse);
    });

    test('a local and a remote preset with the same bind address differ', () {
      expect(
        activeForwardMatches(_forward, _config(1, direction: 'remote')),
        isFalse,
      );
    });

    test('SOCKS5 forwards are identified by their listener alone', () {
      final socks = ActivePortForward(
        id: 'forward-2',
        serverId: 1,
        serverName: 'server',
        direction: PortForwardDirection.local,
        kind: PortForwardKind.socks5,
        bindHost: '127.0.0.1',
        bindPort: 1080,
      );
      expect(
        activeForwardMatches(
          socks,
          _config(
            1,
            kind: 'socks5',
            bindPort: 1080,
            targetHost: '',
            targetPort: 0,
          ),
        ),
        isTrue,
      );
      expect(activeForwardMatches(socks, _config(1, bindPort: 1080)), isFalse);
    });
  });

  group('PortForwardSupervisor', () {
    late SshConnectionManager manager;
    late StreamController<List<Server>> servers;
    late StreamController<List<PortForwardConfig>> configs;
    late PortForwardSupervisor supervisor;

    setUp(() {
      manager = SshConnectionManager();
      servers = StreamController<List<Server>>.broadcast();
      configs = StreamController<List<PortForwardConfig>>.broadcast();
      supervisor = PortForwardSupervisor(
        manager,
        servers: servers.stream,
        configs: configs.stream,
      );
    });

    tearDown(() async {
      supervisor.dispose();
      await servers.close();
      await configs.close();
      await manager.dispose();
    });

    test('unknown and non-keep-alive presets are unsupervised', () async {
      expect(supervisor.statusOf(1), PortForwardPresetStatus.unsupervised);
      configs.add([_config(1, keepAlive: false)]);
      await pumpEventQueue();
      expect(supervisor.statusOf(1), PortForwardPresetStatus.unsupervised);
    });

    test('pause, resume and forget drive the status and notify', () async {
      final events = <void>[];
      final subscription = supervisor.changes.listen(events.add);
      addTearDown(subscription.cancel);
      configs.add([_config(1)]);
      await pumpEventQueue();
      // Not connected: supervised only once the server is up.
      expect(supervisor.statusOf(1), PortForwardPresetStatus.unsupervised);
      final loaded = events.length;

      supervisor.pause(1);
      expect(supervisor.statusOf(1), PortForwardPresetStatus.paused);
      await pumpEventQueue();
      expect(events, hasLength(loaded + 1));

      supervisor.resume(1);
      expect(supervisor.statusOf(1), PortForwardPresetStatus.unsupervised);
      await pumpEventQueue();
      expect(events, hasLength(loaded + 2));

      supervisor.pause(1);
      supervisor.forget(1);
      expect(supervisor.statusOf(1), PortForwardPresetStatus.unsupervised);
    });

    test(
      'a deleted preset stops being paused when the stream drops it',
      () async {
        configs.add([_config(1)]);
        await pumpEventQueue();
        supervisor.pause(1);
        configs.add(const []);
        await pumpEventQueue();
        expect(supervisor.statusOf(1), PortForwardPresetStatus.unsupervised);
      },
    );
  });
}
