import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:conduit/data/local/app_database.dart';

import 'vault_service.dart';

class DatabaseBackupService {
  DatabaseBackupService(this._database, this._vault);

  static const _formatVersion = 3;

  final AppDatabase _database;
  final VaultService _vault;

  Future<String> exportArchive(String password) async {
    return _vault.encryptPortable(await exportPayload(), password);
  }

  /// Produces the clear-text, versioned database payload before it is encrypted
  /// with the vault passphrase. It must never be persisted or sent over the
  /// network without [exportArchive].
  Future<String> exportPayload() async {
    final archive = await _payload();
    archive['createdAt'] = DateTime.now().toUtc().toIso8601String();
    return jsonEncode(archive);
  }

  Future<Map<String, Object?>> _payload() async {
    final servers = await _database.select(_database.servers).get();
    final credentials = await _database
        .select(_database.savedCredentials)
        .get();
    final serverRecords = <Map<String, dynamic>>[];
    for (final server in servers) {
      final record = server.toJson()
        ..remove('encryptedCredential')
        ..remove('credentialNonce')
        ..remove('encryptedProxyPassword')
        ..remove('proxyPasswordNonce');
      if (server.encryptedCredential != null &&
          server.credentialNonce != null) {
        record['credential'] = await _vault.decrypt(
          EncryptedValue(
            bytes: server.encryptedCredential!,
            nonce: server.credentialNonce!,
          ),
          context: 'server-credential',
        );
      }
      if (server.encryptedProxyPassword != null &&
          server.proxyPasswordNonce != null) {
        record['proxyPassword'] = await _vault.decrypt(
          EncryptedValue(
            bytes: server.encryptedProxyPassword!,
            nonce: server.proxyPasswordNonce!,
          ),
          context: 'server-proxy-password',
        );
      }
      serverRecords.add(record);
    }
    final credentialRecords = <Map<String, dynamic>>[];
    for (final credential in credentials) {
      final record = credential.toJson()
        ..remove('encryptedCredential')
        ..remove('credentialNonce');
      record['credential'] = await _vault.decrypt(
        EncryptedValue(
          bytes: credential.encryptedCredential,
          nonce: credential.credentialNonce,
        ),
        context: 'server-credential',
      );
      credentialRecords.add(record);
    }
    final githubTokenRecords = <Map<String, dynamic>>[];
    for (final token in await _database.select(_database.gitHubTokens).get()) {
      final record = token.toJson()
        ..remove('encryptedToken')
        ..remove('tokenNonce');
      record['token'] = await _vault.decrypt(
        EncryptedValue(bytes: token.encryptedToken, nonce: token.tokenNonce),
        context: 'github-token',
      );
      githubTokenRecords.add(record);
    }

    final archive = <String, Object?>{
      'version': _formatVersion,
      'servers': serverRecords,
      'savedCredentials': credentialRecords,
      // GitHub metadata and vault-encrypted access tokens sync with the
      // vault; tokens are decrypted only while the archive is assembled and
      // re-encrypted with the destination vault key during import.
      'githubConnections':
          (await _database.select(_database.gitHubConnections).get())
              .map((record) => record.toJson())
              .toList(),
      'githubRepoPins': (await _database.select(_database.gitHubRepoPins).get())
          .map((record) => record.toJson())
          .toList(),
      'githubTokens': githubTokenRecords,
    };
    return archive;
  }

  /// Replaces the portable database content while retaining this device's
  /// vault metadata and biometric setting.
  Future<void> importArchive(String archive, String password) async {
    final clearText = await _vault.decryptPortable(archive, password);
    await importPayload(clearText);
  }

  /// Replaces the syncable database content after archive decryption.
  Future<void> importPayload(String clearText) async {
    final payload = jsonDecode(clearText);
    if (payload is! Map<String, dynamic> ||
        payload['version'] != _formatVersion) {
      throw const FormatException('Unsupported Conduit backup.');
    }

    final servers = _records(payload, 'servers');
    final credentials = _records(payload, 'savedCredentials');
    // Optional keys: archives written before the GitHub integration carry no
    // GitHub metadata, which imports as an empty connection state. Tokens
    // joined the archive later and are optional too; a connection imported
    // without one simply needs a new sign-in.
    final githubConnections = _recordsOrEmpty(payload, 'githubConnections');
    final githubRepoPins = _recordsOrEmpty(payload, 'githubRepoPins');
    final githubTokens = _recordsOrEmpty(payload, 'githubTokens');

    await _database.transaction(() async {
      await _database.delete(_database.gitHubRepoPins).go();
      await _database.delete(_database.gitHubConnections).go();
      await _database.delete(_database.gitHubTokens).go();
      await _database.delete(_database.servers).go();
      await _database.delete(_database.savedCredentials).go();

      for (final record in credentials) {
        // The archive intentionally excludes these device-specific fields.
        // `SavedCredential.fromJson` cannot be used here because its database
        // representation requires them, even though we replace them below.
        final credential = SavedCredential.fromJson({
          ...record,
          'encryptedCredential': '',
          'credentialNonce': '',
        });
        final clearText = record['credential'];
        if (clearText is! String) {
          throw const FormatException('Invalid saved credential.');
        }
        final encrypted = await _vault.encrypt(
          clearText,
          context: 'server-credential',
        );
        await _database
            .into(_database.savedCredentials)
            .insert(
              SavedCredentialsCompanion(
                id: Value(credential.id),
                name: Value(credential.name),
                credentialType: Value(credential.credentialType),
                encryptedCredential: Value(encrypted.bytes),
                credentialNonce: Value(encrypted.nonce),
                createdAt: Value(credential.createdAt),
                updatedAt: Value(credential.updatedAt),
              ),
            );
      }

      for (final record in servers) {
        // Backups written before the serial-port feature omit the
        // connectionType key; those servers were SSH by definition.
        final server = Server.fromJson({
          ...record,
          'connectionType': record['connectionType'] ?? 'ssh',
        });
        final credential = record['credential'];
        final encrypted = credential is String
            ? await _vault.encrypt(credential, context: 'server-credential')
            : null;
        final proxyPassword = record['proxyPassword'];
        final encryptedProxyPassword = proxyPassword is String
            ? await _vault.encrypt(
                proxyPassword,
                context: 'server-proxy-password',
              )
            : null;
        await _database
            .into(_database.servers)
            .insert(
              ServersCompanion(
                id: Value(server.id),
                name: Value(server.name),
                host: Value(server.host),
                port: Value(server.port),
                username: Value(server.username),
                lastConnectedAt: Value(server.lastConnectedAt),
                syncId: Value(server.syncId),
                createdAt: Value(server.createdAt),
                updatedAt: Value(server.updatedAt),
                deletedAt: Value(server.deletedAt),
                credentialType: Value(server.credentialType),
                encryptedCredential: Value(encrypted?.bytes),
                credentialNonce: Value(encrypted?.nonce),
                credentialId: Value(server.credentialId),
                hostKeyAlgorithm: Value(server.hostKeyAlgorithm),
                hostKeyFingerprint: Value(server.hostKeyFingerprint),
                collectStats: Value(server.collectStats),
                collectSystemInfo: Value(server.collectSystemInfo),
                proxyType: Value(server.proxyType),
                proxyHost: Value(server.proxyHost),
                proxyPort: Value(server.proxyPort),
                proxyUsername: Value(server.proxyUsername),
                encryptedProxyPassword: Value(encryptedProxyPassword?.bytes),
                proxyPasswordNonce: Value(encryptedProxyPassword?.nonce),
                jumpHostServerId: Value(server.jumpHostServerId),
                environment: Value(server.environment),
                tags: Value(server.tags),
                connectionType: Value(server.connectionType),
                serialConfig: Value(server.serialConfig),
                sortOrder: Value(server.sortOrder),
              ),
            );
      }
      for (final record in githubConnections) {
        await _database
            .into(_database.gitHubConnections)
            .insert(GitHubConnection.fromJson(record).toCompanion(false));
      }
      for (final record in githubRepoPins) {
        await _database
            .into(_database.gitHubRepoPins)
            .insert(GitHubRepoPin.fromJson(record).toCompanion(false));
      }
      for (final record in githubTokens) {
        // The archive carries the clear token (the whole archive is encrypted
        // with the vault passphrase); re-encrypt it with this vault's data
        // key, mirroring the saved-credential import.
        final clearToken = record['token'];
        if (clearToken is! String) {
          throw const FormatException('Invalid GitHub token.');
        }
        final token = GitHubToken.fromJson({
          ...record,
          'encryptedToken': '',
          'tokenNonce': '',
        });
        final encrypted = await _vault.encrypt(
          clearToken,
          context: 'github-token',
        );
        await _database
            .into(_database.gitHubTokens)
            .insert(
              GitHubTokensCompanion(
                id: Value(token.id),
                accountLogin: Value(token.accountLogin),
                encryptedToken: Value(encrypted.bytes),
                tokenNonce: Value(encrypted.nonce),
                updatedAt: Value(token.updatedAt),
              ),
            );
      }
    });
  }

  List<Map<String, dynamic>> _recordsOrEmpty(
    Map<String, dynamic> payload,
    String key,
  ) {
    final records = payload[key];
    if (records == null) return const [];
    if (records is! List) throw FormatException('Invalid $key in backup.');
    return records.map((record) {
      if (record is! Map) throw FormatException('Invalid $key record.');
      return Map<String, dynamic>.from(record);
    }).toList();
  }

  List<Map<String, dynamic>> _records(
    Map<String, dynamic> payload,
    String key,
  ) {
    final records = payload[key];
    if (records is! List) throw FormatException('Invalid $key in backup.');
    return records.map((record) {
      if (record is! Map) throw FormatException('Invalid $key record.');
      return Map<String, dynamic>.from(record);
    }).toList();
  }
}
