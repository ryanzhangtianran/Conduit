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

/// Generates SSH key pairs with the system `ssh-keygen`, installs the public
/// half on a server over a password-authenticated session, and owns the
/// private-key files under the configured key directory.
///
/// The vault copy of a private key is the source of truth; the file on disk
/// is a derived artefact that exists so the system `ssh` (via the synced
/// `~/.ssh/config`) can use the same key. Its location is deterministic —
/// [privateKeyPathFor] derives it from the server name and key type — so the
/// file is found again without scanning the directory, and re-exporting the
/// vault copy simply rewrites that one path.
class SshKeyService {
  const SshKeyService();

  /// Turns a server name into a safe key file stem, e.g.
  /// `conduit_prod-db_ed25519`; without a [type] the suffix is omitted.
  static String fileStemFor(String serverName, SshKeyType? type) {
    final slug = serverName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final stem = 'conduit_${slug.isEmpty ? 'server' : slug}';
    return type == null ? stem : '${stem}_${type.keygenName}';
  }

  /// The private-key file for [serverName]'s key of [type] inside the
  /// configured key directory. Used by [generate] and by every export of the
  /// vault copy; the public key lives next to it with a `.pub` suffix.
  static String privateKeyPathFor(
    String serverName,
    SshKeyType? type,
    SshKeyStorageConfig config,
  ) => _pathFor(fileStemFor(serverName, type), config);

  /// The algorithm of an OpenSSH private key, or null when the key cannot be
  /// parsed (foreign format, or encrypted with a passphrase other than
  /// [passphrase]).
  static SshKeyType? keyTypeOf(String privateKey, {String? passphrase}) {
    try {
      final pairs = SSHKeyPair.fromPem(privateKey, passphrase);
      if (pairs.isEmpty) return null;
      final type = pairs.first.type;
      if (type == 'ssh-ed25519') return SshKeyType.ed25519;
      if (type == 'ssh-rsa') return SshKeyType.rsa;
      if (type.startsWith('ecdsa-sha2-')) return SshKeyType.ecdsa;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Runs `ssh-keygen`, writes the private key (0600) to
  /// [privateKeyPathFor] and the public key (0644) next to it, creating the
  /// directory (0700) as needed. One pair exists per path: regenerating
  /// replaces the previous pair (its public key is returned in
  /// [GeneratedSshKeyPair.previousPublicKey] so the server copy can be
  /// dropped) instead of piling up suffixed duplicates.
  Future<GeneratedSshKeyPair> generate({
    required SshKeyType type,
    required String serverName,
    required String comment,
    required SshKeyStorageConfig config,
    String? passphrase,
  }) async {
    final privatePath = privateKeyPathFor(serverName, type, config);
    await _prepareDirectory(privatePath);
    final publicPath = '$privatePath.pub';

    // Capture and remove the pair being replaced, if any — including pairs
    // from the era when private keys carried a .pem extension.
    String? previousPublicKey;
    final oldPublic = File(publicPath);
    if (await oldPublic.exists()) {
      previousPublicKey = (await oldPublic.readAsString()).trim();
      await oldPublic.delete();
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

  /// Makes sure the file at [fileStem] (see [fileStemFor]) inside the key
  /// directory holds [privateKey], mode 600, and returns its path.
  ///
  /// The vault copy wins: a file already holding the key is left alone (a
  /// pair written by [generate] keeps its `.pub`), any other content is
  /// overwritten and a now-stale `.pub` next to it removed.
  Future<String> ensurePrivateKeyFile({
    required String privateKey,
    required String fileStem,
    required SshKeyStorageConfig config,
  }) async {
    final path = _pathFor(fileStem, config);
    await _prepareDirectory(path);
    final file = File(path);
    final content = privateKey.endsWith('\n') ? privateKey : '$privateKey\n';
    if (await file.exists()) {
      try {
        if ((await file.readAsString()).trim() == privateKey.trim()) {
          return path;
        }
      } catch (_) {
        // Unreadable content is replaced below.
      }
      final stalePublic = File('$path.pub');
      if (await stalePublic.exists()) await stalePublic.delete();
    }
    await file.writeAsString(content, flush: true);
    await _chmod('600', path);
    return path;
  }

  static String _pathFor(String fileStem, SshKeyStorageConfig config) =>
      '${expandLocalPath(config.localPrivateKeyDirectory)}/$fileStem';

  /// Creates the key directory of [path] (0700) when missing.
  Future<void> _prepareDirectory(String path) async {
    final directory = File(path).parent;
    await directory.create(recursive: true);
    await _chmod('700', directory.path);
  }

  /// Connects with [password] and installs [publicKey]: the directory holding
  /// `authorized_keys` is created (0700) and the key line appended to the file
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
    required SshKeyStorageConfig config,
    String? replacesPublicKey,
  }) async {
    final session = await client.execute(
      buildInstallScript(
        publicKey: publicKey,
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
    required SshKeyStorageConfig config,
    String? replacesPublicKey,
  }) {
    final authorizedKeys = _remotePath(config.remoteAuthorizedKeysPath);
    final key = _singleQuote(publicKey.trim());
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
ak=$authorizedKeys
akdir="\$(dirname "\$ak")"
key=$key
mkdir -p "\$akdir" && chmod 700 "\$akdir"
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
