import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_record_codec.dart';
import 'package:conduit/servers/vault_service.dart';

Server _server() => Server(
  id: 7,
  name: 'prod-db',
  host: '10.0.0.1',
  port: 2222,
  username: 'root',
  lastConnectedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  syncId: 'sync-7',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 3),
  deletedAt: null,
  credentialId: 3,
  hostKeyFingerprint: 'SHA256:abc',
  collectStats: false,
  collectSystemInfo: true,
  proxyType: ServerProxyType.socks5.name,
  proxyHost: 'proxy.local',
  proxyPort: 1080,
  proxyUsername: 'proxy-user',
  encryptedProxyPassword: 'cipher',
  proxyPasswordNonce: 'nonce',
  jumpHostServerId: 2,
  environment: encodeEnvironmentMap(const {'KUBECONFIG': '/etc/k8s'}),
  tags: encodeStringList(const ['prod', 'eu-west']),
  connectionType: 'ssh',
  sortOrder: 4,
);

void main() {
  const codec = ServerRecordCodec();

  group('ServerRecordCodec.toRecord', () {
    test(
      'redacted record carries identity, tags and the proxy sans password',
      () {
        final record = codec.toRecord(_server(), proxyPassword: 'secret');
        expect(record, {
          'name': 'prod-db',
          'host': '10.0.0.1',
          'port': 2222,
          'username': 'root',
          'tags': ['prod', 'eu-west'],
          'connectionType': 'ssh',
          'syncId': 'sync-7',
          'proxy': {
            'type': 'socks5',
            'host': 'proxy.local',
            'port': 1080,
            'username': 'proxy-user',
          },
        });
      },
    );

    test('full record adds ids, timestamps, environment and the password', () {
      final record = codec.toRecord(
        _server(),
        redact: false,
        proxyPassword: 'secret',
      );
      expect(record['id'], 7);
      expect(record['credentialId'], 3);
      expect(record['jumpHostServerId'], 2);
      expect(record['environment'], {'KUBECONFIG': '/etc/k8s'});
      expect(record['hostKeyFingerprint'], 'SHA256:abc');
      expect(record['collectStats'], isFalse);
      expect(record['sortOrder'], 4);
      expect(record['lastConnectedAt'], '2026-01-02T03:04:05.000Z');
      expect(record['deletedAt'], isNull);
      expect((record['proxy'] as Map)['password'], 'secret');
      expect(codec.proxyPasswordOf(record), 'secret');
    });

    test('omits the proxy block for servers without one', () {
      final server = Server(
        id: 1,
        name: 'plain',
        host: 'h',
        port: 22,
        username: 'u',
        collectStats: true,
        collectSystemInfo: true,
        connectionType: 'ssh',
      );
      expect(codec.toRecord(server).containsKey('proxy'), isFalse);
      expect(codec.toRecord(server)['tags'], isEmpty);
    });
  });

  group('ServerRecordCodec.fromRecord', () {
    test('round-trips a full record', () {
      final record = codec.toRecord(
        _server(),
        redact: false,
        proxyPassword: 'secret',
      );
      const encrypted = EncryptedValue(bytes: 'c', nonce: 'n');
      final companion = codec.fromRecord(record, proxyPassword: encrypted);
      expect(companion.id, const Value(7));
      expect(companion.name.value, 'prod-db');
      expect(companion.host.value, '10.0.0.1');
      expect(companion.port.value, 2222);
      expect(companion.username.value, 'root');
      expect(companion.syncId.value, 'sync-7');
      expect(companion.credentialId.value, 3);
      expect(companion.jumpHostServerId.value, 2);
      expect(companion.hostKeyFingerprint.value, 'SHA256:abc');
      expect(companion.collectStats.value, isFalse);
      expect(companion.collectSystemInfo.value, isTrue);
      expect(companion.proxyType.value, 'socks5');
      expect(companion.proxyHost.value, 'proxy.local');
      expect(companion.proxyPort.value, 1080);
      expect(companion.proxyUsername.value, 'proxy-user');
      expect(companion.encryptedProxyPassword.value, 'c');
      expect(companion.proxyPasswordNonce.value, 'n');
      expect(decodeStringList(companion.tags.value), ['prod', 'eu-west']);
      expect(decodeEnvironmentMap(companion.environment.value), {
        'KUBECONFIG': '/etc/k8s',
      });
      expect(companion.sortOrder.value, 4);
      expect(
        companion.lastConnectedAt.value,
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      expect(companion.deletedAt.value, isNull);
    });

    test('reads the Drift toJson shape of earlier backups', () {
      // Epoch-millisecond dates, JSON-string tags/environment, flat proxy
      // keys, and the columns dropped in schema 41.
      final record = <String, dynamic>{
        'id': 3,
        'name': 'legacy',
        'host': 'legacy.local',
        'port': 22,
        'username': 'admin',
        'lastConnectedAt': DateTime.utc(2025, 6, 1).millisecondsSinceEpoch,
        'createdAt': DateTime.utc(2025, 5, 1).millisecondsSinceEpoch,
        'credentialType': 'password',
        'encryptedCredential': 'x',
        'credentialNonce': 'y',
        'serialConfig': null,
        'hostKeyAlgorithm': 'ssh-ed25519',
        'proxyScheme': 'http',
        'proxyType': 'http',
        'proxyHost': 'proxy.local',
        'proxyPort': 8080,
        'proxyUsername': null,
        'proxyPassword': 'pw',
        'environment': '{"A":"1"}',
        'tags': '["x"]',
        'collectStats': true,
        'collectSystemInfo': false,
      };
      final companion = codec.fromRecord(record);
      expect(companion.id, const Value(3));
      expect(companion.connectionType.value, 'ssh');
      expect(companion.lastConnectedAt.value, DateTime.utc(2025, 6, 1));
      expect(companion.createdAt.value, DateTime.utc(2025, 5, 1));
      expect(companion.proxyType.value, 'http');
      expect(companion.proxyHost.value, 'proxy.local');
      expect(companion.proxyPort.value, 8080);
      expect(companion.collectSystemInfo.value, isFalse);
      expect(decodeStringList(companion.tags.value), ['x']);
      expect(decodeEnvironmentMap(companion.environment.value), {'A': '1'});
      expect(codec.proxyPasswordOf(record), 'pw');
    });

    test('defaults every absent key', () {
      final companion = codec.fromRecord(<String, dynamic>{'name': 'bare'});
      expect(companion.id.present, isFalse);
      expect(companion.host.value, '');
      expect(companion.port.value, 22);
      expect(companion.connectionType.value, 'ssh');
      expect(companion.collectStats.value, isTrue);
      expect(companion.proxyType.value, isNull);
      expect(companion.tags.value, isNull);
      expect(companion.environment.value, isNull);
    });
  });

  group('ServerRecordCodec helpers', () {
    test('decodeProxy fills the password from the secrets block', () {
      final proxy = ServerRecordCodec.decodeProxy({
        'type': 'http',
        'host': 'p',
        'port': 8080,
        'username': 'u',
      }, password: 'pw');
      expect(proxy?.type, ServerProxyType.http);
      expect(proxy?.password, 'pw');
      expect(
        ServerRecordCodec.decodeProxy({'type': 'none', 'host': 'p'}),
        isNull,
      );
      expect(ServerRecordCodec.decodeProxy(null), isNull);
    });

    test('decodeCredential accepts maps and encoded strings', () {
      final fromMap = ServerRecordCodec.decodeCredential({
        'type': 'privateKey',
        'privateKey': 'PEM',
        'keyPassphrase': 'pp',
      });
      expect(fromMap?.type, CredentialType.privateKey);
      expect(fromMap?.privateKey, 'PEM');
      expect(fromMap?.keyPassphrase, 'pp');
      final fromString = ServerRecordCodec.decodeCredential(
        ServerCredential.password('hunter2').encode(),
      );
      expect(fromString?.password, 'hunter2');
      expect(ServerRecordCodec.decodeCredential('not json'), isNull);
      expect(ServerRecordCodec.decodeCredential({'type': 'other'}), isNull);
    });

    test('date decoding accepts ISO strings and epoch milliseconds', () {
      final expected = DateTime.utc(2026, 8, 25, 10, 30);
      expect(
        ServerRecordCodec.decodeDateTime('2026-08-25T10:30:00.000Z'),
        expected,
      );
      expect(
        ServerRecordCodec.decodeDateTime(expected.millisecondsSinceEpoch),
        expected,
      );
      expect(ServerRecordCodec.decodeDateTime('garbage'), isNull);
      expect(ServerRecordCodec.decodeDateTime(null), isNull);
    });
  });

  group('v1 export document', () {
    test('a hand-written redacted document decodes into a connection', () {
      // Shape of a `conduit-connections` v1 file written before
      // credentialIndex existed.
      final record = <String, dynamic>{
        'name': 'web',
        'host': 'web.internal',
        'port': 22,
        'username': 'deploy',
        'authType': 'privateKey',
        'tags': ['web'],
        'connectionType': 'ssh',
        'syncId': 'abc',
        'jumpHostSyncId': null,
        'proxy': {'type': 'http', 'host': 'proxy', 'port': 3128},
      };
      final companion = codec.fromRecord(record);
      expect(companion.name.value, 'web');
      expect(companion.proxyType.value, 'http');
      expect(companion.proxyPort.value, 3128);
      expect(companion.credentialId.value, isNull);
      expect(ServerRecordCodec.decodeTags(record['tags']), ['web']);
    });
  });
}
