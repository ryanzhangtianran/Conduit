import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'server_models.dart' show HostKeyPrompt;
import 'ssh_connection_manager.dart' show HostKeyApproval;
import 'ssh_key_preferences.dart';

/// A key pair written to disk by [SshKeyService.generate].
class GeneratedSshKeyPair {
  const GeneratedSshKeyPair({
    required this.type,
    required this.privateKeyPath,
    required this.publicKeyPath,
    required this.privateKey,
    required this.publicKey,
    this.previousPublicKey,
  });

  final SshKeyType type;
  final String privateKeyPath;
  final String publicKeyPath;

  /// OpenSSH PEM private key, as stored in the credential vault.
  final String privateKey;

  /// Single `authorized_keys` line (`type base64 comment`).
  final String publicKey;

  /// The pair this generation replaced (same server and type), so the
  /// install can drop its stale `authorized_keys` line.
  final String? previousPublicKey;
}

class SshKeyException implements Exception {
  const SshKeyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Generates SSH key pairs with the system `ssh-keygen` and installs the
/// public half on a server over a password-authenticated session.
class SshKeyService {
  const SshKeyService();

  /// Turns a server name into a safe key file stem, e.g. `conduit_prod-db`.
  static String fileStemFor(String serverName, SshKeyType type) {
    final slug = serverName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'conduit_${slug.isEmpty ? 'server' : slug}_${type.keygenName}';
  }

  /// Runs `ssh-keygen`, writes the private key (0600) to the configured
  /// private directory and the public key (0644) to the public directory,
  /// creating directories (0700) as needed. One pair exists per file stem:
  /// regenerating replaces the previous pair (its public key is returned in
  /// [GeneratedSshKeyPair.previousPublicKey] so the server copy can be
  /// dropped) instead of piling up suffixed duplicates.
  Future<GeneratedSshKeyPair> generate({
    required SshKeyType type,
    required String fileStem,
    required String comment,
    required SshKeyStorageConfig config,
    String? passphrase,
  }) async {
    final privateDir = Directory(
      expandLocalPath(config.localPrivateKeyDirectory),
    );
    final publicDir = Directory(
      expandLocalPath(config.localPublicKeyDirectory),
    );
    await privateDir.create(recursive: true);
    await publicDir.create(recursive: true);
    await _chmod('700', privateDir.path);

    final privatePath = '${privateDir.path}/$fileStem';
    final publicPath = '${publicDir.path}/$fileStem.pub';

    // Capture and remove the pair being replaced, if any — including pairs
    // from the era when private keys carried a .pem extension.
    String? previousPublicKey;
    for (final path in [publicPath, '${privateDir.path}/$fileStem.pub']) {
      final oldPublic = File(path);
      if (await oldPublic.exists()) {
        previousPublicKey ??= (await oldPublic.readAsString()).trim();
        await oldPublic.delete();
      }
    }
    for (final path in [privatePath, '$privatePath.pem']) {
      final oldPrivate = File(path);
      if (await oldPrivate.exists()) await oldPrivate.delete();
    }

    final result = await Process.run('ssh-keygen', [
      '-q',
      '-t',
      type.keygenName,
      ...type.extraArguments,
      '-N',
      passphrase ?? '',
      '-C',
      comment,
      '-f',
      privatePath,
    ]);
    if (result.exitCode != 0) {
      throw SshKeyException(
        'ssh-keygen failed (${result.exitCode}): '
        '${(result.stderr as String).trim()}',
      );
    }

    // ssh-keygen always writes `<private>.pub`; relocate it when the
    // public directory differs.
    final generatedPublic = File('$privatePath.pub');
    if (generatedPublic.path != publicPath) {
      await generatedPublic.rename(publicPath);
    }
    await _chmod('600', privatePath);
    await _chmod('644', publicPath);

    return GeneratedSshKeyPair(
      type: type,
      privateKeyPath: privatePath,
      publicKeyPath: publicPath,
      privateKey: await File(privatePath).readAsString(),
      publicKey: (await File(publicPath).readAsString()).trim(),
      previousPublicKey: previousPublicKey == '' ? null : previousPublicKey,
    );
  }

  /// Writes an existing private key (e.g. from the vault) into the local
  /// private key directory with mode 600 so the system ssh can reference it.
  /// Never overwrites: a numeric suffix is appended when the name is taken.
  Future<String> writePrivateKeyFile({
    required String privateKey,
    required String fileStem,
    required SshKeyStorageConfig config,
  }) async {
    final dir = Directory(expandLocalPath(config.localPrivateKeyDirectory));
    await dir.create(recursive: true);
    await _chmod('700', dir.path);
    final path = _uniquePath(dir.path, fileStem, '');
    final content = privateKey.endsWith('\n') ? privateKey : '$privateKey\n';
    await File(path).writeAsString(content, flush: true);
    await _chmod('600', path);
    return path;
  }

  /// Returns a local file holding [privateKey], reusing any file in the key
  /// directory with the same content (a generated key or an earlier export)
  /// before writing a new [fileStem] file. Keeps repeated syncs from piling
  /// up duplicate copies of one key.
  Future<String> ensurePrivateKeyFile({
    required String privateKey,
    required String fileStem,
    required SshKeyStorageConfig config,
  }) async {
    final dir = Directory(expandLocalPath(config.localPrivateKeyDirectory));
    final normalized = privateKey.trim();
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is! File || entity.path.endsWith('.pub')) continue;
        try {
          if (await entity.length() > 64 * 1024) continue;
          if ((await entity.readAsString()).trim() == normalized) {
            return entity.path;
          }
        } catch (_) {
          // Unreadable or non-text entries (sockets, foreign keys) are
          // skipped; a new file is written below if nothing matches.
        }
      }
    }
    return writePrivateKeyFile(
      privateKey: privateKey,
      fileStem: fileStem,
      config: config,
    );
  }

  /// Connects with [password] and installs [publicKey]: the remote key
  /// directory is created (0700), the public key written there as
  /// `<fileName>.pub` (0644), and the line appended to `authorized_keys`
  /// (0600) unless already present.
  ///
  /// Connects directly to [host]; per-server proxies and jump hosts are not
  /// applied to this one-off installation session.
  Future<void> installPublicKey({
    required String host,
    required int port,
    required String username,
    required String password,
    required String publicKey,
    required String fileName,
    required SshKeyStorageConfig config,
    required HostKeyApproval approve,
    String? knownHostKeyFingerprint,
    SSHClient? session,
    Future<SSHSocket> Function()? dial,
    String? replacesPublicKey,
  }) async {
    // An existing session (jump-host or proxied servers connect through the
    // connection manager, which this one-off dial cannot reproduce) is
    // reused as-is and left open.
    if (session != null) {
      await _runInstallScript(
        session,
        publicKey: publicKey,
        fileName: fileName,
        config: config,
        replacesPublicKey: replacesPublicKey,
      );
      return;
    }
    // A jump-host reachable target dials through the jump session's
    // direct-tcpip channel instead of a raw TCP connection.
    final socket = dial != null
        ? await dial()
        : await SSHSocket.connect(
            host,
            port,
            timeout: const Duration(seconds: 15),
          );
    final client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
      onUserInfoRequest: (request) =>
          List<String>.filled(request.prompts.length, password),
      onVerifyHostKey: (algorithm, fingerprint) {
        final presented =
            'SHA256:${base64Encode(fingerprint).replaceAll('=', '')}';
        if (knownHostKeyFingerprint == presented) return true;
        return approve(
          HostKeyPrompt(
            algorithm: algorithm,
            fingerprint: presented,
            replacesExisting: knownHostKeyFingerprint != null,
          ),
        );
      },
      handshakeTimeout: const Duration(seconds: 15),
      authTimeout: const Duration(seconds: 15),
      ident: 'Conduit',
    );
    try {
      await client.authenticated;
      await _runInstallScript(
        client,
        publicKey: publicKey,
        fileName: fileName,
        config: config,
        replacesPublicKey: replacesPublicKey,
      );
    } finally {
      client.close();
      await client.done.catchError((_) {});
    }
  }

  Future<void> _runInstallScript(
    SSHClient client, {
    required String publicKey,
    required String fileName,
    required SshKeyStorageConfig config,
    String? replacesPublicKey,
  }) async {
    final session = await client.execute(
      buildInstallScript(
        publicKey: publicKey,
        fileName: fileName,
        config: config,
        replacesPublicKey: replacesPublicKey,
      ),
    );
    final stderr = utf8.decoder.bind(session.stderr).join();
    await utf8.decoder.bind(session.stdout).drain<void>();
    await session.done;
    final exitCode = session.exitCode ?? 1;
    if (exitCode != 0) {
      throw SshKeyException(
        'Installing the public key failed ($exitCode): '
        '${(await stderr).trim()}',
      );
    }
  }

  /// The POSIX `sh` script run on the server. Paths starting with `~/` are
  /// expanded with `$HOME` on the remote side.
  static String buildInstallScript({
    required String publicKey,
    required String fileName,
    required SshKeyStorageConfig config,
    String? replacesPublicKey,
  }) {
    final dir = _remotePath(config.remoteKeyDirectory);
    final authorizedKeys = _remotePath(config.remoteAuthorizedKeysPath);
    final key = _singleQuote(publicKey.trim());
    final name = _singleQuote(fileName);
    final replaced = replacesPublicKey?.trim();
    final dropReplaced = replaced == null || replaced.isEmpty
        ? ''
        : '''
old=${_singleQuote(replaced)}
grep -vxF "\$old" "\$ak" > "\$ak.conduit-tmp" || true
mv "\$ak.conduit-tmp" "\$ak"
''';
    return '''
set -e
umask 077
dir=$dir
ak=$authorizedKeys
key=$key
mkdir -p "\$dir" && chmod 700 "\$dir"
printf '%s\\n' "\$key" > "\$dir/"$name.pub && chmod 644 "\$dir/"$name.pub
mkdir -p "\$(dirname "\$ak")"
touch "\$ak"
$dropReplaced
grep -qxF "\$key" "\$ak" || printf '%s\\n' "\$key" >> "\$ak"
chmod 600 "\$ak"
''';
  }

  /// Quotes a remote path for `sh`, letting a leading `~/` expand via
  /// `$HOME` while the rest stays literal.
  static String _remotePath(String path) {
    final trimmed = path.trim();
    if (trimmed == '~') return '"\$HOME"';
    if (trimmed.startsWith('~/')) {
      return '"\$HOME"${_singleQuote(trimmed.substring(1))}';
    }
    return _singleQuote(trimmed);
  }

  static String _singleQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  static String _uniquePath(String directory, String stem, String suffix) {
    var candidate = '$directory/$stem$suffix';
    var counter = 1;
    while (FileSystemEntity.typeSync(candidate) !=
            FileSystemEntityType.notFound ||
        (suffix.isEmpty &&
            FileSystemEntity.typeSync('$candidate.pub') !=
                FileSystemEntityType.notFound)) {
      candidate = '$directory/$stem-$counter$suffix';
      counter++;
    }
    return candidate;
  }

  static Future<void> _chmod(String mode, String path) async {
    if (Platform.isWindows) return;
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw SshKeyException(
        'chmod $mode $path failed: ${(result.stderr as String).trim()}',
      );
    }
  }
}
