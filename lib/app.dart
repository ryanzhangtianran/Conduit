import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart' hide GlobalMaterialLocalizations;
import 'package:material_ui/material_ui.dart'
    as material_ui
    show GlobalMaterialLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';

import 'routing/app_router.dart';
import 'shared/presentation/conduit_window_scaffold.dart';
import 'servers/server_providers.dart';
import 'servers/startup_connection_bootstrap.dart';
import 'servers/vault_gate.dart';
import 'theme.dart';

final conduitOverlayKey = GlobalKey<OverlayState>();

class ConduitApp extends ConsumerStatefulWidget {
  const ConduitApp({super.key});

  @override
  ConsumerState<ConduitApp> createState() => _ConduitAppState();
}

class _ConduitAppState extends ConsumerState<ConduitApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appRouter = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appSeedColor = ref.watch(appSeedColorProvider);
    ref.watch(serverMetricsRefreshSchedulerProvider);
    IslandUIFoundation.configureOverlay(conduitOverlayKey);
    IslandUIFoundation.configureNavigator(conduitNavigatorKey);
    return MaterialApp.router(
      title: 'title'.tr(),
      debugShowCheckedModeBanner: true,
      theme: createConduitTheme(Brightness.light, seedColor: appSeedColor),
      darkTheme: createConduitTheme(Brightness.dark, seedColor: appSeedColor),
      themeMode: themeMode,
      localizationsDelegates: [
        ...context.localizationDelegates,
        ...material_ui.GlobalMaterialLocalizations.delegates,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter.config(),
      builder: (context, child) => Overlay(
        key: conduitOverlayKey,
        initialEntries: [
          OverlayEntry(
            builder: (context) => ConduitWindowScaffold(
              title: 'title'.tr(),
              // The gate needs a Navigator for standard Material controls
              // such as a dropdown. The app router remains below it and is
              // only exposed once the vault unlocks.
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  // The whole app is one selection area so any label can be
                  // copied; terminals and text fields keep their own handling.
                  builder: (context) => SelectionArea(
                    child: VaultGate(
                      child: StartupConnectionBootstrap(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
