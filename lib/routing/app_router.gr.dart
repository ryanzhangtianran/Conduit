// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i15;
import 'package:conduit/github/github_models.dart' as _i17;
import 'package:conduit/github/github_page.dart' as _i5;
import 'package:conduit/github/github_run_detail_page.dart' as _i4;
import 'package:conduit/servers/connections_page.dart' as _i2;
import 'package:conduit/servers/monitor_page.dart' as _i6;
import 'package:conduit/servers/port_forwarding_page.dart' as _i7;
import 'package:conduit/servers/server_workspace_page.dart' as _i9;
import 'package:conduit/servers/servers_page.dart' as _i10;
import 'package:conduit/servers/sessions_page.dart' as _i13;
import 'package:conduit/servers/settings/about_settings_page.dart' as _i1;
import 'package:conduit/servers/settings/connections_settings_page.dart' as _i3;
import 'package:conduit/servers/settings/security_settings_page.dart' as _i8;
import 'package:conduit/servers/settings/sync_settings_page.dart' as _i12;
import 'package:conduit/servers/settings/terminal_settings_page.dart' as _i14;
import 'package:conduit/servers/settings_page.dart' as _i11;
import 'package:material_ui/material_ui.dart' as _i16;

/// generated route for
/// [_i1.AboutSettingsPage]
class AboutSettingsRoute extends _i15.PageRouteInfo<void> {
  const AboutSettingsRoute({List<_i15.PageRouteInfo>? children})
    : super(AboutSettingsRoute.name, initialChildren: children);

  static const String name = 'AboutSettingsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutSettingsPage();
    },
  );
}

/// generated route for
/// [_i2.ConnectionsPage]
class ConnectionsRoute extends _i15.PageRouteInfo<void> {
  const ConnectionsRoute({List<_i15.PageRouteInfo>? children})
    : super(ConnectionsRoute.name, initialChildren: children);

  static const String name = 'ConnectionsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i2.ConnectionsPage();
    },
  );
}

/// generated route for
/// [_i3.ConnectionsSettingsPage]
class ConnectionsSettingsRoute extends _i15.PageRouteInfo<void> {
  const ConnectionsSettingsRoute({List<_i15.PageRouteInfo>? children})
    : super(ConnectionsSettingsRoute.name, initialChildren: children);

  static const String name = 'ConnectionsSettingsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i3.ConnectionsSettingsPage();
    },
  );
}

/// generated route for
/// [_i4.GitHubRunDetailPage]
class GitHubRunDetailRoute
    extends _i15.PageRouteInfo<GitHubRunDetailRouteArgs> {
  GitHubRunDetailRoute({
    _i16.Key? key,
    required String owner,
    required String name,
    required int runId,
    required _i17.WorkflowRun run,
    List<_i15.PageRouteInfo>? children,
  }) : super(
         GitHubRunDetailRoute.name,
         args: GitHubRunDetailRouteArgs(
           key: key,
           owner: owner,
           name: name,
           runId: runId,
           run: run,
         ),
         initialChildren: children,
       );

  static const String name = 'GitHubRunDetailRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GitHubRunDetailRouteArgs>();
      return _i4.GitHubRunDetailPage(
        key: args.key,
        owner: args.owner,
        name: args.name,
        runId: args.runId,
        run: args.run,
      );
    },
  );
}

class GitHubRunDetailRouteArgs {
  const GitHubRunDetailRouteArgs({
    this.key,
    required this.owner,
    required this.name,
    required this.runId,
    required this.run,
  });

  final _i16.Key? key;

  final String owner;

  final String name;

  final int runId;

  final _i17.WorkflowRun run;

  @override
  String toString() {
    return 'GitHubRunDetailRouteArgs{key: $key, owner: $owner, name: $name, runId: $runId, run: $run}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GitHubRunDetailRouteArgs) return false;
    return key == other.key &&
        owner == other.owner &&
        name == other.name &&
        runId == other.runId &&
        run == other.run;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      owner.hashCode ^
      name.hashCode ^
      runId.hashCode ^
      run.hashCode;
}

/// generated route for
/// [_i5.GithubPage]
class GithubRoute extends _i15.PageRouteInfo<void> {
  const GithubRoute({List<_i15.PageRouteInfo>? children})
    : super(GithubRoute.name, initialChildren: children);

  static const String name = 'GithubRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i5.GithubPage();
    },
  );
}

/// generated route for
/// [_i6.MonitorPage]
class MonitorRoute extends _i15.PageRouteInfo<void> {
  const MonitorRoute({List<_i15.PageRouteInfo>? children})
    : super(MonitorRoute.name, initialChildren: children);

  static const String name = 'MonitorRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i6.MonitorPage();
    },
  );
}

/// generated route for
/// [_i7.PortForwardingPage]
class PortForwardingRoute extends _i15.PageRouteInfo<void> {
  const PortForwardingRoute({List<_i15.PageRouteInfo>? children})
    : super(PortForwardingRoute.name, initialChildren: children);

  static const String name = 'PortForwardingRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i7.PortForwardingPage();
    },
  );
}

/// generated route for
/// [_i8.SecuritySettingsPage]
class SecuritySettingsRoute extends _i15.PageRouteInfo<void> {
  const SecuritySettingsRoute({List<_i15.PageRouteInfo>? children})
    : super(SecuritySettingsRoute.name, initialChildren: children);

  static const String name = 'SecuritySettingsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i8.SecuritySettingsPage();
    },
  );
}

/// generated route for
/// [_i9.ServerWorkspacePage]
class ServerWorkspaceRoute extends _i15.PageRouteInfo<void> {
  const ServerWorkspaceRoute({List<_i15.PageRouteInfo>? children})
    : super(ServerWorkspaceRoute.name, initialChildren: children);

  static const String name = 'ServerWorkspaceRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i9.ServerWorkspacePage();
    },
  );
}

/// generated route for
/// [_i10.ServersPage]
class ServersRoute extends _i15.PageRouteInfo<void> {
  const ServersRoute({List<_i15.PageRouteInfo>? children})
    : super(ServersRoute.name, initialChildren: children);

  static const String name = 'ServersRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i10.ServersPage();
    },
  );
}

/// generated route for
/// [_i11.SettingsPage]
class SettingsRoute extends _i15.PageRouteInfo<void> {
  const SettingsRoute({List<_i15.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i11.SettingsPage();
    },
  );
}

/// generated route for
/// [_i12.SyncSettingsPage]
class SyncSettingsRoute extends _i15.PageRouteInfo<void> {
  const SyncSettingsRoute({List<_i15.PageRouteInfo>? children})
    : super(SyncSettingsRoute.name, initialChildren: children);

  static const String name = 'SyncSettingsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i12.SyncSettingsPage();
    },
  );
}

/// generated route for
/// [_i13.TerminalPage]
class TerminalRoute extends _i15.PageRouteInfo<void> {
  const TerminalRoute({List<_i15.PageRouteInfo>? children})
    : super(TerminalRoute.name, initialChildren: children);

  static const String name = 'TerminalRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i13.TerminalPage();
    },
  );
}

/// generated route for
/// [_i14.TerminalSettingsPage]
class TerminalSettingsRoute extends _i15.PageRouteInfo<void> {
  const TerminalSettingsRoute({List<_i15.PageRouteInfo>? children})
    : super(TerminalSettingsRoute.name, initialChildren: children);

  static const String name = 'TerminalSettingsRoute';

  static _i15.PageInfo page = _i15.PageInfo(
    name,
    builder: (data) {
      return const _i14.TerminalSettingsPage();
    },
  );
}
