import 'server_models.dart';
import 'server_repository.dart';
import 'ssh_config_sync.dart';
import 'ssh_key_preferences.dart';
import 'ssh_key_service.dart';

/// Writes every saved SSH server into the local OpenSSH config.
///
/// Key-auth servers get an `IdentityFile`: the vaulted key is located in (or
/// exported to) the local key directory via
/// [SshKeyService.ensurePrivateKeyFile]. Password servers keep whatever
/// `IdentityFile` lines their block already has. Returns how many servers
/// were written and the resolved config path.
Future<(int, String)> writeServersToSshConfig({
  required ServerRepository repository,
  required SshKeyService keyService,
  required SshKeyStorageConfig config,
}) async {
  final servers = await repository.all();
  final sshServers = servers
      .where((server) => server.connectionType == ServerConnectionType.ssh.name)
      .toList();
  var path = expandLocalPath(config.sshConfigPath, fallback: '~/.ssh/config');
  for (final server in sshServers) {
    final alias = sshConfigAliasFor(server.name);
    String? identityFile;
    final credential = server.credentialId == null
        ? null
        : await repository.credentialFor(server);
    final privateKey = credential?.privateKey;
    if (credential?.type == CredentialType.privateKey &&
        privateKey != null &&
        privateKey.isNotEmpty) {
      identityFile = tildePath(
        await keyService.ensurePrivateKeyFile(
          privateKey: privateKey,
          fileStem: 'conduit_${alias.toLowerCase()}',
          config: config,
        ),
      );
    }
    path = await syncSshConfigFile(
      SshConfigEntry(
        alias: alias,
        hostName: server.host,
        user: server.username,
        port: server.port,
        identityFile: identityFile,
      ),
      configPath: config.sshConfigPath,
    );
  }
  return (sshServers.length, path);
}
