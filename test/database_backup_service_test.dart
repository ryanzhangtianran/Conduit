import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/database_backup_service.dart';
import 'package:conduit/servers/port_forwarding_models.dart';
import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_repository.dart';
import 'package:conduit/servers/vault_service.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

/// drift_flutter resolves its native database directory through
/// path_provider; point it at the system temp directory in tests.
void _mockPathProvider() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        return Directory.systemTemp.path;
      });
}

/// A database with its own unlocked vault, as on a fresh device.
Future<(AppDatabase, VaultService)> _openVault(String password) async {
  final directory = Directory.systemTemp.createTempSync('backup_test');
  final database = AppDatabase(filePath: '${directory.path}/test.sqlite');
  final vault = VaultService(database, secureStorage: _MemoryStorage());
  await vault.create(password);
  return (database, vault);
}

void main() {
  _mockPathProvider();

  group('DatabaseBackupService', () {
    test('round-trips servers, credentials, proxy and presets', () async {
      final (source, sourceVault) = await _openVault('a');
      addTearDown(source.close);
      final repository = ServerRepository(source, sourceVault);
      final jump = await repository.create(
        ServerDraft(
          name: 'bastion',
          host: 'bastion.local',
          port: 22,
          username: 'ops',
          credential: const ServerCredential.privateKey(
            privateKey: 'PEM',
            keyPassphrase: 'pp',
          ),
        ),
      );
      final server = await repository.create(
        ServerDraft(
          name: 'prod-db',
          host: '10.0.0.1',
          port: 2222,
          username: 'root',
          credential: ServerCredential.password('hunter2'),
          credentialName: 'prod-db-cred',
          proxy: const ServerProxy(
            type: ServerProxyType.http,
            host: 'proxy.local',
            port: 8080,
            username: 'proxy-user',
            password: 'proxy-pass',
          ),
          jumpHostServerId: jump.id,
          environment: const {'KUBECONFIG': '/etc/k8s'},
          tags: const ['prod'],
        ),
      );
      await repository.savePortForwardConfig(
        serverId: server.id,
        direction: PortForwardDirection.local,
        kind: PortForwardKind.tcp,
        bindHost: '127.0.0.1',
        bindPort: 5432,
        targetHost: 'db.internal',
        targetPort: 5432,
        autoStart: true,
        keepAlive: true,
      );

      final payload = await DatabaseBackupService(
        source,
        sourceVault,
      ).exportPayload();
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['version'], DatabaseBackupService.formatVersion);
      expect(decoded['portForwardConfigs'], hasLength(1));
      // Decrypted secrets travel in the clear payload (the archive as a whole
      // is encrypted with the vault password).
      final serverRecord = (decoded['servers'] as List).firstWhere(
        (record) => record['name'] == 'prod-db',
      );
      expect(serverRecord['proxy']['password'], 'proxy-pass');
      expect(serverRecord['environment'], {'KUBECONFIG': '/etc/k8s'});
      expect(serverRecord['jumpHostServerId'], jump.id);

      final (target, targetVault) = await _openVault('b');
      addTearDown(target.close);
      final targetRepository = ServerRepository(target, targetVault);
      // A preset of this device that must not survive the restore: with the
      // archive's ids in place it would point at a different server.
      await targetRepository.savePortForwardConfig(
        serverId: 99,
        direction: PortForwardDirection.remote,
        kind: PortForwardKind.tcp,
        bindHost: '0.0.0.0',
        bindPort: 1,
        targetHost: 'x',
        targetPort: 1,
      );

      await DatabaseBackupService(target, targetVault).importPayload(payload);

      final restored = await targetRepository.all();
      expect(restored.map((s) => s.id), containsAll([jump.id, server.id]));
      final restoredServer = restored.firstWhere((s) => s.id == server.id);
      expect(restoredServer.name, 'prod-db');
      expect(restoredServer.jumpHostServerId, jump.id);
      expect(decodeStringList(restoredServer.tags), ['prod']);
      final credential = await targetRepository.credentialFor(restoredServer);
      expect(credential.password, 'hunter2');
      final jumpCredential = await targetRepository.credentialFor(
        restored.firstWhere((s) => s.id == jump.id),
      );
      expect(jumpCredential.privateKey, 'PEM');
      expect(jumpCredential.keyPassphrase, 'pp');
      final proxy = await targetRepository.proxyFor(restoredServer);
      expect(proxy?.password, 'proxy-pass');
      expect(proxy?.username, 'proxy-user');

      final presets = await target.select(target.portForwardConfigs).get();
      expect(presets, hasLength(1));
      expect(presets.single.serverId, server.id);
      expect(presets.single.bindPort, 5432);
      expect(presets.single.autoStart, isTrue);
      expect(presets.single.keepAlive, isTrue);
    });

    test('a v3 archive (no presets, Drift-shaped rows) is upgraded', () async {
      final (database, vault) = await _openVault('a');
      addTearDown(database.close);
      final payload = {
        'version': 3,
        'servers': [
          {
            'id': 5,
            'name': 'legacy',
            'host': 'legacy.local',
            'port': 22,
            'username': 'admin',
            'credentialId': 2,
            'createdAt': DateTime.utc(2025, 1, 1).millisecondsSinceEpoch,
            'tags': '["old"]',
            'environment': null,
            // Columns dropped in schema 41 are ignored.
            'credentialType': 'password',
            'encryptedCredential': 'x',
            'credentialNonce': 'y',
            'serialConfig': null,
            'hostKeyAlgorithm': 'ssh-ed25519',
            'proxyScheme': null,
            'proxyType': 'socks5',
            'proxyHost': 'p',
            'proxyPort': 1080,
            'proxyPassword': 'pw',
          },
        ],
        'savedCredentials': [
          {
            'id': 2,
            'name': 'legacy',
            'credentialType': 'password',
            'credential': ServerCredential.password('secret').encode(),
            'createdAt': DateTime.utc(2025, 1, 1).millisecondsSinceEpoch,
            'updatedAt': DateTime.utc(2025, 1, 1).millisecondsSinceEpoch,
          },
        ],
        'scriptSnippets': <Object>[],
      };
      await DatabaseBackupService(
        database,
        vault,
      ).importPayload(jsonEncode(payload));

      final repository = ServerRepository(database, vault);
      final server = (await repository.all()).single;
      expect(server.id, 5);
      expect(server.connectionType, 'ssh');
      expect(server.createdAt?.toUtc(), DateTime.utc(2025, 1, 1));
      expect(decodeStringList(server.tags), ['old']);
      expect((await repository.credentialFor(server)).password, 'secret');
      expect((await repository.proxyFor(server))?.password, 'pw');
      expect(await database.select(database.portForwardConfigs).get(), isEmpty);
    });

    test('a v2 archive moves per-server credentials into rows', () async {
      final (database, vault) = await _openVault('a');
      addTearDown(database.close);
      final payload = {
        'version': 2,
        'servers': [
          {
            'id': 1,
            'name': 'one',
            'host': 'one.local',
            'port': 22,
            'username': 'u',
            'credentialType': 'password',
            'credential': ServerCredential.password('p1').encode(),
          },
          {
            'id': 2,
            'name': 'two',
            'host': 'two.local',
            'port': 22,
            'username': 'u',
          },
        ],
      };
      await DatabaseBackupService(
        database,
        vault,
      ).importPayload(jsonEncode(payload));

      final repository = ServerRepository(database, vault);
      final servers = await repository.all();
      final one = servers.firstWhere((s) => s.id == 1);
      final two = servers.firstWhere((s) => s.id == 2);
      expect(one.credentialId, isNotNull);
      expect((await repository.credentialFor(one)).password, 'p1');
      expect(two.credentialId, isNull);
      final rows = await database.select(database.savedCredentials).get();
      expect(rows.single.name, 'one');
      expect(rows.single.credentialType, 'password');
    });

    test('newer or malformed archives are refused', () async {
      final (database, vault) = await _openVault('a');
      addTearDown(database.close);
      final service = DatabaseBackupService(database, vault);
      await expectLater(
        service.importPayload(
          jsonEncode({
            'version': DatabaseBackupService.formatVersion + 1,
            'servers': <Object>[],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.importPayload(jsonEncode({'version': 'x'})),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.importPayload(jsonEncode({'version': 4, 'servers': 'nope'})),
        throwsA(isA<FormatException>()),
      );
    });

    test('upgradePayload steps through every version', () {
      final upgraded = DatabaseBackupService.upgradePayload({
        'version': 1,
        'servers': [
          {
            'id': 1,
            'name': 'a',
            'credentialType': 'privateKey',
            'credential': '{"type":"privateKey","privateKey":"PEM"}',
          },
        ],
      }, 1);
      expect(upgraded['version'], DatabaseBackupService.formatVersion);
      expect(upgraded['portForwardConfigs'], isEmpty);
      final credentials = upgraded['savedCredentials'] as List;
      expect(credentials, hasLength(1));
      expect(credentials.single['id'], 1);
      expect(credentials.single['credentialType'], 'privateKey');
      final server = (upgraded['servers'] as List).single as Map;
      expect(server['credentialId'], 1);
      expect(server.containsKey('credential'), isFalse);
      expect(server.containsKey('credentialType'), isFalse);
    });
  });
}
