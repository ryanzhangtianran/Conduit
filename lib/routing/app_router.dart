// Shell route consts follow the generated-route naming style.
// ignore_for_file: constant_identifier_names
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_router.gr.dart';

final conduitNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<AppRouter>(
  (ref) => AppRouter(navigatorKey: conduitNavigatorKey),
);

/// Tab shells that host nested detail routes. Each renders an [AutoRouter]
/// outlet, so pushed detail pages (GitHub run) stay inside
/// their tab's stack and the tab chrome (rail / bottom navigation) remains
/// switchable while inspecting them.
const ServersTab = EmptyShellRoute('ServersTab');
const ConnectionsTab = EmptyShellRoute('ConnectionsTab');
const GithubTab = EmptyShellRoute('GithubTab');

/// Detail pages opened from within a tab. Declared under every shell tab so
/// cross-links (e.g. opening a GitHub run from another tab) resolve against
/// the tab the user is currently inspecting.
List<AutoRoute> _detailRoutes() => [
  AutoRoute(page: GitHubRunDetailRoute.page, path: 'github-run-detail'),
];

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey});

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: ServerWorkspaceRoute.page,
      initial: true,
      children: [
        AutoRoute(
          page: ServersTab.page,
          path: '',
          initial: true,
          children: [
            AutoRoute(page: ServersRoute.page, path: '', initial: true),
            ..._detailRoutes(),
          ],
        ),
        AutoRoute(
          page: ConnectionsTab.page,
          path: 'connections',
          children: [
            AutoRoute(page: ConnectionsRoute.page, path: '', initial: true),
            ..._detailRoutes(),
          ],
        ),
        AutoRoute(
          page: GithubTab.page,
          path: 'github',
          children: [
            AutoRoute(page: GithubRoute.page, path: '', initial: true),
            ..._detailRoutes(),
          ],
        ),
        AutoRoute(page: TerminalRoute.page, path: 'terminal'),
        AutoRoute(page: MonitorRoute.page, path: 'monitor'),
        AutoRoute(page: PortForwardingRoute.page, path: 'port-forwarding'),
        AutoRoute(
          page: SettingsRoute.page,
          path: 'settings',
          children: [
            AutoRoute(
              page: TerminalSettingsRoute.page,
              path: 'terminal',
              initial: true,
            ),
            AutoRoute(page: ConnectionsSettingsRoute.page, path: 'connections'),
            AutoRoute(page: SyncSettingsRoute.page, path: 'sync'),
            AutoRoute(page: SecuritySettingsRoute.page, path: 'security'),
            AutoRoute(page: AboutSettingsRoute.page, path: 'about'),
          ],
        ),
      ],
    ),
  ];
}
