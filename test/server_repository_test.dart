import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/port_forwarding_models.dart';
import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/server_repository.dart';
import 'package:conduit/servers/vault_service.dart';

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

void main() {
  _mockPathProvider();

  group('ServerRepository server configuration', () {
    late AppDatabase database;
    late ServerRepository repository;

    setUp(() {
      final directory = Directory.systemTemp.createTempSync(
        'server_config_test',
      );
      database = AppDatabase(filePath: '${directory.path}/test.sqlite');
      repository = ServerRepository(database, VaultService(database));
    });

    tearDown(() => database.close());

    Future<int> insertCredential() => database
        .into(database.savedCredentials)
        .insert(
          SavedCredentialsCompanion.insert(
            name: 'test',
            credentialType: CredentialType.password.name,
            encryptedCredential: 'x',
            credentialNonce: 'y',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    test('create persists environment, snippets, and tags', () async {
      final credentialId = await insertCredential();
      final server = await repository.create(
        ServerDraft(
          name: 'prod-db',
          host: '10.0.0.1',
          port: 22,
          username: 'root',
          credentialId: credentialId,
          environment: {'KUBECONFIG': '/etc/kubernetes/admin.conf'},
          tags: ['prod', 'eu-west'],
        ),
      );

      expect(decodeEnvironmentMap(server.environment), {
        'KUBECONFIG': '/etc/kubernetes/admin.conf',
      });
      expect(decodeStringList(server.tags), ['prod', 'eu-west']);
    });

    test('create and update persist chained jump hosts', () async {
      final firstHop = await repository.create(
        const ServerDraft(
          name: 'bastion',
          host: '10.0.0.10',
          port: 22,
          username: 'root',
        ),
      );
      final secondHop = await repository.create(
        ServerDraft(
          name: 'internal-gateway',
          host: '10.0.0.15',
          port: 22,
          username: 'root',
          jumpHostServerId: firstHop.id,
        ),
      );
      final target = await repository.create(
        ServerDraft(
          name: 'internal',
          host: '10.0.0.20',
          port: 22,
          username: 'root',
          jumpHostServerId: secondHop.id,
        ),
      );

      expect(target.jumpHostServerId, secondHop.id);
      await repository.update(
        target,
        const ServerDraft(
          name: 'internal',
          host: '10.0.0.20',
          port: 22,
          username: 'root',
        ),
      );
      expect(
        (await repository.all())
            .singleWhere((server) => server.id == target.id)
            .jumpHostServerId,
        isNull,
      );
    });

    test('update replaces the stored configuration', () async {
      final credentialId = await insertCredential();
      final server = await repository.create(
        ServerDraft(
          name: 'web',
          host: '10.0.0.2',
          port: 22,
          username: 'deploy',
          credentialId: credentialId,
          environment: {'STAGE': 'staging'},
          tags: ['staging'],
        ),
      );
      await repository.update(
        server,
        ServerDraft(
          name: 'web',
          host: '10.0.0.2',
          port: 22,
          username: 'deploy',
          credentialId: credentialId,
          environment: {'STAGE': 'production', 'PORT': '8080'},
          tags: ['prod'],
        ),
      );

      final updated = (await repository.all()).single;
      expect(decodeEnvironmentMap(updated.environment), {
        'STAGE': 'production',
        'PORT': '8080',
      });
      expect(decodeStringList(updated.tags), ['prod']);
    });

    test('empty configuration is stored as null', () async {
      final credentialId = await insertCredential();
      final server = await repository.create(
        ServerDraft(
          name: 'plain',
          host: '10.0.0.3',
          port: 22,
          username: 'user',
          credentialId: credentialId,
        ),
      );

      expect(server.environment, isNull);
      expect(server.tags, isNull);
      expect(decodeEnvironmentMap(server.environment), isEmpty);
      expect(decodeStringList(server.tags), isEmpty);
    });

    test('create appends servers after existing ones', () async {
      final first = await repository.create(
        ServerDraft(name: 'one', host: '10.0.0.1', port: 22, username: 'u'),
      );
      final second = await repository.create(
        ServerDraft(name: 'two', host: '10.0.0.2', port: 22, username: 'u'),
      );

      expect(first.sortOrder!, lessThan(second.sortOrder!));
      expect((await repository.all()).map((s) => s.id), [first.id, second.id]);
    });

    test('reorderServers persists the requested order', () async {
      final servers = [
        for (var i = 0; i < 3; i++)
          await repository.create(
            ServerDraft(
              name: 'server-$i',
              host: '10.0.0.$i',
              port: 22,
              username: 'u',
            ),
          ),
      ];

      final reordered = [servers[2].id, servers[0].id, servers[1].id];
      await repository.reorderServers(reordered);

      final expected = [servers[2].id, servers[0].id, servers[1].id];
      expect((await repository.all()).map((s) => s.id), expected);
      final watched = await database.watchServers().first;
      expect(watched.map((s) => s.id), expected);
    });
  });

  group('ServerRepository port-forward presets', () {
    late AppDatabase database;
    late ServerRepository repository;
    late int serverId;

    setUp(() async {
      final directory = Directory.systemTemp.createTempSync(
        'preset_config_test',
      );
      database = AppDatabase(filePath: '${directory.path}/test.sqlite');
      repository = ServerRepository(database, VaultService(database));
      serverId = await repository
          .create(
            const ServerDraft(
              name: 'tunnel',
              host: '10.0.0.9',
              port: 22,
              username: 'root',
            ),
          )
          .then((server) => server.id);
    });

    tearDown(() => database.close());

    Future<void> saveTcp({
      String bindHost = '127.0.0.1',
      int bindPort = 8080,
      String targetHost = '127.0.0.1',
      int targetPort = 80,
      bool autoStart = false,
    }) => repository.savePortForwardConfig(
      serverId: serverId,
      direction: PortForwardDirection.local,
      kind: PortForwardKind.tcp,
      bindHost: bindHost,
      bindPort: bindPort,
      targetHost: targetHost,
      targetPort: targetPort,
      autoStart: autoStart,
    );

    test('save persists a preset and exposes it to watchers', () async {
      await saveTcp();

      final configs = await repository.portForwardConfigsForServer(serverId);
      expect(configs, hasLength(1));
      expect(configs.single.bindHost, '127.0.0.1');
      expect(configs.single.bindPort, 8080);
      expect(configs.single.targetPort, 80);
      expect(configs.single.direction, PortForwardDirection.local.name);
      expect(configs.single.kind, PortForwardKind.tcp.name);
      expect(configs.single.autoStart, isFalse);

      final watched = await repository.watchPortForwardConfigs(serverId).first;
      expect(watched.map((c) => c.id), [configs.single.id]);
    });

    test('saving the same forward updates instead of duplicating', () async {
      await saveTcp();
      await saveTcp(autoStart: true);

      final configs = await repository.portForwardConfigsForServer(serverId);
      expect(configs, hasLength(1));
      // Auto-start can only be turned on by a repeated save.
      expect(configs.single.autoStart, isTrue);
    });

    test('presets are scoped per server', () async {
      final other = await repository.create(
        const ServerDraft(
          name: 'other',
          host: '10.0.0.10',
          port: 22,
          username: 'root',
        ),
      );
      await saveTcp();

      expect(await repository.portForwardConfigsForServer(other.id), isEmpty);
      expect(
        await repository.portForwardConfigsForServer(serverId),
        hasLength(1),
      );
    });

    test('socks5 presets round-trip with empty target fields', () async {
      await repository.savePortForwardConfig(
        serverId: serverId,
        direction: PortForwardDirection.local,
        kind: PortForwardKind.socks5,
        bindHost: '127.0.0.1',
        bindPort: 1080,
        targetHost: '',
        targetPort: 0,
      );

      final configs = await repository.portForwardConfigsForServer(serverId);
      expect(configs.single.kind, PortForwardKind.socks5.name);
      expect(configs.single.targetHost, '');
      expect(configs.single.targetPort, 0);
    });

    test('autoStart toggle and delete remove the preset', () async {
      await saveTcp();
      final config = (await repository.portForwardConfigsForServer(
        serverId,
      )).single;

      await repository.setPortForwardConfigAutoStart(config.id, true);
      expect(
        (await repository.portForwardConfigsForServer(
          serverId,
        )).single.autoStart,
        isTrue,
      );

      await repository.deletePortForwardConfig(config.id);
      expect(await repository.portForwardConfigsForServer(serverId), isEmpty);
    });
  });

  group('ServerRepository app settings', () {
    late AppDatabase database;
    late ServerRepository repository;

    setUp(() async {
      final directory = Directory.systemTemp.createTempSync(
        'app_settings_test',
      );
      database = AppDatabase(filePath: '${directory.path}/test.sqlite');
      repository = ServerRepository(database, VaultService(database));
      await repository
          .create(
            const ServerDraft(
              name: 'settings-host',
              host: '10.0.0.9',
              port: 22,
              username: 'u',
            ),
          )
          .then((server) => server.id);
    });

    test('app settings round-trip through the vault database', () async {
      expect(await repository.getAppSetting('sample_setting'), isNull);
      await repository.setAppSetting('sample_setting', 'false');
      expect(await repository.getAppSetting('sample_setting'), 'false');
      expect(await repository.watchAppSetting('sample_setting').first, 'false');
      // Upsert overwrites.
      await repository.setAppSetting('sample_setting', 'true');
      expect(await repository.getAppSetting('sample_setting'), 'true');
      expect(await repository.watchAppSetting('sample_setting').first, 'true');
    });
  });

  group('ServerRepository credential ownership', () {
    late AppDatabase database;
    late VaultService vault;
    late ServerRepository repository;

    setUp(() async {
      final directory = Directory.systemTemp.createTempSync(
        'server_credential_test',
      );
      database = AppDatabase(filePath: '${directory.path}/test.sqlite');
      vault = VaultService(database, secureStorage: _MemoryStorage());
      await vault.create('vault-password');
      repository = ServerRepository(database, vault);
    });

    tearDown(() => database.close());

    Future<Server> createServer(String name, String password) =>
        repository.create(
          ServerDraft(
            name: name,
            host: 'example.com',
            port: 22,
            username: 'root',
            credential: ServerCredential.password(password),
          ),
        );

    ServerDraft draftFor(Server server, {ServerCredential? credential}) =>
        ServerDraft(
          name: server.name,
          host: server.host,
          port: server.port,
          username: server.username,
          credential: credential,
          credentialId: credential == null ? server.credentialId : null,
        );

    test(
      'editing a credential updates the server-owned row in place',
      () async {
        final server = await createServer('alpha', 'old-secret');
        final originalCredentialId = server.credentialId;

        await repository.update(
          server,
          draftFor(server, credential: ServerCredential.password('new-secret')),
        );

        final updated = await repository.all().then((items) => items.single);
        expect(updated.credentialId, originalCredentialId);
        final credential = await repository.credentialFor(updated);
        expect(credential.password, 'new-secret');
        final rows = await database.select(database.savedCredentials).get();
        expect(rows, hasLength(1));
      },
    );

    test(
      'a credential shared between servers is split, not overwritten',
      () async {
        final alpha = await createServer('alpha', 'shared-secret');
        final beta = await repository.create(
          ServerDraft(
            name: 'beta',
            host: 'example.org',
            port: 22,
            username: 'root',
            credentialId: alpha.credentialId,
          ),
        );

        await repository.update(
          beta,
          draftFor(beta, credential: ServerCredential.password('beta-secret')),
        );

        final servers = await repository.all();
        final alphaAfter = servers.singleWhere((s) => s.name == 'alpha');
        final betaAfter = servers.singleWhere((s) => s.name == 'beta');
        expect(betaAfter.credentialId, isNot(alphaAfter.credentialId));
        expect(
          (await repository.credentialFor(alphaAfter)).password,
          'shared-secret',
        );
        expect(
          (await repository.credentialFor(betaAfter)).password,
          'beta-secret',
        );
      },
    );

    test(
      'updating a server prunes credential rows nothing references',
      () async {
        await database
            .into(database.savedCredentials)
            .insert(
              SavedCredentialsCompanion.insert(
                name: 'orphan',
                credentialType: CredentialType.password.name,
                encryptedCredential: 'x',
                credentialNonce: 'y',
                createdAt: DateTime.now().toUtc(),
                updatedAt: DateTime.now().toUtc(),
              ),
            );
        final server = await createServer('alpha', 'secret');

        await repository.update(
          server,
          draftFor(server, credential: ServerCredential.password('secret')),
        );

        final rows = await database.select(database.savedCredentials).get();
        expect(rows.map((row) => row.name), ['alpha']);
      },
    );
  });
}
