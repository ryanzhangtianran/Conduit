import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/routing/app_router.dart';
import 'package:conduit/routing/app_router.gr.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'local_proxy_migration.dart';
import 'server_connection_actions.dart';
import 'server_providers.dart';

/// One-time data conversions that need the unlocked vault. They run before
/// startup connections so migrated presets take part in them, and once per
/// vault: each step keeps its own marker in the vault's app settings.
final startupMigrationsProvider = FutureProvider<void>(
  (ref) => migrateLocalProxyForwards(ref.watch(serverRepositoryProvider)),
);

/// How long after the workspace appears the launch-time update check runs.
const startupUpdateCheckDelay = Duration(seconds: 5);

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
  Timer? _updateCheck;

  @override
  void initState() {
    super.initState();
    // The updater itself makes sure this runs at most once per launch and
    // not more often than its throttle allows.
    _updateCheck = Timer(
      startupUpdateCheckDelay,
      () => unawaited(_checkForUpdates()),
    );
  }

  @override
  void dispose() {
    _updateCheck?.cancel();
    super.dispose();
  }

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

  Future<void> _checkForUpdates() async {
    final update = await ref
        .read(availableUpdateProvider.notifier)
        .checkOnStartup();
    if (update == null || !mounted) return;
    showStyledSnackBar(
      message: 'updateSnackbarMessage'.tr(args: [update.version]),
      icon: Symbols.update,
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'updateSnackbarAction'.tr(),
        onPressed: () => ref
            .read(appRouterProvider)
            .navigate(const SettingsRoute(children: [AboutSettingsRoute()])),
      ),
    );
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
