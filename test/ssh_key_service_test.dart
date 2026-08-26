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
    });
  });

  group('SshKeyService.buildInstallScript', () {
    test('expands ~ via \$HOME and sets directory/file permissions', () {
      final script = SshKeyService.buildInstallScript(
        publicKey: 'ssh-ed25519 AAAAC3 user@host',
        fileName: 'conduit_prod_ed25519',
        config: const SshKeyStorageConfig(),
      );
      expect(script, contains('dir="\$HOME"\'/.ssh\''));
      expect(script, contains('ak="\$HOME"\'/.ssh/authorized_keys\''));
      expect(script, contains("key='ssh-ed25519 AAAAC3 user@host'"));
      expect(script, contains('chmod 700 "\$dir"'));
      expect(
        script,
        contains('chmod 644 "\$dir/"\'conduit_prod_ed25519\'.pub'),
      );
      expect(script, contains('grep -qxF "\$key" "\$ak" ||'));
      expect(script, contains('chmod 600 "\$ak"'));
      expect(script, startsWith('set -e'));
    });

    test('keeps absolute paths literal and escapes single quotes', () {
      final script = SshKeyService.buildInstallScript(
        publicKey: "ssh-rsa AAAA it's-me",
        fileName: 'k',
        config: const SshKeyStorageConfig(
          remoteKeyDirectory: '/srv/keys',
          remoteAuthorizedKeysPath: '/srv/keys/authorized',
        ),
      );
      expect(script, contains("dir='/srv/keys'"));
      expect(script, contains("ak='/srv/keys/authorized'"));
      expect(script, contains("key='ssh-rsa AAAA it'\\''s-me'"));
    });

    test('drops the replaced key line before appending the new one', () {
      final script = SshKeyService.buildInstallScript(
        publicKey: 'ssh-ed25519 NEW user@host',
        fileName: 'k',
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
        fileName: 'k',
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
          fileStem: 'conduit_test_ed25519',
          comment: 'tester@example',
          config: SshKeyStorageConfig(
            localPrivateKeyDirectory: keyDir,
            localPublicKeyDirectory: keyDir,
          ),
        );

        expect(pair.privateKeyPath, '$keyDir/conduit_test_ed25519');
        expect(pair.publicKeyPath, '$keyDir/conduit_test_ed25519.pub');
        expect(pair.privateKey, contains('OPENSSH PRIVATE KEY'));
        expect(pair.publicKey, startsWith('ssh-ed25519 '));
        expect(pair.publicKey, endsWith(' tester@example'));
        expect(await _mode(keyDir), '700');
        expect(await _mode(pair.privateKeyPath), '600');
        expect(await _mode(pair.publicKeyPath), '644');
      },
      skip: !Platform.isMacOS && !Platform.isLinux,
    );

    test('relocates the public key to a separate directory', () async {
      const service = SshKeyService();
      final pair = await service.generate(
        type: SshKeyType.ecdsa,
        fileStem: 'conduit_split_ecdsa',
        comment: 'c',
        config: SshKeyStorageConfig(
          localPrivateKeyDirectory: '${root.path}/private',
          localPublicKeyDirectory: '${root.path}/public',
        ),
      );
      expect(pair.privateKeyPath, '${root.path}/private/conduit_split_ecdsa');
      expect(pair.publicKeyPath, '${root.path}/public/conduit_split_ecdsa.pub');
      expect(
        File('${root.path}/private/conduit_split_ecdsa.pub').existsSync(),
        isFalse,
      );
      expect(pair.publicKey, startsWith('ecdsa-sha2-nistp256 '));
    }, skip: !Platform.isMacOS && !Platform.isLinux);

    test(
      'regenerating a stem replaces the pair and reports the old key',
      () async {
        const service = SshKeyService();
        final config = SshKeyStorageConfig(
          localPrivateKeyDirectory: root.path,
          localPublicKeyDirectory: root.path,
        );
        final first = await service.generate(
          type: SshKeyType.ed25519,
          fileStem: 'dup',
          comment: 'a',
          config: config,
        );
        final second = await service.generate(
          type: SshKeyType.ed25519,
          fileStem: 'dup',
          comment: 'b',
          config: config,
        );
        expect(first.previousPublicKey, isNull);
        // Same paths, no -1 duplicates, and the replaced public key is
        // carried so the server line can be dropped.
        expect(second.privateKeyPath, first.privateKeyPath);
        expect(second.publicKeyPath, first.publicKeyPath);
        expect(second.previousPublicKey, first.publicKey);
        expect(File('${root.path}/dup-1').existsSync(), isFalse);
        expect(
          await File(second.privateKeyPath).readAsString(),
          second.privateKey,
        );
      },
      skip: !Platform.isMacOS && !Platform.isLinux,
    );
  });

  group('SshKeyService.writePrivateKeyFile', () {
    test('exports a key with mode 600 and never overwrites', () async {
      final root = Directory.systemTemp.createTempSync('ssh_key_export');
      addTearDown(() => root.deleteSync(recursive: true));
      const service = SshKeyService();
      final config = SshKeyStorageConfig(localPrivateKeyDirectory: root.path);

      final first = await service.writePrivateKeyFile(
        privateKey: 'PEM-ONE',
        fileStem: 'conduit_box',
        config: config,
      );
      final second = await service.writePrivateKeyFile(
        privateKey: 'PEM-TWO',
        fileStem: 'conduit_box',
        config: config,
      );
      expect(first, '${root.path}/conduit_box');
      expect(second, '${root.path}/conduit_box-1');
      expect(await File(first).readAsString(), 'PEM-ONE\n');
      expect(await _mode(first), '600');
      expect(await _mode(root.path), '700');
    }, skip: !Platform.isMacOS && !Platform.isLinux);
  });

  group('SshKeyService.ensurePrivateKeyFile', () {
    test('reuses any file holding the key instead of writing a copy', () async {
      final root = Directory.systemTemp.createTempSync('ssh_key_ensure');
      addTearDown(() => root.deleteSync(recursive: true));
      const service = SshKeyService();
      final config = SshKeyStorageConfig(localPrivateKeyDirectory: root.path);
      // A previously generated key under a different name, plus its .pub twin
      // which must never be matched.
      await File('${root.path}/conduit_box_ed25519').writeAsString('PEM-ONE\n');
      await File(
        '${root.path}/conduit_box_ed25519.pub',
      ).writeAsString('PEM-ONE\n');

      final reused = await service.ensurePrivateKeyFile(
        privateKey: 'PEM-ONE',
        fileStem: 'conduit_box',
        config: config,
      );
      expect(reused, '${root.path}/conduit_box_ed25519');

      // A different key gets its own file; a repeat ensure then reuses it.
      final written = await service.ensurePrivateKeyFile(
        privateKey: 'PEM-TWO',
        fileStem: 'conduit_box',
        config: config,
      );
      expect(written, '${root.path}/conduit_box');
      final repeat = await service.ensurePrivateKeyFile(
        privateKey: 'PEM-TWO',
        fileStem: 'conduit_box',
        config: config,
      );
      expect(repeat, written);
    }, skip: !Platform.isMacOS && !Platform.isLinux);
  });

  group('SshKeyStorageConfig', () {
    test('expandLocalPath resolves ~ and falls back when blank', () {
      final home = Platform.environment['HOME']!;
      expect(expandLocalPath('~/.ssh'), '$home/.ssh');
      expect(expandLocalPath('~'), home);
      expect(expandLocalPath('  '), '$home/.ssh');
      expect(expandLocalPath('/abs/path'), '/abs/path');
    });

    test('in-memory settings round-trip the config', () async {
      final settings = InMemorySshKeySettings();
      final updated = settings.config.copyWith(
        remoteAuthorizedKeysPath: '/etc/ssh/keys',
        defaultKeyType: SshKeyType.rsa,
      );
      await settings.saveConfig(updated);
      expect(settings.config, updated);
      expect(settings.config.localPrivateKeyDirectory, '~/.ssh');
      expect(settings.config.defaultKeyType, SshKeyType.rsa);
    });
  });
}
