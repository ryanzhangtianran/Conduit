import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/data/local/app_database.dart';
import 'server_models.dart';
import 'server_providers.dart';

/// Marks [serverId] as the focused server (the one the metrics scheduler
/// refreshes at the focused interval) for as long as this is watched.
///
/// It has no dependencies of its own, so it only disposes when its last
/// watcher goes away, not when that watcher rebuilds.
final _focusedServerLeaseProvider = Provider.autoDispose.family<void, int>((
  ref,
  serverId,
) {
  final focused = ref.read(focusedServerIdProvider.notifier);
  // Riverpod forbids changing another provider while this one is being
  // built or torn down, so both transitions are deferred a microtask.
  Future.microtask(() => focused.focus(serverId));
  ref.onDispose(() => Future.microtask(() => focused.clear(serverId)));
});

/// The process list of the server shown on the Monitor page, refreshed at
/// [focusedServerRefreshIntervalProvider] while the server is connected.
///
/// Each tick also refreshes the server's statistics so the overview panel
/// keeps pace. A failed first load surfaces as an error (the page offers a
/// retry via `ref.invalidate`); a failed later tick keeps the last list and
/// the next tick tries again. Watching this also focuses the server for the
/// background scheduler until the page stops watching.
final focusedServerProcessesProvider = StreamProvider.autoDispose
    .family<List<ServerProcess>, int>((ref, serverId) async* {
      ref.watch(_focusedServerLeaseProvider(serverId));
      final manager = ref.watch(connectionManagerProvider);
      final interval = ref.watch(focusedServerRefreshIntervalProvider);
      final connected = ref.watch(
        sessionsProvider.select(
          (sessions) =>
              sessions.asData?.value.any(
                (session) =>
                    session.serverId == serverId &&
                    session.status == SessionStatus.connected,
              ) ??
              false,
        ),
      );
      var cancelled = false;
      ref.onDispose(() => cancelled = true);

      if (!connected) {
        yield const [];
        return;
      }
      yield await manager.listProcesses(serverId);
      while (!cancelled) {
        await Future<void>.delayed(interval);
        if (cancelled) return;
        final server =
            (ref.read(serversProvider).asData?.value ?? const <Server>[])
                .where((server) => server.id == serverId)
                .firstOrNull;
        if (server == null || manager.clientFor(serverId) == null) continue;
        try {
          await manager.refreshServerInfo(server);
          final processes = await manager.listProcesses(serverId);
          if (cancelled) return;
          yield processes;
        } catch (_) {
          // The last list stays on screen; the next tick retries.
        }
      }
    });

/// The password to hand `sudo` when acting on [server]'s processes: the
/// stored password for password-authenticated servers, otherwise null (a
/// key-authenticated user is expected to have passwordless sudo or be root).
Future<String?> sudoPasswordFor(WidgetRef ref, Server server) async {
  final credential = await ref
      .read(serverRepositoryProvider)
      .credentialFor(server);
  return credential.type == CredentialType.password
      ? credential.password
      : null;
}
