import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'server_connection_actions.dart';
import 'server_providers.dart';
import 'ssh_config_bulk.dart';
import 'ssh_config_sync.dart' hide sshConfigAliasFor, tildePath;
import 'ssh_key_setup_dialog.dart';

/// The connection fields the server editor form holds while a key pair is
/// set up or its `Host` entry written, before anything is saved.
typedef ServerEndpoint = ({
  String name,
  String host,
  int port,
  String username,
});

/// A thrown reason the user is shown when key setup cannot proceed.
class SshKeySetupException implements Exception {
  const SshKeySetupException(this.messageKey);

  /// Translation key of the message.
  final String messageKey;

  @override
  String toString() => messageKey.tr();
}

/// The SSH side of the server editor: generating and installing a key pair
/// through whatever route reaches the server (a live session, the jump
/// chain, or a direct dial), and writing the server's `Host` block into the
/// local OpenSSH config.
class SshKeySetupService {
  SshKeySetupService(this._ref);

  final WidgetRef _ref;

  /// Generates a key pair and installs it on the server described by the
  /// form. Returns null when the user cancels or the transport could not be
  /// brought up (a message has been shown in that case).
  ///
  /// [serverId] is the saved server being edited, when any; [jumpHostServerId]
  /// and [proxied] describe the route the form currently configures.
  Future<SshKeySetupResult?> setUpKeyPair(
    BuildContext context, {
    required ServerEndpoint endpoint,
    int? serverId,
    int? jumpHostServerId,
    bool proxied = false,
    String? initialPassword,
  }) async {
    final transport = await _resolveTransport(
      context,
      endpoint: endpoint,
      serverId: serverId,
      jumpHostServerId: jumpHostServerId,
      proxied: proxied,
    );
    if (transport == null || !context.mounted) return null;
    return showSshKeySetupDialog(
      context,
      serverName: endpoint.name,
      host: endpoint.host,
      port: endpoint.port,
      username: endpoint.username,
      initialPassword: initialPassword,
      sessionClient: transport.sessionClient,
      dialSocket: transport.dialSocket,
    );
  }

  /// A live session (present when editing an already-connected server)
  /// carries the install through jump hosts and proxies, which the dialog's
  /// direct dial cannot reach. Without one, the jump chain is connected
  /// first; a saved server is then brought up itself, an unsaved draft is
  /// dialled through the jump host's client.
  Future<
    ({SSHClient? sessionClient, Future<SSHSocket> Function()? dialSocket})?
  >
  _resolveTransport(
    BuildContext context, {
    required ServerEndpoint endpoint,
    required int? serverId,
    required int? jumpHostServerId,
    required bool proxied,
  }) async {
    final manager = _ref.read(connectionManagerProvider);
    var sessionClient = serverId == null ? null : manager.clientFor(serverId);
    if (sessionClient != null || (jumpHostServerId == null && !proxied)) {
      return (sessionClient: sessionClient, dialSocket: null);
    }
    if (serverId != null) {
      final server = await _serverById(serverId);
      if (server == null || !context.mounted) return null;
      if (!await _connectWithProgress(context, server)) return null;
      sessionClient = manager.clientFor(serverId);
      return sessionClient == null
          ? null
          : (sessionClient: sessionClient, dialSocket: null);
    }
    if (jumpHostServerId == null) {
      // An unsaved draft that needs a proxy has no dialable path yet.
      throw const SshKeySetupException('sshKeyConnectFirst');
    }
    final jumpServer = await _serverById(jumpHostServerId);
    if (jumpServer == null || !context.mounted) return null;
    if (manager.clientFor(jumpServer.id) == null &&
        !await _connectWithProgress(context, jumpServer)) {
      return null;
    }
    final jumpClient = manager.clientFor(jumpHostServerId);
    if (jumpClient == null) return null;
    return (
      sessionClient: null,
      dialSocket: () => jumpClient.forwardLocal(endpoint.host, endpoint.port),
    );
  }

  Future<Server?> _serverById(int id) async =>
      (await _ref.read(serverRepositoryProvider).all())
          .where((server) => server.id == id)
          .firstOrNull;

  Future<bool> _connectWithProgress(BuildContext context, Server server) async {
    final loading = showConduitLoadingModal(
      context,
      message: 'commonConnecting'.tr(),
    );
    try {
      return await connectForStatistics(context, _ref, server);
    } finally {
      loading.dismiss();
    }
  }

  /// Writes or updates the server's `Host` entry in the local ssh config and
  /// returns the alias and the config path written.
  ///
  /// A private key that only lives in the form/vault is first exported to
  /// the local key directory (mode 600) so `IdentityFile` can point at it;
  /// [localPrivateKeyPath] short-circuits that when the key was generated in
  /// this editing session. The exported path is reported back through
  /// [onKeyExported] so later syncs reuse it.
  Future<(String alias, String path)> syncToSshConfig({
    required ServerEndpoint endpoint,
    String? privateKey,
    String? localPrivateKeyPath,
    void Function(String path)? onKeyExported,
  }) async {
    final alias = sshConfigAliasFor(endpoint.name);
    final config = _ref.read(sshKeyStorageConfigProvider);
    String? identityFile;
    if (privateKey != null && privateKey.isNotEmpty) {
      var path = localPrivateKeyPath;
      if (path == null) {
        path = await _ref
            .read(sshKeyServiceProvider)
            .ensurePrivateKeyFile(
              privateKey: privateKey,
              fileStem: sshKeyFileStemFor(endpoint.name, null),
              config: config,
            );
        onKeyExported?.call(path);
      }
      identityFile = tildePathFor(path);
    }
    final written = await syncSshConfigFile(
      SshConfigEntry(
        alias: alias,
        hostName: endpoint.host,
        user: endpoint.username,
        port: endpoint.port,
        identityFile: identityFile,
      ),
      configPath: config.sshConfigPath,
    );
    return (alias, written);
  }
}
