import 'dart:convert';

import 'package:conduit/data/local/app_database.dart';

import 'server_models.dart';
import 'server_record_codec.dart';
import 'vault_service.dart';

/// Exports server connections in portable, human-readable formats.
///
/// Complements [DatabaseBackupService]: the `.conduit` archive is the canonical
/// full backup, while this service produces JSON/CSV files meant for other
/// tools and for sharing server lists with a team.
///
/// Sensitive fields (credentials, proxy passwords, environment variables)
/// are excluded from the redacted document. When a passphrase is supplied
/// they are collected into a single `secrets` block encrypted with the same
/// portable scheme as the `.conduit` archive, keyed by the server's position in
/// the exported list. Saved credentials are listed once under
/// `savedCredentials`; each server names the one it uses through
/// `credentialIndex` so an import can re-link servers that share a
/// credential instead of duplicating it.
class ConnectionExportService {
  ConnectionExportService(this._database, this._vault);

  static const String formatName = 'conduit-connections';
  static const int formatVersion = 1;

  /// CSV columns. Secrets do not fit the flat format.
  static const List<String> csvHeader = [
    'name',
    'host',
    'port',
    'username',
    'authType',
    'tags',
    'connectionType',
  ];

  final AppDatabase _database;
  final VaultService _vault;
  final ServerRecordCodec _codec = const ServerRecordCodec();

  /// Exports all active servers as a JSON document.
  ///
  /// Without [passphrase] the document is redacted: no passwords, private
  /// keys, proxy passwords, or environment variables are included. With one,
  /// those fields are collected into the passphrase-encrypted `secrets`
  /// block (see [VaultService.encryptPortable]).
  Future<String> exportJson({String? passphrase}) async {
    final servers = await _activeServers();
    final credentials = await _database
        .select(_database.savedCredentials)
        .get();
    final credentialsById = {
      for (final credential in credentials) credential.id: credential,
    };
    final credentialIndexById = {
      for (final (index, credential) in credentials.indexed)
        credential.id: index,
    };
    final serversById = {for (final server in servers) server.id: server};

    final serverRecords = <Map<String, Object?>>[
      for (final server in servers)
        {
          ..._codec.toRecord(server),
          'authType': credentialsById[server.credentialId]?.credentialType,
          'credentialIndex': credentialIndexById[server.credentialId],
          'jumpHostSyncId': server.jumpHostServerId == null
              ? null
              : serversById[server.jumpHostServerId!]?.syncId,
        },
    ];
    final credentialRecords = <Map<String, Object?>>[
      for (final credential in credentials)
        {'name': credential.name, 'authType': credential.credentialType},
    ];

    final document = <String, Object?>{
      'format': formatName,
      'version': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'servers': serverRecords,
      'savedCredentials': credentialRecords,
    };

    if (passphrase != null) {
      final secretRecords = <Map<String, Object?>>[];
      for (final (index, server) in servers.indexed) {
        secretRecords.add(
          await _secretRecordFor(server, index, credentialsById),
        );
      }
      final credentialSecrets = <Map<String, Object?>>[];
      for (final (index, credential) in credentials.indexed) {
        credentialSecrets.add({
          'index': index,
          'credential': await _decryptCredential(credential),
        });
      }
      document['secrets'] = await _vault.encryptPortable(
        jsonEncode({
          'servers': secretRecords,
          'savedCredentials': credentialSecrets,
        }),
        passphrase,
      );
    }

    return jsonEncode(document);
  }

  /// Exports all active servers as a CSV document. Always redacted.
  Future<String> exportCsv() async {
    final servers = await _activeServers();
    final credentials = await _database
        .select(_database.savedCredentials)
        .get();
    final credentialsById = {
      for (final credential in credentials) credential.id: credential,
    };
    final buffer = StringBuffer('${csvHeader.join(',')}\n');
    for (final server in servers) {
      buffer
        ..writeAll([
          _csvField(server.name),
          _csvField(server.host),
          '${server.port}',
          _csvField(server.username),
          _csvField(credentialsById[server.credentialId]?.credentialType ?? ''),
          _csvField(decodeStringList(server.tags).map(_escapeTag).join(',')),
          server.connectionType,
        ], ',')
        ..writeln();
    }
    return buffer.toString();
  }

  Future<List<Server>> _activeServers() => (_database.select(
    _database.servers,
  )..where((table) => table.deletedAt.isNull())).get();

  /// The per-server secrets entry: its credential (also listed under the
  /// shared `savedCredentials` secrets, kept here so readers without
  /// `credentialIndex` support still get it), proxy password and environment.
  Future<Map<String, Object?>> _secretRecordFor(
    Server server,
    int index,
    Map<int, SavedCredential> credentialsById,
  ) async {
    final credential = credentialsById[server.credentialId];
    final entry = <String, Object?>{
      'index': index,
      if (credential != null)
        'credential': await _decryptCredential(credential),
    };
    if (server.encryptedProxyPassword != null &&
        server.proxyPasswordNonce != null) {
      entry['proxyPassword'] = await _vault.decrypt(
        EncryptedValue(
          bytes: server.encryptedProxyPassword!,
          nonce: server.proxyPasswordNonce!,
        ),
        context: 'server-proxy-password',
      );
    }
    final environment = decodeEnvironmentMap(server.environment);
    if (environment.isNotEmpty) entry['environment'] = environment;
    return entry;
  }

  Future<Map<String, Object?>> _decryptCredential(
    SavedCredential credential,
  ) async {
    final value = await _vault.decrypt(
      EncryptedValue(
        bytes: credential.encryptedCredential,
        nonce: credential.credentialNonce,
      ),
      context: 'server-credential',
    );
    return ServerCredential.decode(value).toJson();
  }
}

String _csvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Escapes a tag for the comma-joined CSV column so tags containing commas
/// or backslashes round-trip losslessly.
String _escapeTag(String tag) =>
    tag.replaceAll(r'\', r'\\').replaceAll(',', r'\,');
