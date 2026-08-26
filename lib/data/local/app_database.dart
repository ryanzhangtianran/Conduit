import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Servers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get host => text()();
  IntColumn get port => integer().withDefault(const Constant(22))();
  TextColumn get username => text()();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get credentialId => integer().nullable()();
  TextColumn get hostKeyFingerprint => text().nullable()();
  BoolColumn get collectStats => boolean().withDefault(const Constant(true))();
  BoolColumn get collectSystemInfo =>
      boolean().withDefault(const Constant(true))();
  // Optional per-server HTTP CONNECT / SOCKS5 proxy. The password is
  // encrypted with the vault key, mirroring the saved-credential columns.
  TextColumn get proxyType => text().nullable()();
  TextColumn get proxyHost => text().nullable()();
  IntColumn get proxyPort => integer().nullable()();
  TextColumn get proxyUsername => text().nullable()();
  TextColumn get encryptedProxyPassword => text().nullable()();
  TextColumn get proxyPasswordNonce => text().nullable()();
  // Optional SSH jump host. The referenced server may itself have a jump
  // host, allowing chained routes.
  IntColumn get jumpHostServerId => integer().nullable()();
  // Per-server configuration, JSON-encoded. Environment is a map of variable
  // names to values, and tags is a list of free-form labels.
  TextColumn get environment => text().nullable()();
  TextColumn get tags => text().nullable()();
  // Connection transport; only `ssh` is supported.
  TextColumn get connectionType => text().withDefault(const Constant('ssh'))();
  // User-controlled display order on the server dashboard. Rows without a
  // value (legacy rows and imports) sort after explicitly ordered ones.
  IntColumn get sortOrder => integer().nullable()();
}

/// An encrypted SSH credential that may be linked to by more than one server.
/// The encrypted payload remains protected by the user's vault key.
class SavedCredentials extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get credentialType => text()();
  TextColumn get encryptedCredential => text()();
  TextColumn get credentialNonce => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class VaultMetadata extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get formatVersion => integer()();
  TextColumn get salt => text()();
  TextColumn get wrappedDataKey => text()();
  TextColumn get wrappedDataKeyNonce => text()();
  TextColumn get verifier => text()();
  TextColumn get verifierNonce => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// A GitHub account the user signed in with. Only non-secret identity is kept
/// here; the access token lives in [GitHubTokens], encrypted with the vault
/// key, and never enters this table or the portable payload in clear text.
class GitHubConnections extends Table {
  @override
  String get tableName => 'github_connections';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountLogin => text().unique()();
  TextColumn get accountName => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Repositories pinned to the GitHub tab. Metadata only, safe to sync.
class GitHubRepoPins extends Table {
  @override
  String get tableName => 'github_repo_pins';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get connectionId => integer().references(GitHubConnections, #id)();
  TextColumn get owner => text()();
  TextColumn get name => text()();
  DateTimeColumn get pinnedAt => dateTime()();
}

/// GitHub access tokens, encrypted with the vault data key. Tokens live
/// inside the vault so they sync with it and survive vault migration; only
/// the ciphertext is stored, keyed by [accountLogin] like the connection.
class GitHubTokens extends Table {
  @override
  String get tableName => 'github_tokens';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountLogin => text().unique()();
  TextColumn get encryptedToken => text()();
  TextColumn get tokenNonce => text()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// A saved port-forwarding preset (Termius-style). A preset is metadata only:
/// it reuses the server's existing SSH connection and contains no credentials.
/// When [autoStart] is set, the forward is started automatically every time
/// the server connects.
class PortForwardConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer()();
  TextColumn get direction => text()();
  TextColumn get kind => text()();
  TextColumn get bindHost => text()();
  IntColumn get bindPort => integer()();
  TextColumn get targetHost => text()();
  IntColumn get targetPort => integer()();
  BoolColumn get autoStart => boolean().withDefault(const Constant(false))();

  /// Re-establish the forward with backoff whenever it drops while the SSH
  /// session itself stays connected.
  BoolColumn get keepAlive => boolean().withDefault(const Constant(false))();

  /// Manual position in the forward table; null sorts after ordered rows,
  /// then by creation time.
  IntColumn get sortOrder => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Vault-synced app preferences (key-value). Rows travel with the vault file
/// like every other table, so preferences follow the user across devices.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Servers,
    SavedCredentials,
    VaultMetadata,
    GitHubConnections,
    GitHubRepoPins,
    GitHubTokens,
    PortForwardConfigs,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the legacy app database when [filePath] is omitted, or a user
  /// selected vault database when it is provided.
  AppDatabase({String? filePath})
    : super(
        driftDatabase(
          name: filePath ?? 'conduit',
          native: filePath == null
              ? null
              : DriftNativeOptions(databasePath: () async => filePath),
        ),
      );

  @override
  int get schemaVersion => 41;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX servers_sync_id_unique ON servers (sync_id)',
      );
      await customStatement(
        'CREATE UNIQUE INDEX github_repo_pins_unique '
        'ON github_repo_pins (connection_id, owner, name)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(servers, servers.syncId);
        await m.addColumn(servers, servers.createdAt);
        await m.addColumn(servers, servers.updatedAt);
        await m.addColumn(servers, servers.deletedAt);
        // The per-server credential columns were dropped in schema 41, but
        // the schema-9 step below still reads them to build saved_credentials.
        await customStatement(
          'ALTER TABLE servers ADD COLUMN credential_type TEXT NULL',
        );
        await customStatement(
          'ALTER TABLE servers ADD COLUMN encrypted_credential TEXT NULL',
        );
        await customStatement(
          'ALTER TABLE servers ADD COLUMN credential_nonce TEXT NULL',
        );
        await m.createTable(vaultMetadata);
        await customStatement(
          'CREATE UNIQUE INDEX servers_sync_id_unique ON servers (sync_id)',
        );
      }
      if (from < 3) {
        await m.addColumn(servers, servers.hostKeyFingerprint);
      }
      if (from < 4) {
        await m.addColumn(servers, servers.collectStats);
        await m.addColumn(servers, servers.collectSystemInfo);
      }
      if (from < 9) {
        await m.createTable(savedCredentials);
        await m.addColumn(servers, servers.credentialId);
        // Each pre-relationship server gets its own saved credential. Keeping
        // the original ciphertext means no vault unlock is required here.
        await customStatement('''
          INSERT INTO saved_credentials
            (name, credential_type, encrypted_credential, credential_nonce, created_at, updated_at)
          SELECT name, credential_type, encrypted_credential, credential_nonce,
            COALESCE(created_at, CURRENT_TIMESTAMP), COALESCE(updated_at, CURRENT_TIMESTAMP)
          FROM servers
          WHERE encrypted_credential IS NOT NULL
            AND credential_nonce IS NOT NULL
            AND credential_type IS NOT NULL
        ''');
        await customStatement('''
          UPDATE servers
          SET credential_id = (
            SELECT saved_credentials.id FROM saved_credentials
            WHERE saved_credentials.name = servers.name
              AND saved_credentials.encrypted_credential = servers.encrypted_credential
              AND saved_credentials.credential_nonce = servers.credential_nonce
            ORDER BY saved_credentials.id DESC LIMIT 1
          )
          WHERE encrypted_credential IS NOT NULL AND credential_nonce IS NOT NULL
        ''');
      }
      // Schema 10 added vault_metadata.sync_passphrase_* for the removed
      // cloud sync feature; schema 41 drops them again, so nothing is added
      // here for databases older than 10.
      if (from < 18) {
        await m.addColumn(servers, servers.proxyType);
        await m.addColumn(servers, servers.proxyHost);
        await m.addColumn(servers, servers.proxyPort);
        await m.addColumn(servers, servers.proxyUsername);
        await m.addColumn(servers, servers.encryptedProxyPassword);
        await m.addColumn(servers, servers.proxyPasswordNonce);
      }
      if (from < 19) {
        await m.createTable(gitHubConnections);
        await m.createTable(gitHubRepoPins);
        await customStatement(
          'CREATE UNIQUE INDEX github_repo_pins_unique '
          'ON github_repo_pins (connection_id, owner, name)',
        );
      }
      if (from < 20) {
        await m.addColumn(servers, servers.environment);
        await m.addColumn(servers, servers.tags);
      }
      if (from < 21) {
        // Workflow links became a regular deployment resource (kind
        // `githubWorkflow`, configuration JSON) in schema 21.
        await customStatement(
          'DROP TABLE IF EXISTS github_project_workflow_links',
        );
      }
      if (from < 22) {
        await m.addColumn(servers, servers.connectionType);
      }
      if (from < 23) {
        // Some development builds wrote a servers table that already
        // contained sort_order while still reporting schema 22. Guard the
        // ALTER so those databases upgrade instead of crashing on a
        // duplicate column.
        final hasSortOrder = await customSelect(
          "SELECT 1 FROM pragma_table_info('servers') "
          "WHERE name = 'sort_order'",
        ).get();
        if (hasSortOrder.isEmpty) {
          await m.addColumn(servers, servers.sortOrder);
        }
        // Preserve the current (creation-id) dashboard order for existing
        // servers; new servers are appended after the largest sort order.
        await customStatement(
          'UPDATE servers SET sort_order = id WHERE sort_order IS NULL',
        );
      }
      if (from < 24) {
        final hasJumpHostServerId = await customSelect(
          "SELECT 1 FROM pragma_table_info('servers') "
          "WHERE name = 'jump_host_server_id'",
        ).get();
        if (hasJumpHostServerId.isEmpty) {
          await m.addColumn(servers, servers.jumpHostServerId);
        }
      }
      if (from < 27) {
        await m.createTable(gitHubTokens);
      }
      if (from < 28) {
        await m.createTable(portForwardConfigs);
      }
      if (from < 31) {
        await m.createTable(appSettings);
      }
      if (from < 33) {
        // Schema 32 stored the (since removed) embedded Tailscale auth key on
        // the vault; drop the columns from databases that gained them.
        final tailscaleColumns = await customSelect(
          "SELECT name FROM pragma_table_info('vault_metadata') "
          "WHERE name IN ('encrypted_tailscale_auth_key', "
          "'tailscale_auth_key_nonce')",
        ).get();
        for (final row in tailscaleColumns) {
          await customStatement(
            'ALTER TABLE vault_metadata DROP COLUMN ${row.read<String>('name')}',
          );
        }
      }
      if (from < 34) {
        // Schema 34 removed the AI agent and deployment projects features;
        // drop their tables from databases that gained them. The guards also
        // cover databases that skipped the intermediate schemas.
        for (final table in const [
          'compose_project_links',
          'deployment_projects',
          'deployment_resources',
          'agent_settings',
          'agent_providers',
          'agent_provider_models',
          'agent_conversations',
          'mcp_servers',
          'agent_skills',
        ]) {
          await customStatement('DROP TABLE IF EXISTS $table');
        }
      }
      if (from < 35) {
        // Schema 35 removed the script snippets feature.
        await customStatement('DROP TABLE IF EXISTS script_snippets');
        final snippetColumn = await customSelect(
          "SELECT name FROM pragma_table_info('servers') "
          "WHERE name = 'initial_snippets'",
        ).get();
        if (snippetColumn.isNotEmpty) {
          await customStatement(
            'ALTER TABLE servers DROP COLUMN initial_snippets',
          );
        }
      }
      if (from < 36) {
        // Schema 36 removed the container management feature and its cache.
        await customStatement('DROP TABLE IF EXISTS container_cache_entries');
      }
      if (from < 37) {
        // Schema 37 removed the runtimes feature (and the watched-process
        // cards that shared its table) along with services and crontab.
        await customStatement('DROP TABLE IF EXISTS runtime_watch_configs');
      }
      if (from < 38) {
        // Schema 38 removed the MaidCafe daemon integration; its per-server
        // endpoint and secret columns go with it.
        for (final column in const [
          'maid_cafe_daemon_url',
          'encrypted_maid_cafe_webhook_secret',
          'maid_cafe_webhook_secret_nonce',
          'encrypted_maid_cafe_metrics_secret',
          'maid_cafe_metrics_secret_nonce',
        ]) {
          final present = await customSelect(
            "SELECT 1 FROM pragma_table_info('servers') WHERE name = ?",
            variables: [Variable.withString(column)],
          ).get();
          if (present.isNotEmpty) {
            await customStatement('ALTER TABLE servers DROP COLUMN $column');
          }
        }
      }
      if (from < 39) {
        // Schema 39 folded the local proxy tunnel into ordinary saved
        // forwards: supervision became a per-preset property. (The
        // proxy_scheme column added alongside it was never used and is
        // dropped again in schema 41.)
        final present = await customSelect(
          "SELECT 1 FROM pragma_table_info('port_forward_configs') "
          "WHERE name = 'keep_alive'",
        ).get();
        if (present.isEmpty) {
          await customStatement(
            'ALTER TABLE port_forward_configs '
            'ADD COLUMN keep_alive INTEGER NOT NULL DEFAULT 0',
          );
        }
      }
      if (from < 40) {
        // Schema 40 adds a manual order to saved forwards. Older steps may
        // have (re)created the table from the current definition, which
        // already carries the column.
        final present = await customSelect(
          "SELECT 1 FROM pragma_table_info('port_forward_configs') "
          "WHERE name = 'sort_order'",
        ).get();
        if (present.isEmpty) {
          await m.addColumn(portForwardConfigs, portForwardConfigs.sortOrder);
        }
      }
      if (from < 41) {
        // Schema 41 drops columns nothing reads any more: the pre-schema-9
        // per-server credential ciphertext (credentials live in
        // saved_credentials), the never-shipped serial-port config, the
        // unused host key algorithm, the port-forward proxy scheme, and the
        // removed cloud-sync passphrase.
        Future<void> dropColumn(String table, String column) async {
          final present = await customSelect(
            "SELECT 1 FROM pragma_table_info('$table') WHERE name = ?",
            variables: [Variable.withString(column)],
          ).get();
          if (present.isNotEmpty) {
            await customStatement('ALTER TABLE $table DROP COLUMN $column');
          }
        }

        for (final column in const [
          'credential_type',
          'encrypted_credential',
          'credential_nonce',
          'serial_config',
          'host_key_algorithm',
        ]) {
          await dropColumn('servers', column);
        }
        await dropColumn('port_forward_configs', 'proxy_scheme');
        for (final column in const [
          'sync_passphrase_ciphertext',
          'sync_passphrase_nonce',
        ]) {
          await dropColumn('vault_metadata', column);
        }
      }
    },
  );

  /// Live servers in dashboard order: manual positions first, then by id.
  SimpleSelectStatement<$ServersTable, Server> _activeServers() =>
      select(servers)
        ..where((table) => table.deletedAt.isNull())
        ..orderBy([
          (table) => OrderingTerm.asc(table.sortOrder.isNull()),
          (table) => OrderingTerm.asc(table.sortOrder),
          (table) => OrderingTerm.asc(table.id),
        ]);

  Stream<List<Server>> watchServers() => _activeServers().watch();

  Future<List<Server>> getServers() => _activeServers().get();

  Stream<List<GitHubConnection>> watchGitHubConnections() => (select(
    gitHubConnections,
  )..orderBy([(table) => OrderingTerm.asc(table.accountLogin)])).watch();

  Stream<List<GitHubRepoPin>> watchGitHubRepoPins() =>
      select(gitHubRepoPins).watch();

  /// Saved forwards in display order: manual positions first, then by
  /// creation time; optionally limited to one server.
  SimpleSelectStatement<$PortForwardConfigsTable, PortForwardConfig>
  _orderedPortForwardConfigs({int? serverId}) {
    final query = select(portForwardConfigs)
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder.isNull()),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);
    if (serverId != null) {
      query.where((table) => table.serverId.equals(serverId));
    }
    return query;
  }

  Stream<List<PortForwardConfig>> watchPortForwardConfigs(int serverId) =>
      _orderedPortForwardConfigs(serverId: serverId).watch();

  Stream<List<PortForwardConfig>> watchAllPortForwardConfigs() =>
      _orderedPortForwardConfigs().watch();

  Stream<String?> watchAppSetting(String key) =>
      (select(appSettings)..where((table) => table.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<String?> getAppSetting(String key) async => (await (select(
    appSettings,
  )..where((table) => table.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setAppSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<List<PortForwardConfig>> portForwardConfigsForServer(int serverId) =>
      _orderedPortForwardConfigs(serverId: serverId).get();
}
