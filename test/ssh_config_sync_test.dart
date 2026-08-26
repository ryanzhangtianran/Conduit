import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/servers/ssh_config_sync.dart';

const _entry = SshConfigEntry(
  alias: 'prod',
  hostName: '10.0.0.5',
  user: 'deploy',
  port: 2222,
  identityFile: '~/.ssh/conduit_prod_ed25519',
);

void main() {
  group('sshConfigAliasFor', () {
    test('collapses whitespace and strips pattern metacharacters', () {
      expect(sshConfigAliasFor('Prod DB  (eu)'), 'Prod-DB-(eu)');
      expect(sshConfigAliasFor('web*?!'), 'web');
      expect(sshConfigAliasFor('   '), 'server');
    });
  });

  group('tildePath', () {
    test('rewrites paths under HOME and leaves others alone', () {
      final home = Platform.environment['HOME']!;
      expect(tildePath('$home/.ssh/key'), '~/.ssh/key');
      expect(tildePath('/etc/ssh/key'), '/etc/ssh/key');
    });
  });

  group('mergeSshConfig', () {
    test('appends a block to an empty config', () {
      expect(mergeSshConfig('', _entry), '''
Host prod
  HostName 10.0.0.5
  User deploy
  Port 2222
  IdentityFile ~/.ssh/conduit_prod_ed25519
  IdentitiesOnly yes
''');
    });

    test('appends after existing blocks with a blank separator', () {
      const existing = 'Host other\n  HostName 1.1.1.1\n';
      final merged = mergeSshConfig(existing, _entry);
      expect(merged, startsWith(existing));
      expect(merged, contains('\n\nHost prod\n'));
      expect(merged, endsWith('IdentitiesOnly yes\n'));
    });

    test('updates a matching block in place, keeping other options', () {
      const existing = '''
# personal hosts
Host prod
    HostName old.example
    User root
    ForwardAgent yes   # keep me
    IdentityFile ~/.ssh/old_a
    IdentityFile ~/.ssh/old_b

Host other
    HostName 1.1.1.1
''';
      final merged = mergeSshConfig(existing, _entry);
      expect(merged, '''
# personal hosts
Host prod
    Port 2222
    IdentitiesOnly yes
    HostName 10.0.0.5
    User deploy
    ForwardAgent yes   # keep me
    IdentityFile ~/.ssh/conduit_prod_ed25519

Host other
    HostName 1.1.1.1
''');
    });

    test('matches aliases case-insensitively and on multi-pattern lines', () {
      const existing = 'Host staging PROD\n  HostName x\n';
      final merged = mergeSshConfig(existing, _entry);
      expect(merged, contains('Host staging PROD\n'));
      expect(merged, contains('  HostName 10.0.0.5\n'));
      expect(merged.split('Host ').length, 2); // no second block appended
    });

    test('does not treat a prefix or HostName line as a match', () {
      const existing = 'Host prod-old\n  HostName prod\n';
      final merged = mergeSshConfig(existing, _entry);
      expect(merged, contains('Host prod-old\n  HostName prod\n'));
      expect(merged, contains('\nHost prod\n  HostName 10.0.0.5\n'));
    });

    test('stops the block at the next Host or Match directive', () {
      const existing = 'Host prod\n  User root\nMatch all\n  User nobody\n';
      final merged = mergeSshConfig(existing, _entry);
      expect(merged, contains('Match all\n  User nobody\n'));
      expect(merged, contains('  User deploy\n'));
    });

    test('omits IdentityFile for password logins and keeps existing ones', () {
      const passwordEntry = SshConfigEntry(
        alias: 'prod',
        hostName: '10.0.0.5',
        user: 'deploy',
        port: 22,
      );
      expect(mergeSshConfig('', passwordEntry), '''
Host prod
  HostName 10.0.0.5
  User deploy
  Port 22
''');
      const existing = 'Host prod\n  HostName x\n  IdentityFile ~/.ssh/mine\n';
      final merged = mergeSshConfig(existing, passwordEntry);
      expect(merged, contains('  IdentityFile ~/.ssh/mine\n'));
      expect(merged, isNot(contains('IdentitiesOnly')));
    });

    test('is idempotent', () {
      final once = mergeSshConfig('', _entry);
      expect(mergeSshConfig(once, _entry), once);
    });
  });

  group('syncSshConfigFile', () {
    test('creates the file with mode 600 and merges into it', () async {
      final dir = Directory.systemTemp.createTempSync('ssh_config_sync');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/nested/config';

      final written = await syncSshConfigFile(_entry, configPath: path);
      expect(written, path);
      expect(await File(path).readAsString(), contains('Host prod\n'));
      final mode = await Process.run('stat', ['-f', '%Lp', path]);
      expect((mode.stdout as String).trim(), '600');

      // Second sync with a changed host updates rather than duplicates.
      await syncSshConfigFile(
        const SshConfigEntry(
          alias: 'prod',
          hostName: '10.0.0.9',
          user: 'deploy',
          port: 22,
          identityFile: '~/.ssh/k',
        ),
        configPath: path,
      );
      final text = await File(path).readAsString();
      expect('Host prod'.allMatches(text).length, 1);
      expect(text, contains('HostName 10.0.0.9'));
      expect(text, isNot(contains('10.0.0.5')));
    }, skip: !Platform.isMacOS);
  });

  group('parseSshConfigHosts', () {
    test('parses blocks with options, patterns, and wildcards', () {
      const config = '''
# global comment
Host prod staging
  HostName 10.0.0.5
  User deploy
  Port 2200
  IdentityFile ~/.ssh/prod
  IdentityFile ~/.ssh/backup

Host *
  ServerAliveInterval 60

Host bare
''';
      final hosts = parseSshConfigHosts(config);
      expect(hosts, hasLength(3));
      expect(hosts[0].alias, 'prod');
      expect(hosts[0].extraPatterns, ['staging']);
      expect(hosts[0].hostName, '10.0.0.5');
      expect(hosts[0].user, 'deploy');
      expect(hosts[0].port, 2200);
      // First value wins, like OpenSSH.
      expect(hosts[0].identityFile, '~/.ssh/prod');
      expect(hosts[0].isWildcard, isFalse);
      expect(hosts[1].alias, '*');
      expect(hosts[1].isWildcard, isTrue);
      expect(hosts[2].alias, 'bare');
      expect(hosts[2].hostName, isNull);
    });

    test('empty content parses to no hosts', () {
      expect(parseSshConfigHosts(''), isEmpty);
    });
  });

  group('removeSshConfigHost', () {
    const config = '''
Host a
  HostName 1.1.1.1

Host b
  HostName 2.2.2.2

Host c
  HostName 3.3.3.3
''';

    test('removes a middle block without leaving a double gap', () {
      final result = removeSshConfigHost(config, 'b');
      expect(result, isNot(contains('Host b')));
      expect(result, contains('Host a'));
      expect(result, contains('Host c'));
      expect(result, isNot(contains('\n\n\n')));
    });

    test('removes the last block and trailing blank lines', () {
      final result = removeSshConfigHost(config, 'c');
      expect(result, isNot(contains('Host c')));
      expect(result.endsWith('2.2.2.2\n'), isTrue);
    });

    test('unknown alias leaves the text unchanged', () {
      expect(removeSshConfigHost(config, 'nope'), config);
    });

    test('removing the only block empties the file', () {
      expect(removeSshConfigHost('Host a\n  HostName 1.1.1.1\n', 'a'), '');
    });
  });
}
