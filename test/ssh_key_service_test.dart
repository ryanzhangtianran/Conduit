import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/servers/ssh_key_preferences.dart';
import 'package:conduit/servers/ssh_key_service.dart';

/// Octal permission bits of [path] via `stat`, e.g. `600`.
Future<String> _mode(String path) async {
  final result = await Process.run('stat', ['-f', '%Lp', path]);
  return (result.stdout as String).trim();
}

void main() {
  group('SshKeyService.fileStemFor', () {
    test('slugs the server name and appends the key type', () {
      expect(
        SshKeyService.fileStemFor('Prod DB (eu/west)', SshKeyType.ed25519),
        'conduit_prod-db-eu-west_ed25519',
      );
      expect(
        SshKeyService.fileStemFor('   ', SshKeyType.rsa),
        'conduit_server_rsa',
      );
      expect(SshKeyService.fileStemFor('Prod', null), 'conduit_prod');
    });
  });

  group('SshKeyService.privateKeyPathFor', () {
    test('joins the expanded key directory and the file stem', () {
      expect(
        SshKeyService.privateKeyPathFor(
          'Prod DB',
          SshKeyType.ed25519,
          const SshKeyStorageConfig(localPrivateKeyDirectory: '/keys'),
        ),
        '/keys/conduit_prod-db_ed25519',
      );
    });
  });

  group('SshKeyService.buildInstallScript', () {
    test('expands ~ via \$HOME and sets directory/file permissions', () {
      final script = SshKeyService.buildInstallScript(
        publicKey: 'ssh-ed25519 AAAAC3 user@host',
        config: const SshKeyStorageConfig(),
      );
      expect(script, contains('ak="\$HOME"\'/.ssh/authorized_keys\''));
      expect(script, contains("key='ssh-ed25519 AAAAC3 user@host'"));
      expect(script, contains('chmod 700 "\$akdir"'));
      expect(script, contains('grep -qxF "\$key" "\$ak" ||'));
      expect(script, contains('chmod 600 "\$ak"'));
      expect(script, startsWith('set -e'));
    });

    test('keeps absolute paths literal and escapes single quotes', () {
      final script = SshKeyService.buildInstallScript(
        publicKey: "ssh-rsa AAAA it's-me",
        config: const SshKeyStorageConfig(
          remoteAuthorizedKeysPath: '/srv/keys/authorized',
        ),
      );
      expect(script, contains("ak='/srv/keys/authorized'"));
      expect(script, contains("key='ssh-rsa AAAA it'\\''s-me'"));
    });

    test('drops the replaced key line before appending the new one', () {
      final script = SshKeyService.buildInstallScript(
        publicKey: 'ssh-ed25519 NEW user@host',
        config: const SshKeyStorageConfig(),
        replacesPublicKey: 'ssh-ed25519 OLD user@host',
      );
      expect(script, contains("old='ssh-ed25519 OLD user@host'"));
      final drop = script.indexOf('grep -vxF "\$old"');
      final append = script.indexOf('grep -qxF "\$key"');
      expect(drop, greaterThan(-1));
      expect(append, greaterThan(drop));

      final withoutOld = SshKeyService.buildInstallScript(
        publicKey: 'ssh-ed25519 NEW user@host',
        config: const SshKeyStorageConfig(),
      );
      expect(withoutOld, isNot(contains('grep -vxF')));
    });
  });

  group('SshKeyService.generate', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ssh_key_service_test');
    });

    tearDown(() => root.deleteSync(recursive: true));

    test(
      'writes an Ed25519 pair with 600/644 modes in a 700 directory',
      () async {
        const service = SshKeyService();
        final keyDir = '${root.path}/keys';
        final pair = await service.generate(
          type: SshKeyType.ed25519,
          serverName: 'test',
          comment: 'tester@example',
          config: SshKeyStorageConfig(localPrivateKeyDirectory: keyDir),
        );

        expect(pair.privateKeyPath, '$keyDir/conduit_test_ed25519');
        expect(pair.publicKeyPath, '$keyDir/conduit_test_ed25519.pub');
        expect(pair.privateKey, contains('OPENSSH PRIVATE KEY'));
        expect(pair.publicKey, startsWith('ssh-ed25519 '));
        expect(pair.publicKey, endsWith(' tester@example'));
        expect(await _mode(keyDir), '700');
        expect(await _mode(pair.privateKeyPath), '600');
        expect(await _mode(pair.publicKeyPath), '644');
        expect(SshKeyService.keyTypeOf(pair.privateKey), SshKeyType.ed25519);
        // The file is where every later lookup expects it.
        expect(
          pair.privateKeyPath,
          SshKeyService.privateKeyPathFor(
            'test',
            SshKeyType.ed25519,
            SshKeyStorageConfig(localPrivateKeyDirectory: keyDir),
          ),
        );
      },
      skip: !Platform.isMacOS && !Platform.isLinux,
    );

    test(
      'regenerating a stem replaces the pair and reports the old key',
      () async {
        const service = SshKeyService();
        final config = SshKeyStorageConfig(localPrivateKeyDirectory: root.path);
        final first = await service.generate(
          type: SshKeyType.ed25519,
          serverName: 'dup',
          comment: 'a',
          config: config,
        );
        final second = await service.generate(
          type: SshKeyType.ed25519,
          serverName: 'dup',
          comment: 'b',
          config: config,
        );
        expect(first.previousPublicKey, isNull);
        // Same paths, no -1 duplicates, and the replaced public key is
        // carried so the server line can be dropped.
        expect(second.privateKeyPath, first.privateKeyPath);
        expect(second.publicKeyPath, first.publicKeyPath);
        expect(second.previousPublicKey, first.publicKey);
        expect(
          File('${root.path}/conduit_dup_ed25519-1').existsSync(),
          isFalse,
        );
        expect(
          await File(second.privateKeyPath).readAsString(),
          second.privateKey,
        );
      },
      skip: !Platform.isMacOS && !Platform.isLinux,
    );
  });

  group('SshKeyService.ensurePrivateKeyFile', () {
    test('writes the vault key to its deterministic path, mode 600', () async {
      final root = Directory.systemTemp.createTempSync('ssh_key_ensure');
      addTearDown(() => root.deleteSync(recursive: true));
      const service = SshKeyService();
      final config = SshKeyStorageConfig(localPrivateKeyDirectory: root.path);

      final path = await service.ensurePrivateKeyFile(
        privateKey: 'PEM-ONE',
        fileStem: 'conduit_box_ed25519',
        config: config,
      );
      expect(path, '${root.path}/conduit_box_ed25519');
      expect(await File(path).readAsString(), 'PEM-ONE\n');
      expect(await _mode(path), '600');
      expect(await _mode(root.path), '700');

      // A repeat with the same key is a no-op on the same path.
      expect(
        await service.ensurePrivateKeyFile(
          privateKey: 'PEM-ONE\n',
          fileStem: 'conduit_box_ed25519',
          config: config,
        ),
        path,
      );
    }, skip: !Platform.isMacOS && !Platform.isLinux);

    test('the vault copy overwrites a stale file and its .pub', () async {
      final root = Directory.systemTemp.createTempSync('ssh_key_ensure');
      addTearDown(() => root.deleteSync(recursive: true));
      const service = SshKeyService();
      final config = SshKeyStorageConfig(localPrivateKeyDirectory: root.path);
      await File('${root.path}/conduit_box_ed25519').writeAsString('OLD\n');
      await File('${root.path}/conduit_box_ed25519.pub').writeAsString('OLD');

      final path = await service.ensurePrivateKeyFile(
        privateKey: 'NEW',
        fileStem: 'conduit_box_ed25519',
        config: config,
      );
      expect(path, '${root.path}/conduit_box_ed25519');
      expect(await File(path).readAsString(), 'NEW\n');
      expect(File('$path.pub').existsSync(), isFalse);
      // No suffixed duplicate was written.
      expect(root.listSync().map((e) => e.path), [path]);
    }, skip: !Platform.isMacOS && !Platform.isLinux);
  });

  group('SshKeyService.keyTypeOf', () {
    test('returns null for text that is not a key', () {
      expect(SshKeyService.keyTypeOf('not a key'), isNull);
      expect(SshKeyService.keyTypeOf(''), isNull);
    });
  });

  group('SshKeyStorageConfig', () {
    test('expandLocalPath resolves ~ and falls back when blank', () {
      final home = Platform.environment['HOME']!;
      expect(expandLocalPath('~/.ssh'), '$home/.ssh');
      expect(expandLocalPath('~'), home);
      expect(expandLocalPath('  '), '$home/.ssh');
      expect(expandLocalPath('/abs/path'), '/abs/path');
    });

    test('copyWith keeps the untouched fields', () {
      const settings = SshKeyStorageConfig();
      final updated = settings.copyWith(
        remoteAuthorizedKeysPath: '/etc/ssh/keys',
        defaultKeyType: SshKeyType.rsa,
      );
      expect(updated.localPrivateKeyDirectory, '~/.ssh');
      expect(updated.remoteAuthorizedKeysPath, '/etc/ssh/keys');
      expect(updated.defaultKeyType, SshKeyType.rsa);
    });
  });
}
