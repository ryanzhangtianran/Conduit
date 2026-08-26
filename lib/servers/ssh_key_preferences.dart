import 'dart:io';

/// Key algorithms offered when generating a pair with `ssh-keygen`.
enum SshKeyType {
  ed25519('ed25519', 'Ed25519', <String>[]),
  rsa('rsa', 'RSA 4096', <String>['-b', '4096']),
  ecdsa('ecdsa', 'ECDSA P-256', <String>['-b', '256']);

  const SshKeyType(this.keygenName, this.label, this.extraArguments);

  /// Value passed to `ssh-keygen -t`.
  final String keygenName;
  final String label;

  /// Extra `ssh-keygen` arguments (key size) for this algorithm.
  final List<String> extraArguments;
}

/// Where generated keys are written locally and installed on the server.
///
/// Paths may start with `~/`; [expandLocalPath] resolves it against the
/// local home directory, and the remote installer expands it with `$HOME`.
class SshKeyStorageConfig {
  const SshKeyStorageConfig({
    this.localPrivateKeyDirectory = '~/.ssh',
    this.remoteAuthorizedKeysPath = '~/.ssh/authorized_keys',
    this.defaultKeyType = SshKeyType.ed25519,
    this.sshConfigPath = '~/.ssh/config',
  });

  final String localPrivateKeyDirectory;
  final String remoteAuthorizedKeysPath;
  final SshKeyType defaultKeyType;

  /// Local OpenSSH client config that "sync to ssh config" writes to.
  final String sshConfigPath;

  SshKeyStorageConfig copyWith({
    String? localPrivateKeyDirectory,
    String? remoteAuthorizedKeysPath,
    SshKeyType? defaultKeyType,
    String? sshConfigPath,
  }) => SshKeyStorageConfig(
    localPrivateKeyDirectory:
        localPrivateKeyDirectory ?? this.localPrivateKeyDirectory,
    remoteAuthorizedKeysPath:
        remoteAuthorizedKeysPath ?? this.remoteAuthorizedKeysPath,
    defaultKeyType: defaultKeyType ?? this.defaultKeyType,
    sshConfigPath: sshConfigPath ?? this.sshConfigPath,
  );

  @override
  bool operator ==(Object other) =>
      other is SshKeyStorageConfig &&
      other.localPrivateKeyDirectory == localPrivateKeyDirectory &&
      other.remoteAuthorizedKeysPath == remoteAuthorizedKeysPath &&
      other.defaultKeyType == defaultKeyType &&
      other.sshConfigPath == sshConfigPath;

  @override
  int get hashCode => Object.hash(
    localPrivateKeyDirectory,
    remoteAuthorizedKeysPath,
    defaultKeyType,
    sshConfigPath,
  );
}

/// Expands a leading `~` against the local home directory. Blank input
/// falls back to [fallback].
String expandLocalPath(String path, {String fallback = '~/.ssh'}) {
  final trimmed = path.trim().isEmpty ? fallback : path.trim();
  if (trimmed == '~' || trimmed.startsWith('~/')) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return trimmed == '~' ? home : '$home${trimmed.substring(1)}';
    }
  }
  return trimmed;
}
