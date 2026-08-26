import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/connection_import_adapters.dart';
import 'package:conduit/servers/connection_import_service.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        return Directory.systemTemp.path;
      });

  group('OpenSshConfigAdapter', () {
    test('parses host blocks, skips wildcards, reads relative keys', () {
      final directory = Directory.systemTemp.createTempSync(
        'openssh_adapter_test',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final keyDir = Directory('${directory.path}/keys')..createSync();
      File('${keyDir.path}/prod_key').writeAsStringSync('PROD-KEY\n');

      const config = '''
# comment
Host jump
  HostName jump.internal
  User alice
  Port 2222
  IdentityFile ~/.ssh/jump_key

Host prod prod2
  HostName 10.0.0.5
  User root
  IdentityFile keys/prod_key

Host *.example.com
  HostName 10.0.0.9
''';

      final connections = OpenSshConfigAdapter().parse(
        config,
        baseDirectory: directory.path,
      );
      expect(connections, hasLength(2));

      final jump = connections[0];
      expect(jump.name, 'jump');
      expect(jump.host, 'jump.internal');
      expect(jump.port, 2222);
      expect(jump.username, 'alice');
      expect(jump.credential, isNull); // ~/.ssh/jump_key does not exist.

      final prod = connections[1];
      expect(prod.name, 'prod');
      expect(prod.host, '10.0.0.5');
      expect(prod.port, 22);
      expect(prod.credential!.privateKey, contains('PROD-KEY'));
    });

    test('inherits wildcard defaults and imports tokenized identity files', () {
      final directory = Directory.systemTemp.createTempSync(
        'openssh_defaults_test',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final keyDirectory = Directory('${directory.path}/keys')..createSync();
      File('${keyDirectory.path}/prod_key').writeAsStringSync('DEFAULT-KEY\n');

      const config = '''
Host *
  IdentityFile keys/%h_key

Host prod
  HostName prod.internal
  User deploy
''';
      final connections = OpenSshConfigAdapter().parse(
        config,
        baseDirectory: directory.path,
      );

      expect(connections, hasLength(1));
      expect(connections.single.name, 'prod');
      expect(connections.single.host, 'prod.internal');
      expect(connections.single.username, 'deploy');
      expect(
        connections.single.credential!.privateKey,
        contains('DEFAULT-KEY'),
      );
    });

    test('loads concrete hosts from included config files', () {
      final directory = Directory.systemTemp.createTempSync(
        'openssh_include_test',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final includeDirectory = Directory('${directory.path}/config.d')
        ..createSync();
      File('${includeDirectory.path}/work').writeAsStringSync('''
Host work
  HostName work.internal
  User builder
''');

      const config = '''
Include config.d/*
Host *
  ServerAliveInterval 30
''';
      final connections = OpenSshConfigAdapter().parse(
        config,
        baseDirectory: directory.path,
      );

      expect(connections, hasLength(1));
      expect(connections.single.name, 'work');
      expect(connections.single.host, 'work.internal');
      expect(connections.single.username, 'builder');
    });

    test('falls back to the pattern as hostname', () {
      const config = 'Host mybox\n  User admin\n';
      final connections = OpenSshConfigAdapter().parse(config);
      expect(connections.single.host, 'mybox');
      expect(connections.single.username, 'admin');
    });
  });

  group('detectThirdPartyAdapter', () {
    test('recognizes OpenSSH config and rejects everything else', () {
      expect(
        detectThirdPartyAdapter('Host web\n  HostName 10.0.0.1\n'),
        isA<OpenSshConfigAdapter>(),
      );
      expect(
        detectThirdPartyAdapter(
          'Include ~/.ssh/config.d/*\nHost *\n  IdentityFile ~/.ssh/id_ed25519\n',
        ),
        isA<OpenSshConfigAdapter>(),
      );
      expect(detectThirdPartyAdapter('random text'), isNull);
      expect(detectThirdPartyAdapter('{"name":"prod"}'), isNull);
    });
  });

  group('ConnectionImportService third-party integration', () {
    late AppDatabase database;
    late VaultService vault;
    late ConnectionImportService service;

    setUp(() async {
      final directory = Directory.systemTemp.createTempSync(
        'adapter_integration_test',
      );
      database = AppDatabase(filePath: '${directory.path}/test.sqlite');
      vault = VaultService(database, secureStorage: _MemoryStorage());
      await vault.create('vault-password');
      service = ConnectionImportService(database, vault);
    });

    tearDown(() => database.close());

    test('imports an OpenSSH host end to end', () async {
      final candidates = await service.previewThirdParty(
        'Host prod\n  HostName 10.0.0.1\n  User root\n',
      );
      expect(candidates, hasLength(1));
      expect(candidates.single.connection.source, 'OpenSSH config');

      await service.import(candidates);
      final repository = ServerRepository(database, vault);
      final imported = (await repository.all()).single;
      expect(imported.name, 'prod');
      expect(imported.host, '10.0.0.1');
    });

    test('previewAny routes OpenSSH configs to the adapter', () async {
      final candidates = await service.previewAny(
        'Host web\n  HostName 10.0.0.1\n  User root\n',
      );
      expect(candidates.single.connection.source, 'OpenSSH config');
      expect(candidates.single.connection.host, '10.0.0.1');
    });

    test('previewAny rejects unknown content', () async {
      expect(
        () => service.previewAny('this is not a connection file'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
