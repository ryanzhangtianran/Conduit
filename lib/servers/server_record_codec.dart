import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:conduit/data/local/app_database.dart';

import 'server_models.dart';
import 'vault_service.dart';

/// The one serialisation of a [Server] row shared by the JSON export, the
/// import preview and the encrypted `.conduit` backup.
///
/// [toRecord] writes either the *portable* shape (`redact: true`: identity,
/// address, tags and the proxy without its password — what a team can share)
/// or the *full* shape (`redact: false`: additionally ids, timestamps,
/// environment, host-key fingerprint and the clear proxy password, for a
/// backup that is encrypted as a whole).
///
/// [fromRecord] reads both, plus the shape earlier backups produced with
/// Drift's `toJson` (JSON-string `tags`/`environment`, flat `proxyType`…
/// keys, epoch-millisecond dates). Every key is optional and falls back to
/// the column default, so a record written before a column existed — or after
/// one was dropped (`credentialType`, `encryptedCredential`,
/// `credentialNonce`, `serialConfig`, `hostKeyAlgorithm`, `proxyScheme`) —
/// still restores.
class ServerRecordCodec {
  const ServerRecordCodec();

  /// Serialises [server]. A clear [proxyPassword] (decrypted by the caller)
  /// is embedded in the proxy block of a full record only.
  Map<String, Object?> toRecord(
    Server server, {
    bool redact = true,
    String? proxyPassword,
  }) => {
    if (!redact) 'id': server.id,
    'name': server.name,
    'host': server.host,
    'port': server.port,
    'username': server.username,
    'tags': decodeStringList(server.tags),
    'connectionType': server.connectionType,
    'syncId': server.syncId,
    if (!redact) ...{
      'credentialId': server.credentialId,
      'jumpHostServerId': server.jumpHostServerId,
      'environment': decodeEnvironmentMap(server.environment),
      'hostKeyFingerprint': server.hostKeyFingerprint,
      'collectStats': server.collectStats,
      'collectSystemInfo': server.collectSystemInfo,
      'sortOrder': server.sortOrder,
      'lastConnectedAt': encodeDateTime(server.lastConnectedAt),
      'createdAt': encodeDateTime(server.createdAt),
      'updatedAt': encodeDateTime(server.updatedAt),
      'deletedAt': encodeDateTime(server.deletedAt),
    },
    'proxy': ?encodeProxy(server, password: redact ? null : proxyPassword),
  };

  /// Builds an insertable companion from any record shape [toRecord] or an
  /// earlier backup produced. Absent keys take the column defaults; the
  /// caller encrypts the clear proxy password (see [proxyPasswordOf]) and
  /// passes the result as [proxyPassword].
  ServersCompanion fromRecord(
    Map<String, dynamic> record, {
    EncryptedValue? proxyPassword,
  }) {
    final proxy = decodeProxy(record['proxy']) ?? _decodeFlatProxy(record);
    final id = record['id'];
    return ServersCompanion(
      id: id is int ? Value(id) : const Value.absent(),
      name: Value(stringOf(record['name'])),
      host: Value(stringOf(record['host'])),
      port: Value(intOf(record['port'], fallback: 22)),
      username: Value(stringOf(record['username'])),
      lastConnectedAt: Value(decodeDateTime(record['lastConnectedAt'])),
      syncId: Value(record['syncId'] as String?),
      createdAt: Value(decodeDateTime(record['createdAt'])),
      updatedAt: Value(decodeDateTime(record['updatedAt'])),
      deletedAt: Value(decodeDateTime(record['deletedAt'])),
      credentialId: Value(record['credentialId'] as int?),
      hostKeyFingerprint: Value(record['hostKeyFingerprint'] as String?),
      collectStats: Value(record['collectStats'] as bool? ?? true),
      collectSystemInfo: Value(record['collectSystemInfo'] as bool? ?? true),
      proxyType: Value(proxy?.type.name),
      proxyHost: Value(proxy?.host),
      proxyPort: Value(proxy?.port),
      proxyUsername: Value(proxy?.username),
      encryptedProxyPassword: Value(proxyPassword?.bytes),
      proxyPasswordNonce: Value(proxyPassword?.nonce),
      jumpHostServerId: Value(record['jumpHostServerId'] as int?),
      environment: Value(
        encodeEnvironmentMap(decodeEnvironment(record['environment'])),
      ),
      tags: Value(encodeStringList(decodeTags(record['tags']))),
      connectionType: Value(
        stringOf(record['connectionType'], fallback: 'ssh'),
      ),
      sortOrder: Value(record['sortOrder'] as int?),
    );
  }

  /// The clear proxy password of a full record: nested in the proxy block
  /// ([toRecord]) or at the top level (earlier backups).
  String? proxyPasswordOf(Map<String, dynamic> record) {
    final proxy = record['proxy'];
    if (proxy is Map && proxy['password'] is String) {
      return proxy['password'] as String;
    }
    return record['proxyPassword'] as String?;
  }

  /// The proxy block, or null when the server uses none. The password is
  /// only included when [password] is given.
  Map<String, Object?>? encodeProxy(Server server, {String? password}) {
    final type = server.proxyType;
    final host = server.proxyHost;
    if (type == null ||
        type == ServerProxyType.none.name ||
        host == null ||
        host.isEmpty) {
      return null;
    }
    return {
      'type': type,
      'host': host,
      'port': server.proxyPort ?? 1080,
      'username': server.proxyUsername,
      'password': ?password,
    };
  }

  /// Decodes a proxy block written by [encodeProxy]. [password] fills in the
  /// password when the block itself carries none (the export keeps it in the
  /// secrets block).
  static ServerProxy? decodeProxy(Object? raw, {String? password}) {
    if (raw is! Map) return null;
    final host = raw['host'];
    if (host is! String || host.isEmpty) return null;
    final type = proxyTypeOf(raw['type']);
    if (type == ServerProxyType.none) return null;
    return ServerProxy(
      type: type,
      host: host,
      port: intOf(raw['port'], fallback: 1080),
      username: raw['username'] as String?,
      password: raw['password'] as String? ?? password,
    );
  }

  /// The flat `proxyType`/`proxyHost`/… keys of a Drift-shaped record.
  static ServerProxy? _decodeFlatProxy(Map<String, dynamic> record) =>
      decodeProxy({
        'type': record['proxyType'],
        'host': record['proxyHost'],
        'port': record['proxyPort'],
        'username': record['proxyUsername'],
      });

  /// Decodes a credential from an export secrets block (a map) or a v2
  /// backup (the encoded JSON string), tolerating missing fields. Returns
  /// null for anything that is not a credential.
  static ServerCredential? decodeCredential(Object? raw) {
    Object? value = raw;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is! Map) return null;
    if (value['type'] == CredentialType.privateKey.name) {
      return ServerCredential.privateKey(
        privateKey: stringOf(value['privateKey']),
        keyPassphrase: value['keyPassphrase'] as String?,
      );
    }
    if (value['type'] == CredentialType.password.name) {
      return ServerCredential.password(stringOf(value['password']));
    }
    return null;
  }

  /// Tags as a list (export) or the JSON-string column (earlier backups).
  static List<String> decodeTags(Object? raw) {
    if (raw is String) return decodeStringList(raw);
    if (raw is! List) return const [];
    return [
      for (final tag in raw)
        if (tag is String && tag.isNotEmpty) tag,
    ];
  }

  /// Environment as a map (export secrets, full record) or the JSON-string
  /// column (earlier backups).
  static Map<String, String> decodeEnvironment(Object? raw) {
    if (raw is String) return decodeEnvironmentMap(raw);
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value != null)
          entry.key as String: entry.value.toString(),
    };
  }

  static ServerProxyType proxyTypeOf(Object? value) {
    if (value is! String) return ServerProxyType.none;
    return ServerProxyType.values.asNameMap()[value] ?? ServerProxyType.none;
  }

  /// UTC ISO-8601, the form every record written by this codec uses.
  static String? encodeDateTime(DateTime? value) =>
      value?.toUtc().toIso8601String();

  /// Accepts ISO-8601 strings and the epoch milliseconds Drift's `toJson`
  /// wrote in earlier backups. Anything unparsable is null.
  static DateTime? decodeDateTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String stringOf(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static int intOf(Object? value, {required int fallback}) =>
      value is int ? value : (value is num ? value.toInt() : fallback);
}
