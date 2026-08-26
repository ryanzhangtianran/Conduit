import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/data/local/app_database.dart';

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

void main() {
  _mockPathProvider();

  group('AppDatabase migrations', () {
    test(
      'schema 22 database that already has sort_order migrates to 41',
      () async {
        final directory = Directory.systemTemp.createTempSync('migration_test');
        final path = '${directory.path}/stale.sqlite';

        // Reproduce the state left behind by pre-release builds: a servers
        // table that already contains sort_order while user_version still
        // reports 22.
        final seeded = AppDatabase(filePath: path);
        await seeded
            .into(seeded.servers)
            .insert(
              ServersCompanion.insert(
                name: 'legacy',
                host: '10.0.0.1',
                username: 'root',
              ),
            );
        await seeded.customStatement('PRAGMA user_version = 22');
        await seeded.close();

        // Opening the database again runs the 22 -> 41 migrations, which
        // must not fail with a duplicate column error.
        final database = AppDatabase(filePath: path);
        final version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 41);

        // The order backfill still ran, so the legacy row keeps its
        // creation-id position.
        final row = await database
            .customSelect(
              'SELECT sort_order FROM servers WHERE name = ?',
              variables: [Variable('legacy')],
            )
            .getSingle();
        expect(row.read<int>('sort_order'), 1);

        // The GitHub token table is created for vault-backed token storage.
        final tokenTable = await database
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'table' AND name = 'github_tokens'",
            )
            .get();
        expect(tokenTable, isNotEmpty);

        // Saved port-forwarding presets are created in schema 28.
        final presetTable = await database
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'table' AND name = 'port_forward_configs'",
            )
            .get();
        expect(presetTable, isNotEmpty);

        // Schema 37 dropped the runtimes feature's watch-config table.
        final runtimeTable = await database
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'table' AND name = 'runtime_watch_configs'",
            )
            .get();
        expect(runtimeTable, isEmpty);

        // Vault-synced app preferences are created in schema 31.
        final settingsTable = await database
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'table' AND name = 'app_settings'",
            )
            .get();
        expect(settingsTable, isNotEmpty);

        // Schema 33 removed the embedded Tailscale auth key columns.
        final authKeyColumns = await database
            .customSelect(
              "SELECT name FROM pragma_table_info('vault_metadata') "
              "WHERE name IN ('encrypted_tailscale_auth_key', "
              "'tailscale_auth_key_nonce')",
            )
            .get();
        expect(authKeyColumns, isEmpty);
        await database.close();
      },
    );
    test('schema 22 without sort_order adds the column', () async {
      final directory = Directory.systemTemp.createTempSync('migration_test');
      final path = '${directory.path}/clean.sqlite';

      final seeded = AppDatabase(filePath: path);
      await seeded.customStatement(
        'ALTER TABLE servers DROP COLUMN sort_order',
      );
      await seeded.customStatement('PRAGMA user_version = 22');
      await seeded.close();

      final database = AppDatabase(filePath: path);
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 41);

      final column = await database
          .customSelect(
            "SELECT name FROM pragma_table_info('servers') "
            "WHERE name = 'sort_order'",
          )
          .get();
      expect(column, isNotEmpty);
      await database.close();
    });
    test('schema 41 drops the unused legacy columns', () async {
      final directory = Directory.systemTemp.createTempSync('migration_test');
      final path = '${directory.path}/legacy.sqlite';

      // Recreate the columns a schema-40 database still carried.
      final seeded = AppDatabase(filePath: path);
      for (final statement in const [
        'ALTER TABLE servers ADD COLUMN credential_type TEXT NULL',
        'ALTER TABLE servers ADD COLUMN encrypted_credential TEXT NULL',
        'ALTER TABLE servers ADD COLUMN credential_nonce TEXT NULL',
        'ALTER TABLE servers ADD COLUMN serial_config TEXT NULL',
        'ALTER TABLE servers ADD COLUMN host_key_algorithm TEXT NULL',
        'ALTER TABLE port_forward_configs ADD COLUMN proxy_scheme TEXT NULL',
        'ALTER TABLE vault_metadata '
            'ADD COLUMN sync_passphrase_ciphertext TEXT NULL',
        'ALTER TABLE vault_metadata ADD COLUMN sync_passphrase_nonce TEXT NULL',
      ]) {
        await seeded.customStatement(statement);
      }
      await seeded
          .into(seeded.servers)
          .insert(
            ServersCompanion.insert(
              name: 'kept',
              host: '10.0.0.2',
              username: 'root',
            ),
          );
      await seeded.customStatement('PRAGMA user_version = 40');
      await seeded.close();

      final database = AppDatabase(filePath: path);
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 41);

      Future<List<String>> columnsOf(String table) async {
        final rows = await database
            .customSelect("SELECT name FROM pragma_table_info('$table')")
            .get();
        return [for (final row in rows) row.read<String>('name')];
      }

      expect(
        await columnsOf('servers'),
        isNot(
          anyOf(
            contains('credential_type'),
            contains('encrypted_credential'),
            contains('credential_nonce'),
            contains('serial_config'),
            contains('host_key_algorithm'),
          ),
        ),
      );
      expect(await columnsOf('servers'), contains('host_key_fingerprint'));
      expect(
        await columnsOf('port_forward_configs'),
        isNot(contains('proxy_scheme')),
      );
      expect(
        await columnsOf('vault_metadata'),
        isNot(
          anyOf(
            contains('sync_passphrase_ciphertext'),
            contains('sync_passphrase_nonce'),
          ),
        ),
      );
      // Existing rows survive the column drops.
      final rows = await database
          .customSelect('SELECT name FROM servers')
          .get();
      expect(rows.map((row) => row.read<String>('name')), ['kept']);
      await database.close();
    });
  });
}
