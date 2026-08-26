import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/data/local/app_database.dart';
import 'local_proxy_migration.dart';
import 'server_connection_actions.dart';
import 'server_providers.dart';

/// One-time data conversions that need the unlocked vault. They run before
/// startup connections so migrated presets take part in them, and once per
/// vault: each step keeps its own marker in the vault's app settings.
final startupMigrationsProvider = FutureProvider<void>(
  (ref) => migrateLocalProxyForwards(ref.watch(serverRepositoryProvider)),
);

class StartupConnectionBootstrap extends ConsumerStatefulWidget {
  const StartupConnectionBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupConnectionBootstrap> createState() =>
      _StartupConnectionBootstrapState();
}

class _StartupConnectionBootstrapState
    extends ConsumerState<StartupConnectionBootstrap> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    // The vault is unlocked by the time this builds, so the database is
    // available for the migrations.
    ref.watch(startupMigrationsProvider);
    final enabled = ref.watch(connectOnStartupProvider);
    if (enabled && !_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_connectSavedServers());
      });
    }
    return widget.child;
  }

  Future<void> _connectSavedServers() async {
    await ref.read(startupMigrationsProvider.future);
    if (!mounted) return;
    final repository = ref.read(serverRepositoryProvider);
    final manager = ref.read(connectionManagerProvider);
    final servers = await repository.all();

    // Nobody is there to approve an unknown host key at startup, so it is
    // rejected and the server shows as failed; the interactive path prompts.
    Future<void> connectHop(Server hop) =>
        connectSavedServer(repository, manager, hop, (_) async => false);

    for (final server in servers) {
      try {
        await manager.connectJumpHosts(server, servers, connectHop: connectHop);
        if (manager.clientFor(server.id) == null) await connectHop(server);
      } catch (_) {
        // The connection manager exposes the failure state to the server grid.
      }
    }
  }
}
