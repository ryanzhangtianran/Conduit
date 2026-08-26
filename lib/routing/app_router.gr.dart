// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i11;
import 'package:conduit/data/local/app_database.dart' as _i14;
import 'package:conduit/github/github_models.dart' as _i13;
import 'package:conduit/github/github_run_detail_page.dart' as _i3;
import 'package:conduit/servers/about_page.dart' as _i1;
import 'package:conduit/servers/assets_page.dart' as _i2;
import 'package:conduit/servers/monitor_page.dart' as _i4;
import 'package:conduit/servers/port_forwarding_page.dart' as _i5;
import 'package:conduit/servers/server_detail_page.dart' as _i6;
import 'package:conduit/servers/server_workspace_page.dart' as _i7;
import 'package:conduit/servers/servers_page.dart' as _i8;
import 'package:conduit/servers/sessions_page.dart' as _i10;
import 'package:conduit/servers/settings_page.dart' as _i9;
import 'package:material_ui/material_ui.dart' as _i12;

/// generated route for
/// [_i1.AboutPage]
class AboutRoute extends _i11.PageRouteInfo<void> {
  const AboutRoute({List<_i11.PageRouteInfo>? children})
    : super(AboutRoute.name, initialChildren: children);

  static const String name = 'AboutRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutPage();
    },
  );
}

/// generated route for
/// [_i2.ConnectionsPage]
class ConnectionsRoute extends _i11.PageRouteInfo<void> {
  const ConnectionsRoute({List<_i11.PageRouteInfo>? children})
    : super(ConnectionsRoute.name, initialChildren: children);

  static const String name = 'ConnectionsRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i2.ConnectionsPage();
    },
  );
}

/// generated route for
/// [_i3.GitHubRunDetailPage]
class GitHubRunDetailRoute
    extends _i11.PageRouteInfo<GitHubRunDetailRouteArgs> {
  GitHubRunDetailRoute({
    _i12.Key? key,
    required String owner,
    required String name,
    required int runId,
    required _i13.WorkflowRun run,
    List<_i11.PageRouteInfo>? children,
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

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GitHubRunDetailRouteArgs>();
      return _i3.GitHubRunDetailPage(
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

  final _i12.Key? key;

  final String owner;

  final String name;

  final int runId;

  final _i13.WorkflowRun run;

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
/// [_i2.GithubPage]
class GithubRoute extends _i11.PageRouteInfo<void> {
  const GithubRoute({List<_i11.PageRouteInfo>? children})
    : super(GithubRoute.name, initialChildren: children);

  static const String name = 'GithubRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i2.GithubPage();
    },
  );
}

/// generated route for
/// [_i4.MonitorPage]
class MonitorRoute extends _i11.PageRouteInfo<void> {
  const MonitorRoute({List<_i11.PageRouteInfo>? children})
    : super(MonitorRoute.name, initialChildren: children);

  static const String name = 'MonitorRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i4.MonitorPage();
    },
  );
}

/// generated route for
/// [_i5.PortForwardingPage]
class PortForwardingRoute extends _i11.PageRouteInfo<void> {
  const PortForwardingRoute({List<_i11.PageRouteInfo>? children})
    : super(PortForwardingRoute.name, initialChildren: children);

  static const String name = 'PortForwardingRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i5.PortForwardingPage();
    },
  );
}

/// generated route for
/// [_i6.ServerDetailPage]
class ServerDetailRoute extends _i11.PageRouteInfo<ServerDetailRouteArgs> {
  ServerDetailRoute({
    _i12.Key? key,
    required _i14.Server server,
    bool embedded = false,
    _i12.Widget? header,
    List<_i11.PageRouteInfo>? children,
  }) : super(
         ServerDetailRoute.name,
         args: ServerDetailRouteArgs(
           key: key,
           server: server,
           embedded: embedded,
           header: header,
         ),
         initialChildren: children,
       );

  static const String name = 'ServerDetailRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ServerDetailRouteArgs>();
      return _i6.ServerDetailPage(
        key: args.key,
        server: args.server,
        embedded: args.embedded,
        header: args.header,
      );
    },
  );
}

class ServerDetailRouteArgs {
  const ServerDetailRouteArgs({
    this.key,
    required this.server,
    this.embedded = false,
    this.header,
  });

  final _i12.Key? key;

  final _i14.Server server;

  final bool embedded;

  final _i12.Widget? header;

  @override
  String toString() {
    return 'ServerDetailRouteArgs{key: $key, server: $server, embedded: $embedded, header: $header}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ServerDetailRouteArgs) return false;
    return key == other.key &&
        server == other.server &&
        embedded == other.embedded &&
        header == other.header;
  }

  @override
  int get hashCode =>
      key.hashCode ^ server.hashCode ^ embedded.hashCode ^ header.hashCode;
}

/// generated route for
/// [_i7.ServerWorkspacePage]
class ServerWorkspaceRoute extends _i11.PageRouteInfo<void> {
  const ServerWorkspaceRoute({List<_i11.PageRouteInfo>? children})
    : super(ServerWorkspaceRoute.name, initialChildren: children);

  static const String name = 'ServerWorkspaceRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i7.ServerWorkspacePage();
    },
  );
}

/// generated route for
/// [_i8.ServersPage]
class ServersRoute extends _i11.PageRouteInfo<void> {
  const ServersRoute({List<_i11.PageRouteInfo>? children})
    : super(ServersRoute.name, initialChildren: children);

  static const String name = 'ServersRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i8.ServersPage();
    },
  );
}

/// generated route for
/// [_i9.SettingsPage]
class SettingsRoute extends _i11.PageRouteInfo<void> {
  const SettingsRoute({List<_i11.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i9.SettingsPage();
    },
  );
}

/// generated route for
/// [_i10.TerminalPage]
class TerminalRoute extends _i11.PageRouteInfo<void> {
  const TerminalRoute({List<_i11.PageRouteInfo>? children})
    : super(TerminalRoute.name, initialChildren: children);

  static const String name = 'TerminalRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i10.TerminalPage();
    },
  );
}
