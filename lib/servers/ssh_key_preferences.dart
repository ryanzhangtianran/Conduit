import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

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
    this.localPublicKeyDirectory = '~/.ssh',
    this.remoteKeyDirectory = '~/.ssh',
    this.remoteAuthorizedKeysPath = '~/.ssh/authorized_keys',
    this.defaultKeyType = SshKeyType.ed25519,
    this.sshConfigPath = '~/.ssh/config',
  });

  final String localPrivateKeyDirectory;
  final String localPublicKeyDirectory;
  final String remoteKeyDirectory;
  final String remoteAuthorizedKeysPath;
  final SshKeyType defaultKeyType;

  /// Local OpenSSH client config that "sync to ssh config" writes to.
  final String sshConfigPath;

  SshKeyStorageConfig copyWith({
    String? localPrivateKeyDirectory,
    String? localPublicKeyDirectory,
    String? remoteKeyDirectory,
    String? remoteAuthorizedKeysPath,
    SshKeyType? defaultKeyType,
    String? sshConfigPath,
  }) => SshKeyStorageConfig(
    localPrivateKeyDirectory:
        localPrivateKeyDirectory ?? this.localPrivateKeyDirectory,
    localPublicKeyDirectory:
        localPublicKeyDirectory ?? this.localPublicKeyDirectory,
    remoteKeyDirectory: remoteKeyDirectory ?? this.remoteKeyDirectory,
    remoteAuthorizedKeysPath:
        remoteAuthorizedKeysPath ?? this.remoteAuthorizedKeysPath,
    defaultKeyType: defaultKeyType ?? this.defaultKeyType,
    sshConfigPath: sshConfigPath ?? this.sshConfigPath,
  );

  @override
  bool operator ==(Object other) =>
      other is SshKeyStorageConfig &&
      other.localPrivateKeyDirectory == localPrivateKeyDirectory &&
      other.localPublicKeyDirectory == localPublicKeyDirectory &&
      other.remoteKeyDirectory == remoteKeyDirectory &&
      other.remoteAuthorizedKeysPath == remoteAuthorizedKeysPath &&
      other.defaultKeyType == defaultKeyType &&
      other.sshConfigPath == sshConfigPath;

  @override
  int get hashCode => Object.hash(
    localPrivateKeyDirectory,
    localPublicKeyDirectory,
    remoteKeyDirectory,
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

abstract interface class SshKeySettings {
  SshKeyStorageConfig get config;

  Future<void> saveConfig(SshKeyStorageConfig config);
}

class SshKeyPreferences implements SshKeySettings {
  SshKeyPreferences(this._preferences, this.config);

  static const _localPrivateKey = 'ssh_key_local_private_dir';
  static const _localPublicKey = 'ssh_key_local_public_dir';
  static const _remoteDirKey = 'ssh_key_remote_dir';
  static const _remoteAuthorizedKeysKey = 'ssh_key_remote_authorized_keys';
  static const _defaultTypeKey = 'ssh_key_default_type';
  static const _configPathKey = 'ssh_key_config_path';

  final SharedPreferencesAsync _preferences;
  @override
  SshKeyStorageConfig config;

  static Future<SshKeyPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    const defaults = SshKeyStorageConfig();
    final typeName = await store.getString(_defaultTypeKey);
    return SshKeyPreferences(
      store,
      SshKeyStorageConfig(
        localPrivateKeyDirectory:
            await store.getString(_localPrivateKey) ??
            defaults.localPrivateKeyDirectory,
        localPublicKeyDirectory:
            await store.getString(_localPublicKey) ??
            defaults.localPublicKeyDirectory,
        remoteKeyDirectory:
            await store.getString(_remoteDirKey) ?? defaults.remoteKeyDirectory,
        remoteAuthorizedKeysPath:
            await store.getString(_remoteAuthorizedKeysKey) ??
            defaults.remoteAuthorizedKeysPath,
        defaultKeyType:
            SshKeyType.values.asNameMap()[typeName] ?? defaults.defaultKeyType,
        sshConfigPath:
            await store.getString(_configPathKey) ?? defaults.sshConfigPath,
      ),
    );
  }

  @override
  Future<void> saveConfig(SshKeyStorageConfig value) async {
    config = value;
    await Future.wait([
      _preferences.setString(_localPrivateKey, value.localPrivateKeyDirectory),
      _preferences.setString(_localPublicKey, value.localPublicKeyDirectory),
      _preferences.setString(_remoteDirKey, value.remoteKeyDirectory),
      _preferences.setString(
        _remoteAuthorizedKeysKey,
        value.remoteAuthorizedKeysPath,
      ),
      _preferences.setString(_defaultTypeKey, value.defaultKeyType.name),
      _preferences.setString(_configPathKey, value.sshConfigPath),
    ]);
  }
}

class InMemorySshKeySettings implements SshKeySettings {
  InMemorySshKeySettings([this.config = const SshKeyStorageConfig()]);

  @override
  SshKeyStorageConfig config;

  @override
  Future<void> saveConfig(SshKeyStorageConfig value) async {
    config = value;
  }
}
