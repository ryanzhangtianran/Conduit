import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'server_models.dart';
import 'server_providers.dart';
import 'server_repository.dart';
import 'ssh_config_sync.dart';
import 'ssh_key_preferences.dart';
import 'ssh_key_service.dart';

export 'ssh_config_sync.dart' show sshConfigAliasFor;

/// The key-file stem for a server's private key, shared by key generation,
/// the ssh-config sync and the server editor so all three agree on one path
/// (see [SshKeyService.privateKeyPathFor]). [type] is null when the key's
/// algorithm is unknown.
String sshKeyFileStemFor(String serverName, SshKeyType? type) =>
    SshKeyService.fileStemFor(serverName, type);

/// The `~/`-form of [path] for `IdentityFile` lines (see [tildePath]).
String tildePathFor(String path) => tildePath(path);

/// Writes every saved SSH server into the local OpenSSH config.
///
/// Key-auth servers get an `IdentityFile`: the vaulted key is exported to its
/// deterministic file in the local key directory via
/// [SshKeyService.ensurePrivateKeyFile] (an existing identical file is
/// reused). Password servers keep whatever `IdentityFile` lines their block
/// already has. Returns how many servers were written and the resolved
/// config path.
Future<(int, String)> writeServersToSshConfig({
  required ServerRepository repository,
  required SshKeyService keyService,
  required SshKeyStorageConfig config,
}) async {
  final sshServers = await repository.all();
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
      identityFile = tildePathFor(
        await keyService.ensurePrivateKeyFile(
          privateKey: privateKey,
          fileStem: sshKeyFileStemFor(
            server.name,
            SshKeyService.keyTypeOf(
              privateKey,
              passphrase: credential?.keyPassphrase,
            ),
          ),
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

/// The "sync all servers to ssh config" action shared by the settings and
/// connections pages: writes the config, reloads the parsed host list and
/// reports the outcome in a snackbar.
Future<void> syncServersToSshConfig(BuildContext context, WidgetRef ref) async {
  try {
    final (count, path) = await writeServersToSshConfig(
      repository: ref.read(serverRepositoryProvider),
      keyService: ref.read(sshKeyServiceProvider),
      config: ref.read(sshKeyStorageConfigProvider),
    );
    ref.invalidate(sshConfigHostsProvider);
    showStyledSnackBar(
      message: 'assetsSshConfigSyncDone'.tr(args: ['$count', path]),
      icon: Symbols.check_circle,
    );
  } catch (error) {
    if (!context.mounted) return;
    showStyledSnackBar(
      message: 'sshKeyConfigSyncFailed'.tr(args: ['$error']),
      icon: Symbols.warning,
      accentColor: Theme.of(context).colorScheme.error,
    );
  }
}
