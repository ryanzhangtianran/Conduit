import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:conduit/data/local/app_database.dart';

import 'server_record_codec.dart';
import 'vault_service.dart';

/// Writes and restores the encrypted `.conduit` backup (formerly `.mkb`) of the vault database.
///
/// The clear payload is versioned ([formatVersion]). Every older version is
/// still readable: [importPayload] upgrades the payload in place, one step per
/// version, before restoring it, and only refuses archives written by a newer
/// app. Records are decoded leniently — a key that a later schema added is
/// defaulted, a key of a dropped column is ignored — so a restore never
/// depends on Drift's generated `fromJson`.
///
/// Version history:
/// - 1/2: `servers` carried the clear credential on each server record.
/// - 3: credentials moved to `savedCredentials`, servers link by
///   `credentialId`; GitHub connections, pins and tokens were added later
///   as optional keys.
/// - 4: `portForwardConfigs` (saved forwarding presets) travel with the
///   servers they reference; server records use [ServerRecordCodec]'s full
///   shape.
class DatabaseBackupService {
  DatabaseBackupService(this._database, this._vault);

  static const formatVersion = 4;

  final AppDatabase _database;
  final VaultService _vault;
  final ServerRecordCodec _codec = const ServerRecordCodec();

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
    final serverRecords = <Map<String, Object?>>[];
    for (final server in await _database.select(_database.servers).get()) {
      String? proxyPassword;
      if (server.encryptedProxyPassword != null &&
          server.proxyPasswordNonce != null) {
        proxyPassword = await _vault.decrypt(
          EncryptedValue(
            bytes: server.encryptedProxyPassword!,
            nonce: server.proxyPasswordNonce!,
          ),
          context: 'server-proxy-password',
        );
      }
      serverRecords.add(
        _codec.toRecord(server, redact: false, proxyPassword: proxyPassword),
      );
    }

    final credentialRecords = <Map<String, Object?>>[];
    for (final credential
        in await _database.select(_database.savedCredentials).get()) {
      credentialRecords.add({
        'id': credential.id,
        'name': credential.name,
        'credentialType': credential.credentialType,
        'credential': await _vault.decrypt(
          EncryptedValue(
            bytes: credential.encryptedCredential,
            nonce: credential.credentialNonce,
          ),
          context: 'server-credential',
        ),
        'createdAt': ServerRecordCodec.encodeDateTime(credential.createdAt),
        'updatedAt': ServerRecordCodec.encodeDateTime(credential.updatedAt),
      });
    }

    final forwardRecords = <Map<String, Object?>>[
      for (final config
          in await _database.select(_database.portForwardConfigs).get())
        {
          'id': config.id,
          'serverId': config.serverId,
          'direction': config.direction,
          'kind': config.kind,
          'bindHost': config.bindHost,
          'bindPort': config.bindPort,
          'targetHost': config.targetHost,
          'targetPort': config.targetPort,
          'autoStart': config.autoStart,
          'keepAlive': config.keepAlive,
          'sortOrder': config.sortOrder,
          'createdAt': ServerRecordCodec.encodeDateTime(config.createdAt),
          'updatedAt': ServerRecordCodec.encodeDateTime(config.updatedAt),
        },
    ];

    // GitHub metadata and vault-encrypted access tokens sync with the vault;
    // tokens are decrypted only while the archive is assembled and
    // re-encrypted with the destination vault key during import.
    final githubTokenRecords = <Map<String, Object?>>[];
    for (final token in await _database.select(_database.gitHubTokens).get()) {
      githubTokenRecords.add({
        'id': token.id,
        'accountLogin': token.accountLogin,
        'token': await _vault.decrypt(
          EncryptedValue(bytes: token.encryptedToken, nonce: token.tokenNonce),
          context: 'github-token',
        ),
        'updatedAt': ServerRecordCodec.encodeDateTime(token.updatedAt),
      });
    }

    return {
      'version': formatVersion,
      'servers': serverRecords,
      'savedCredentials': credentialRecords,
      'portForwardConfigs': forwardRecords,
      'githubConnections': [
        for (final connection
            in await _database.select(_database.gitHubConnections).get())
          {
            'id': connection.id,
            'accountLogin': connection.accountLogin,
            'accountName': connection.accountName,
            'avatarUrl': connection.avatarUrl,
            'createdAt': ServerRecordCodec.encodeDateTime(connection.createdAt),
          },
      ],
      'githubRepoPins': [
        for (final pin
            in await _database.select(_database.gitHubRepoPins).get())
          {
            'id': pin.id,
            'connectionId': pin.connectionId,
            'owner': pin.owner,
            'name': pin.name,
            'pinnedAt': ServerRecordCodec.encodeDateTime(pin.pinnedAt),
          },
      ],
      'githubTokens': githubTokenRecords,
    };
  }

  /// Replaces the portable database content while retaining this device's
  /// vault metadata and biometric setting.
  Future<void> importArchive(String archive, String password) async {
    final clearText = await _vault.decryptPortable(archive, password);
    await importPayload(clearText);
  }

  /// Replaces the syncable database content after archive decryption.
  ///
  /// Accepts every payload version up to [formatVersion] (older ones are
  /// upgraded first) and rejects newer ones.
  Future<void> importPayload(String clearText) async {
    final decoded = jsonDecode(clearText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unsupported Conduit backup.');
    }
    final version = decoded['version'];
    if (version is! int || version < 1) {
      throw const FormatException('Unsupported Conduit backup.');
    }
    if (version > formatVersion) {
      throw const FormatException(
        'This backup was written by a newer version of Conduit.',
      );
    }
    final payload = upgradePayload(decoded, version);

    final servers = _records(payload, 'servers');
    final credentials = _records(payload, 'savedCredentials');
    final forwards = _records(payload, 'portForwardConfigs');
    // Optional keys: archives written before the GitHub integration carry no
    // GitHub metadata, which imports as an empty connection state. Tokens
    // joined the archive later and are optional too; a connection imported
    // without one simply needs a new sign-in.
    final githubConnections = _records(payload, 'githubConnections');
    final githubRepoPins = _records(payload, 'githubRepoPins');
    final githubTokens = _records(payload, 'githubTokens');

    await _database.transaction(() async {
      await _database.delete(_database.gitHubRepoPins).go();
      await _database.delete(_database.gitHubConnections).go();
      await _database.delete(_database.gitHubTokens).go();
      await _database.delete(_database.portForwardConfigs).go();
      await _database.delete(_database.servers).go();
      await _database.delete(_database.savedCredentials).go();

      final now = DateTime.now().toUtc();
      for (final record in credentials) {
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
                id: _idOf(record),
                name: Value(ServerRecordCodec.stringOf(record['name'])),
                credentialType: Value(
                  ServerRecordCodec.stringOf(
                    record['credentialType'],
                    fallback: 'password',
                  ),
                ),
                encryptedCredential: Value(encrypted.bytes),
                credentialNonce: Value(encrypted.nonce),
                createdAt: Value(_dateOf(record['createdAt'], now)),
                updatedAt: Value(_dateOf(record['updatedAt'], now)),
              ),
            );
      }

      for (final record in servers) {
        final proxyPassword = _codec.proxyPasswordOf(record);
        await _database
            .into(_database.servers)
            .insert(
              _codec.fromRecord(
                record,
                proxyPassword: proxyPassword == null
                    ? null
                    : await _vault.encrypt(
                        proxyPassword,
                        context: 'server-proxy-password',
                      ),
              ),
            );
      }

      // Presets belong to the archived servers (by id), so they are replaced
      // together: a preset left over from this device would otherwise point
      // at whichever server now owns its old id.
      for (final record in forwards) {
        await _database
            .into(_database.portForwardConfigs)
            .insert(
              PortForwardConfigsCompanion(
                id: _idOf(record),
                serverId: Value(
                  ServerRecordCodec.intOf(record['serverId'], fallback: 0),
                ),
                direction: Value(
                  ServerRecordCodec.stringOf(
                    record['direction'],
                    fallback: 'local',
                  ),
                ),
                kind: Value(
                  ServerRecordCodec.stringOf(record['kind'], fallback: 'tcp'),
                ),
                bindHost: Value(
                  ServerRecordCodec.stringOf(
                    record['bindHost'],
                    fallback: '127.0.0.1',
                  ),
                ),
                bindPort: Value(
                  ServerRecordCodec.intOf(record['bindPort'], fallback: 0),
                ),
                targetHost: Value(
                  ServerRecordCodec.stringOf(record['targetHost']),
                ),
                targetPort: Value(
                  ServerRecordCodec.intOf(record['targetPort'], fallback: 0),
                ),
                autoStart: Value(record['autoStart'] as bool? ?? false),
                keepAlive: Value(record['keepAlive'] as bool? ?? false),
                sortOrder: Value(record['sortOrder'] as int?),
                createdAt: Value(_dateOf(record['createdAt'], now)),
                updatedAt: Value(_dateOf(record['updatedAt'], now)),
              ),
            );
      }

      for (final record in githubConnections) {
        await _database
            .into(_database.gitHubConnections)
            .insert(
              GitHubConnectionsCompanion(
                id: _idOf(record),
                accountLogin: Value(
                  ServerRecordCodec.stringOf(record['accountLogin']),
                ),
                accountName: Value(
                  ServerRecordCodec.stringOf(record['accountName']),
                ),
                avatarUrl: Value(
                  ServerRecordCodec.stringOf(record['avatarUrl']),
                ),
                createdAt: Value(_dateOf(record['createdAt'], now)),
              ),
            );
      }
      for (final record in githubRepoPins) {
        await _database
            .into(_database.gitHubRepoPins)
            .insert(
              GitHubRepoPinsCompanion(
                id: _idOf(record),
                connectionId: Value(
                  ServerRecordCodec.intOf(record['connectionId'], fallback: 0),
                ),
                owner: Value(ServerRecordCodec.stringOf(record['owner'])),
                name: Value(ServerRecordCodec.stringOf(record['name'])),
                pinnedAt: Value(_dateOf(record['pinnedAt'], now)),
              ),
            );
      }
      for (final record in githubTokens) {
        // The archive carries the clear token (the whole archive is encrypted
        // with the vault passphrase); re-encrypt it with this vault's data
        // key, mirroring the saved-credential import.
        final clearToken = record['token'];
        if (clearToken is! String) {
          throw const FormatException('Invalid GitHub token.');
        }
        final encrypted = await _vault.encrypt(
          clearToken,
          context: 'github-token',
        );
        await _database
            .into(_database.gitHubTokens)
            .insert(
              GitHubTokensCompanion(
                id: _idOf(record),
                accountLogin: Value(
                  ServerRecordCodec.stringOf(record['accountLogin']),
                ),
                encryptedToken: Value(encrypted.bytes),
                tokenNonce: Value(encrypted.nonce),
                updatedAt: Value(_dateOf(record['updatedAt'], now)),
              ),
            );
      }
    });
  }

  /// Brings a payload written at [fromVersion] up to [formatVersion], one
  /// step per version. Unknown keys (dropped tables and columns) are carried
  /// along untouched and ignored by the restore.
  static Map<String, dynamic> upgradePayload(
    Map<String, dynamic> payload,
    int fromVersion,
  ) {
    var current = Map<String, dynamic>.from(payload);
    for (var version = fromVersion; version < formatVersion; version++) {
      current = switch (version) {
        1 => _upgradeV1ToV2(current),
        2 => _upgradeV2ToV3(current),
        3 => _upgradeV3ToV4(current),
        _ => current,
      };
      current['version'] = version + 1;
    }
    return current;
  }

  /// v1 and v2 share the server shape; v2 only added tables that no longer
  /// exist, so there is nothing to translate.
  static Map<String, dynamic> _upgradeV1ToV2(Map<String, dynamic> payload) =>
      payload;

  /// v2 kept the clear credential on each server (`credential`, the encoded
  /// JSON, plus `credentialType`). v3 moved them into `savedCredentials`
  /// rows that servers reference by `credentialId`.
  static Map<String, dynamic> _upgradeV2ToV3(Map<String, dynamic> payload) {
    final servers = _records(payload, 'servers');
    final credentials = _records(payload, 'savedCredentials');
    var nextId =
        credentials.fold<int>(
          0,
          (max, record) => switch (record['id']) {
            final int id when id > max => id,
            _ => max,
          },
        ) +
        1;
    for (final server in servers) {
      final credential = server.remove('credential');
      final type = server.remove('credentialType');
      server.remove('encryptedCredential');
      server.remove('credentialNonce');
      if (credential is! String || credential.isEmpty) continue;
      final id = nextId++;
      credentials.add({
        'id': id,
        'name': server['name'],
        'credentialType': type is String ? type : 'password',
        'credential': credential,
        'createdAt': server['createdAt'],
        'updatedAt': server['updatedAt'],
      });
      server['credentialId'] = id;
    }
    return {...payload, 'servers': servers, 'savedCredentials': credentials};
  }

  /// v4 adds the saved port-forwarding presets; earlier archives had none.
  static Map<String, dynamic> _upgradeV3ToV4(Map<String, dynamic> payload) => {
    ...payload,
    'portForwardConfigs': payload['portForwardConfigs'] ?? <Object?>[],
  };

  static Value<int> _idOf(Map<String, dynamic> record) =>
      switch (record['id']) {
        final int id => Value(id),
        _ => const Value.absent(),
      };

  static DateTime _dateOf(Object? value, DateTime fallback) =>
      ServerRecordCodec.decodeDateTime(value) ?? fallback;

  /// The record list under [key]; a missing key is an empty list (archives
  /// predate most keys), anything else is a corrupt archive.
  static List<Map<String, dynamic>> _records(
    Map<String, dynamic> payload,
    String key,
  ) {
    final records = payload[key];
    if (records == null) return [];
    if (records is! List) throw FormatException('Invalid $key in backup.');
    return [
      for (final record in records)
        if (record is Map)
          Map<String, dynamic>.from(record)
        else
          throw FormatException('Invalid $key record.'),
    ];
  }
}
