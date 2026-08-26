import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart' hide GlobalMaterialLocalizations;
import 'package:material_ui/material_ui.dart'
    as material_ui
    show GlobalMaterialLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';

import 'routing/app_router.dart';
import 'servers/server_providers.dart';
import 'servers/startup_connection_bootstrap.dart';
import 'servers/terminal_command_palette.dart';
import 'servers/vault_gate.dart';
import 'shared/presentation/conduit_window_scaffold.dart';
import 'app_tray_controller.dart';
import 'theme.dart';

final conduitOverlayKey = GlobalKey<OverlayState>();

class ConduitApp extends ConsumerStatefulWidget {
  const ConduitApp({super.key});

  @override
  ConsumerState<ConduitApp> createState() => _ConduitAppState();
}

class _ConduitAppState extends ConsumerState<ConduitApp> {
  AppTrayController? _tray;

  @override
  void initState() {
    super.initState();
    if (DesktopWindowFrame.isPlatformDesktop) {
      final tray = _tray = AppTrayController(ref)..init();
      ref.read(appTrayControllerProvider.notifier).register(tray);
    }
  }

  @override
  void dispose() {
    _tray?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appRouter = ref.watch(appRouterProvider);
    ref.watch(serverMetricsRefreshSchedulerProvider);
    AppOverlayRegistry.configureOverlay(conduitOverlayKey);
    AppOverlayRegistry.configureNavigator(conduitNavigatorKey);
    return MaterialApp.router(
      title: 'title'.tr(),
      debugShowCheckedModeBanner: true,
      theme: createConduitTheme(Brightness.light),
      darkTheme: createConduitTheme(Brightness.dark),
      themeMode: ThemeMode.system,
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
            builder: (context) => _CommandPaletteShortcut(
              child: ConduitWindowScaffold(
                title: 'title'.tr(),
                // The gate needs a Navigator for standard Material controls
                // such as a dropdown. The app router remains below it and is
                // only exposed once the vault unlocks.
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute<void>(
                    settings: settings,
                    // The whole app is one selection area so any label can
                    // be copied; terminals and text fields keep their own
                    // handling.
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
          ),
        ],
      ),
    );
  }
}

/// Shift+Tab anywhere in the window opens the terminal command palette.
class _CommandPaletteShortcut extends ConsumerWidget {
  const _CommandPaletteShortcut({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Focus(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          HardwareKeyboard.instance.isShiftPressed) {
        showTerminalCommandPalette(context, ref);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}
