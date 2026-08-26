import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_processes_provider.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/servers/ssh_connection_manager.dart';

/// Serves a canned process list without touching SSH.
class _FakeConnectionManager extends SshConnectionManager {
  var listCalls = 0;

  @override
  Future<List<ServerProcess>> listProcesses(int serverId) async {
    listCalls++;
    return const [
      ServerProcess(
        pid: 42,
        user: 'root',
        cpuPercent: 1,
        memoryPercent: 2,
        rssKb: 3,
        command: 'sshd',
      ),
    ];
  }
}

void main() {
  ProviderContainer container(
    _FakeConnectionManager manager, {
    SessionStatus? status,
  }) {
    final container = ProviderContainer(
      overrides: [
        connectionManagerProvider.overrideWithValue(manager),
        sessionsProvider.overrideWith(
          (ref) => Stream.value([
            if (status != null)
              SshSessionInfo(
                serverId: 1,
                serverName: 'box',
                connectedAt: DateTime(2026),
                status: status,
              ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('focuses the server while watched and clears it afterwards', () async {
    final manager = _FakeConnectionManager();
    final c = container(manager);
    expect(c.read(focusedServerIdProvider), isNull);

    final subscription = c.listen(focusedServerProcessesProvider(1), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(focusedServerIdProvider), 1);

    // A disconnected server yields an empty list and never lists processes.
    await Future<void>.delayed(Duration.zero);
    expect(c.read(focusedServerProcessesProvider(1)).value, isEmpty);
    expect(manager.listCalls, 0);

    subscription.close();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(focusedServerIdProvider), isNull);
  });

  test('lists processes once the server is connected', () async {
    final manager = _FakeConnectionManager();
    final c = container(manager, status: SessionStatus.connected);
    final subscription = c.listen(focusedServerProcessesProvider(1), (_, _) {});
    addTearDown(subscription.close);
    // The session stream settles a tick later; the provider then rebuilds
    // as connected and lists processes.
    while (manager.listCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    final processes = await c.read(focusedServerProcessesProvider(1).future);
    expect(processes.single.pid, 42);
    expect(manager.listCalls, 1);
  });
}
