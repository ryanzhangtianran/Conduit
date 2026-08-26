import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:conduit/data/local/app_database.dart';
import 'port_forwarding_models.dart';
import 'server_models.dart';
import 'vault_service.dart';

class ServerRepository {
  ServerRepository(this._database, this._vault);

  final AppDatabase _database;
  final VaultService _vault;
  final Uuid _uuid = const Uuid();

  Stream<List<Server>> watchAll() => _database.watchServers();

  Future<List<Server>> all() => _database.getServers();

  Future<Server> create(ServerDraft draft) async {
    final now = DateTime.now().toUtc();
    final credentialId = await _credentialIdForDraft(draft, now);
    final proxyPassword =
        draft.proxy?.password == null || draft.proxy!.password!.isEmpty
        ? null
        : await _vault.encrypt(
            draft.proxy!.password!,
            context: 'server-proxy-password',
          );
    final id = await _database.transaction(() async {
      final maxOrder =
          await (_database.selectOnly(_database.servers)
                ..addColumns([_database.servers.sortOrder.max()])
                ..where(_database.servers.deletedAt.isNull()))
              .getSingle();
      final nextOrder =
          (maxOrder.read(_database.servers.sortOrder.max()) ?? -1) + 1;
      return _database
          .into(_database.servers)
          .insert(
            ServersCompanion.insert(
              name: draft.name.trim(),
              host: draft.host.trim(),
              port: Value(draft.port),
              username: draft.username.trim(),
              syncId: Value(_uuid.v4()),
              createdAt: Value(now),
              updatedAt: Value(now),
              credentialId: Value(credentialId),
              collectStats: Value(draft.collectStats),
              proxyType: Value(draft.proxy?.type.name),
              proxyHost: Value(draft.proxy?.host),
              proxyPort: Value(draft.proxy?.port),
              proxyUsername: Value(draft.proxy?.username),
              encryptedProxyPassword: Value(proxyPassword?.bytes),
              proxyPasswordNonce: Value(proxyPassword?.nonce),
              jumpHostServerId: Value(draft.jumpHostServerId),
              environment: Value(encodeEnvironmentMap(draft.environment)),
              tags: Value(encodeStringList(draft.tags)),
              connectionType: Value(draft.connectionType.name),
              sortOrder: Value(nextOrder),
            ),
          );
    });
    return (_database.select(
      _database.servers,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> update(Server server, ServerDraft draft) async {
    final credentialId = await _credentialIdForUpdate(
      server,
      draft,
      DateTime.now().toUtc(),
    );
    final proxy = draft.proxy;
    // A new password replaces the stored one. Leaving the field blank keeps
    // the existing encrypted password, and removing the proxy clears it.
    final proxyPassword = proxy?.password == null
        ? null
        : proxy!.password!.isEmpty
        ? null
        : await _vault.encrypt(
            proxy.password!,
            context: 'server-proxy-password',
          );
    await (_database.update(
      _database.servers,
    )..where((table) => table.id.equals(server.id))).write(
      ServersCompanion(
        name: Value(draft.name.trim()),
        host: Value(draft.host.trim()),
        port: Value(draft.port),
        username: Value(draft.username.trim()),
        credentialId: Value(credentialId),
        collectStats: Value(draft.collectStats),
        collectSystemInfo: Value(draft.collectSystemInfo),
        proxyType: Value(proxy?.type.name),
        proxyHost: Value(proxy?.host),
        proxyPort: Value(proxy?.port),
        proxyUsername: Value(proxy?.username),
        encryptedProxyPassword: proxy == null
            ? const Value(null)
            : proxyPassword == null
            ? const Value.absent()
            : Value(proxyPassword.bytes),
        proxyPasswordNonce: proxy == null
            ? const Value(null)
            : proxyPassword == null
            ? const Value.absent()
            : Value(proxyPassword.nonce),
        jumpHostServerId: Value(draft.jumpHostServerId),
        environment: Value(encodeEnvironmentMap(draft.environment)),
        tags: Value(encodeStringList(draft.tags)),
        connectionType: Value(draft.connectionType.name),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await _pruneOrphanCredentials();
  }

  /// Each server owns its credential: an edited credential updates the
  /// server's own row in place. A row still shared with other servers
  /// (legacy data from the former credential picker) is left alone and the
  /// server gets a private copy instead.
  Future<int?> _credentialIdForUpdate(
    Server server,
    ServerDraft draft,
    DateTime now,
  ) async {
    final credential = draft.credential;
    if (credential == null) return draft.credentialId ?? server.credentialId;
    final existingId = server.credentialId;
    if (existingId != null) {
      final otherUsers =
          await (_database.selectOnly(_database.servers)
                ..addColumns([_database.servers.id])
                ..where(_database.servers.credentialId.equals(existingId))
                ..where(_database.servers.id.isNotValue(server.id)))
              .get();
      if (otherUsers.isEmpty) {
        final encrypted = await _vault.encrypt(
          credential.encode(),
          context: 'server-credential',
        );
        await (_database.update(
          _database.savedCredentials,
        )..where((table) => table.id.equals(existingId))).write(
          SavedCredentialsCompanion(
            name: Value(draft.name.trim()),
            credentialType: Value(credential.type.name),
            encryptedCredential: Value(encrypted.bytes),
            credentialNonce: Value(encrypted.nonce),
            updatedAt: Value(now),
          ),
        );
        return existingId;
      }
    }
    return _credentialIdForDraft(
      ServerDraft(
        name: draft.name,
        host: draft.host,
        port: draft.port,
        username: draft.username,
        credential: credential,
        credentialName: draft.credentialName,
      ),
      now,
    );
  }

  /// Deletes credential rows no server references at all. Soft-deleted
  /// servers keep their credential so restoring them still authenticates.
  Future<void> _pruneOrphanCredentials() async {
    final referenced =
        await (_database.selectOnly(_database.servers, distinct: true)
              ..addColumns([_database.servers.credentialId])
              ..where(_database.servers.credentialId.isNotNull()))
            .get();
    final ids = referenced
        .map((row) => row.read(_database.servers.credentialId))
        .whereType<int>()
        .toList();
    final query = _database.delete(_database.savedCredentials);
    if (ids.isNotEmpty) {
      query.where((table) => table.id.isNotIn(ids));
    }
    await query.go();
  }

  Future<void> setJumpHostServerId(int serverId, int? jumpHostServerId) =>
      (_database.update(
        _database.servers,
      )..where((table) => table.id.equals(serverId))).write(
        ServersCompanion(
          jumpHostServerId: Value(jumpHostServerId),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<ServerCredential> credentialFor(Server server) async {
    final credential = await _credentialRecordFor(server);
    final value = await _vault.decrypt(
      EncryptedValue(
        bytes: credential.encryptedCredential,
        nonce: credential.credentialNonce,
      ),
      context: 'server-credential',
    );
    return ServerCredential.decode(value);
  }

  /// Returns the server's configured proxy with its password decrypted, or
  /// null when the server does not use a proxy.
  Future<ServerProxy?> proxyFor(Server server) async {
    final type = server.proxyType;
    final host = server.proxyHost;
    if (type == null ||
        type == ServerProxyType.none.name ||
        host == null ||
        host.isEmpty) {
      return null;
    }
    String? password;
    if (server.encryptedProxyPassword != null &&
        server.proxyPasswordNonce != null) {
      password = await _vault.decrypt(
        EncryptedValue(
          bytes: server.encryptedProxyPassword!,
          nonce: server.proxyPasswordNonce!,
        ),
        context: 'server-proxy-password',
      );
    }
    return ServerProxy(
      type: ServerProxyType.values.byName(type),
      host: host,
      port: server.proxyPort ?? 1080,
      username: server.proxyUsername,
      password: password,
    );
  }

  Stream<List<PortForwardConfig>> watchPortForwardConfigs(int serverId) =>
      _database.watchPortForwardConfigs(serverId);

  Stream<List<PortForwardConfig>> watchAllPortForwardConfigs() =>
      _database.watchAllPortForwardConfigs();

  Stream<String?> watchAppSetting(String key) => _database.watchAppSetting(key);

  Future<String?> getAppSetting(String key) => _database.getAppSetting(key);

  Future<void> setAppSetting(String key, String value) =>
      _database.setAppSetting(key, value);

  Future<List<PortForwardConfig>> portForwardConfigsForServer(int serverId) =>
      _database.portForwardConfigsForServer(serverId);

  /// Persists a port-forwarding preset. Saving the same forward (same server,
  /// direction, kind and endpoints) again updates the existing preset instead
  /// of creating a duplicate; [autoStart] can only turn auto-start on.
  Future<void> savePortForwardConfig({
    required int serverId,
    required PortForwardDirection direction,
    required PortForwardKind kind,
    required String bindHost,
    required int bindPort,
    required String targetHost,
    required int targetPort,
    bool autoStart = false,
    bool keepAlive = false,
  }) async {
    final now = DateTime.now().toUtc();
    final existing =
        await (_database.select(_database.portForwardConfigs)..where(
              (table) =>
                  table.serverId.equals(serverId) &
                  table.direction.equals(direction.name) &
                  table.kind.equals(kind.name) &
                  table.bindHost.equals(bindHost) &
                  table.bindPort.equals(bindPort) &
                  table.targetHost.equals(targetHost) &
                  table.targetPort.equals(targetPort),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await _database
          .into(_database.portForwardConfigs)
          .insert(
            PortForwardConfigsCompanion.insert(
              serverId: serverId,
              direction: direction.name,
              kind: kind.name,
              bindHost: bindHost,
              bindPort: bindPort,
              targetHost: targetHost,
              targetPort: targetPort,
              autoStart: Value(autoStart),
              keepAlive: Value(keepAlive),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_database.update(
        _database.portForwardConfigs,
      )..where((table) => table.id.equals(existing.id))).write(
        PortForwardConfigsCompanion(
          autoStart: Value(existing.autoStart || autoStart),
          keepAlive: Value(existing.keepAlive || keepAlive),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> setPortForwardConfigKeepAlive(int id, bool keepAlive) =>
      (_database.update(
        _database.portForwardConfigs,
      )..where((table) => table.id.equals(id))).write(
        PortForwardConfigsCompanion(
          keepAlive: Value(keepAlive),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> setPortForwardConfigAutoStart(int id, bool autoStart) =>
      (_database.update(
        _database.portForwardConfigs,
      )..where((table) => table.id.equals(id))).write(
        PortForwardConfigsCompanion(
          autoStart: Value(autoStart),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> deletePortForwardConfig(int id) => (_database.delete(
    _database.portForwardConfigs,
  )..where((table) => table.id.equals(id))).go();

  Future<SavedCredential> _credentialRecordFor(Server server) async {
    final id = server.credentialId;
    if (id == null) {
      throw StateError('This server has no saved credential.');
    }
    return (_database.select(
      _database.savedCredentials,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  Future<int?> _credentialIdForDraft(ServerDraft draft, DateTime now) async {
    if (draft.credentialId case final id?) return id;
    final credential = draft.credential;
    // Credential-less servers are allowed (e.g. imported redacted connection
    // lists); the user assigns a credential later in the edit form.
    if (credential == null) return null;
    final encrypted = await _vault.encrypt(
      credential.encode(),
      context: 'server-credential',
    );
    return _database
        .into(_database.savedCredentials)
        .insert(
          SavedCredentialsCompanion.insert(
            name: draft.credentialName?.trim().isNotEmpty == true
                ? draft.credentialName!.trim()
                : draft.name.trim(),
            credentialType: credential.type.name,
            encryptedCredential: encrypted.bytes,
            credentialNonce: encrypted.nonce,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> markConnected(int id) =>
      (_database.update(
        _database.servers,
      )..where((t) => t.id.equals(id))).write(
        ServersCompanion(
          lastConnectedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Persists the dashboard display order. [orderedIds] must list every
  /// non-deleted server id exactly once; each server's position in the list
  /// becomes its [Server.sortOrder].
  Future<void> reorderServers(List<int> orderedIds) async {
    final now = DateTime.now().toUtc();
    await _database.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _database.servers,
          ServersCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          where: (table) => table.id.equals(orderedIds[i]),
        );
      }
    });
  }

  /// Persists the manual order of saved forwards (ids in display order).
  Future<void> reorderPortForwardConfigs(List<int> orderedIds) async {
    final now = DateTime.now().toUtc();
    await _database.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _database.portForwardConfigs,
          PortForwardConfigsCompanion(
            sortOrder: Value(i),
            updatedAt: Value(now),
          ),
          where: (table) => table.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<void> rememberHostKey(int id, HostKeyPrompt hostKey) =>
      (_database.update(
        _database.servers,
      )..where((table) => table.id.equals(id))).write(
        ServersCompanion(
          hostKeyFingerprint: Value(hostKey.fingerprint),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> delete(Server server) =>
      (_database.update(
        _database.servers,
      )..where((t) => t.id.equals(server.id))).write(
        ServersCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
