// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServersTable extends Servers with TableInfo<$ServersTable, Server> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(22),
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnectedAt =
      GeneratedColumn<DateTime>(
        'last_connected_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialIdMeta = const VerificationMeta(
    'credentialId',
  );
  @override
  late final GeneratedColumn<int> credentialId = GeneratedColumn<int>(
    'credential_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostKeyFingerprintMeta =
      const VerificationMeta('hostKeyFingerprint');
  @override
  late final GeneratedColumn<String> hostKeyFingerprint =
      GeneratedColumn<String>(
        'host_key_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _collectStatsMeta = const VerificationMeta(
    'collectStats',
  );
  @override
  late final GeneratedColumn<bool> collectStats = GeneratedColumn<bool>(
    'collect_stats',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collect_stats" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _collectSystemInfoMeta = const VerificationMeta(
    'collectSystemInfo',
  );
  @override
  late final GeneratedColumn<bool> collectSystemInfo = GeneratedColumn<bool>(
    'collect_system_info',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collect_system_info" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _proxyTypeMeta = const VerificationMeta(
    'proxyType',
  );
  @override
  late final GeneratedColumn<String> proxyType = GeneratedColumn<String>(
    'proxy_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proxyHostMeta = const VerificationMeta(
    'proxyHost',
  );
  @override
  late final GeneratedColumn<String> proxyHost = GeneratedColumn<String>(
    'proxy_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proxyPortMeta = const VerificationMeta(
    'proxyPort',
  );
  @override
  late final GeneratedColumn<int> proxyPort = GeneratedColumn<int>(
    'proxy_port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proxyUsernameMeta = const VerificationMeta(
    'proxyUsername',
  );
  @override
  late final GeneratedColumn<String> proxyUsername = GeneratedColumn<String>(
    'proxy_username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedProxyPasswordMeta =
      const VerificationMeta('encryptedProxyPassword');
  @override
  late final GeneratedColumn<String> encryptedProxyPassword =
      GeneratedColumn<String>(
        'encrypted_proxy_password',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _proxyPasswordNonceMeta =
      const VerificationMeta('proxyPasswordNonce');
  @override
  late final GeneratedColumn<String> proxyPasswordNonce =
      GeneratedColumn<String>(
        'proxy_password_nonce',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _jumpHostServerIdMeta = const VerificationMeta(
    'jumpHostServerId',
  );
  @override
  late final GeneratedColumn<int> jumpHostServerId = GeneratedColumn<int>(
    'jump_host_server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _environmentMeta = const VerificationMeta(
    'environment',
  );
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
    'environment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _connectionTypeMeta = const VerificationMeta(
    'connectionType',
  );
  @override
  late final GeneratedColumn<String> connectionType = GeneratedColumn<String>(
    'connection_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ssh'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    host,
    port,
    username,
    lastConnectedAt,
    syncId,
    createdAt,
    updatedAt,
    deletedAt,
    credentialId,
    hostKeyFingerprint,
    collectStats,
    collectSystemInfo,
    proxyType,
    proxyHost,
    proxyPort,
    proxyUsername,
    encryptedProxyPassword,
    proxyPasswordNonce,
    jumpHostServerId,
    environment,
    tags,
    connectionType,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Server> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('credential_id')) {
      context.handle(
        _credentialIdMeta,
        credentialId.isAcceptableOrUnknown(
          data['credential_id']!,
          _credentialIdMeta,
        ),
      );
    }
    if (data.containsKey('host_key_fingerprint')) {
      context.handle(
        _hostKeyFingerprintMeta,
        hostKeyFingerprint.isAcceptableOrUnknown(
          data['host_key_fingerprint']!,
          _hostKeyFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('collect_stats')) {
      context.handle(
        _collectStatsMeta,
        collectStats.isAcceptableOrUnknown(
          data['collect_stats']!,
          _collectStatsMeta,
        ),
      );
    }
    if (data.containsKey('collect_system_info')) {
      context.handle(
        _collectSystemInfoMeta,
        collectSystemInfo.isAcceptableOrUnknown(
          data['collect_system_info']!,
          _collectSystemInfoMeta,
        ),
      );
    }
    if (data.containsKey('proxy_type')) {
      context.handle(
        _proxyTypeMeta,
        proxyType.isAcceptableOrUnknown(data['proxy_type']!, _proxyTypeMeta),
      );
    }
    if (data.containsKey('proxy_host')) {
      context.handle(
        _proxyHostMeta,
        proxyHost.isAcceptableOrUnknown(data['proxy_host']!, _proxyHostMeta),
      );
    }
    if (data.containsKey('proxy_port')) {
      context.handle(
        _proxyPortMeta,
        proxyPort.isAcceptableOrUnknown(data['proxy_port']!, _proxyPortMeta),
      );
    }
    if (data.containsKey('proxy_username')) {
      context.handle(
        _proxyUsernameMeta,
        proxyUsername.isAcceptableOrUnknown(
          data['proxy_username']!,
          _proxyUsernameMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_proxy_password')) {
      context.handle(
        _encryptedProxyPasswordMeta,
        encryptedProxyPassword.isAcceptableOrUnknown(
          data['encrypted_proxy_password']!,
          _encryptedProxyPasswordMeta,
        ),
      );
    }
    if (data.containsKey('proxy_password_nonce')) {
      context.handle(
        _proxyPasswordNonceMeta,
        proxyPasswordNonce.isAcceptableOrUnknown(
          data['proxy_password_nonce']!,
          _proxyPasswordNonceMeta,
        ),
      );
    }
    if (data.containsKey('jump_host_server_id')) {
      context.handle(
        _jumpHostServerIdMeta,
        jumpHostServerId.isAcceptableOrUnknown(
          data['jump_host_server_id']!,
          _jumpHostServerIdMeta,
        ),
      );
    }
    if (data.containsKey('environment')) {
      context.handle(
        _environmentMeta,
        environment.isAcceptableOrUnknown(
          data['environment']!,
          _environmentMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('connection_type')) {
      context.handle(
        _connectionTypeMeta,
        connectionType.isAcceptableOrUnknown(
          data['connection_type']!,
          _connectionTypeMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Server map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Server(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected_at'],
      ),
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      credentialId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credential_id'],
      ),
      hostKeyFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_key_fingerprint'],
      ),
      collectStats: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collect_stats'],
      )!,
      collectSystemInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collect_system_info'],
      )!,
      proxyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_type'],
      ),
      proxyHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_host'],
      ),
      proxyPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proxy_port'],
      ),
      proxyUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_username'],
      ),
      encryptedProxyPassword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_proxy_password'],
      ),
      proxyPasswordNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_password_nonce'],
      ),
      jumpHostServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jump_host_server_id'],
      ),
      environment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}environment'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      connectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_type'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
    );
  }

  @override
  $ServersTable createAlias(String alias) {
    return $ServersTable(attachedDatabase, alias);
  }
}

class Server extends DataClass implements Insertable<Server> {
  final int id;
  final String name;
  final String host;
  final int port;
  final String username;
  final DateTime? lastConnectedAt;
  final String? syncId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int? credentialId;
  final String? hostKeyFingerprint;
  final bool collectStats;
  final bool collectSystemInfo;
  final String? proxyType;
  final String? proxyHost;
  final int? proxyPort;
  final String? proxyUsername;
  final String? encryptedProxyPassword;
  final String? proxyPasswordNonce;
  final int? jumpHostServerId;
  final String? environment;
  final String? tags;
  final String connectionType;
  final int? sortOrder;
  const Server({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.lastConnectedAt,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.credentialId,
    this.hostKeyFingerprint,
    required this.collectStats,
    required this.collectSystemInfo,
    this.proxyType,
    this.proxyHost,
    this.proxyPort,
    this.proxyUsername,
    this.encryptedProxyPassword,
    this.proxyPasswordNonce,
    this.jumpHostServerId,
    this.environment,
    this.tags,
    required this.connectionType,
    this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['host'] = Variable<String>(host);
    map['port'] = Variable<int>(port);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || lastConnectedAt != null) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || credentialId != null) {
      map['credential_id'] = Variable<int>(credentialId);
    }
    if (!nullToAbsent || hostKeyFingerprint != null) {
      map['host_key_fingerprint'] = Variable<String>(hostKeyFingerprint);
    }
    map['collect_stats'] = Variable<bool>(collectStats);
    map['collect_system_info'] = Variable<bool>(collectSystemInfo);
    if (!nullToAbsent || proxyType != null) {
      map['proxy_type'] = Variable<String>(proxyType);
    }
    if (!nullToAbsent || proxyHost != null) {
      map['proxy_host'] = Variable<String>(proxyHost);
    }
    if (!nullToAbsent || proxyPort != null) {
      map['proxy_port'] = Variable<int>(proxyPort);
    }
    if (!nullToAbsent || proxyUsername != null) {
      map['proxy_username'] = Variable<String>(proxyUsername);
    }
    if (!nullToAbsent || encryptedProxyPassword != null) {
      map['encrypted_proxy_password'] = Variable<String>(
        encryptedProxyPassword,
      );
    }
    if (!nullToAbsent || proxyPasswordNonce != null) {
      map['proxy_password_nonce'] = Variable<String>(proxyPasswordNonce);
    }
    if (!nullToAbsent || jumpHostServerId != null) {
      map['jump_host_server_id'] = Variable<int>(jumpHostServerId);
    }
    if (!nullToAbsent || environment != null) {
      map['environment'] = Variable<String>(environment);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['connection_type'] = Variable<String>(connectionType);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    return map;
  }

  ServersCompanion toCompanion(bool nullToAbsent) {
    return ServersCompanion(
      id: Value(id),
      name: Value(name),
      host: Value(host),
      port: Value(port),
      username: Value(username),
      lastConnectedAt: lastConnectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnectedAt),
      syncId: syncId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      credentialId: credentialId == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialId),
      hostKeyFingerprint: hostKeyFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(hostKeyFingerprint),
      collectStats: Value(collectStats),
      collectSystemInfo: Value(collectSystemInfo),
      proxyType: proxyType == null && nullToAbsent
          ? const Value.absent()
          : Value(proxyType),
      proxyHost: proxyHost == null && nullToAbsent
          ? const Value.absent()
          : Value(proxyHost),
      proxyPort: proxyPort == null && nullToAbsent
          ? const Value.absent()
          : Value(proxyPort),
      proxyUsername: proxyUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(proxyUsername),
      encryptedProxyPassword: encryptedProxyPassword == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedProxyPassword),
      proxyPasswordNonce: proxyPasswordNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(proxyPasswordNonce),
      jumpHostServerId: jumpHostServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(jumpHostServerId),
      environment: environment == null && nullToAbsent
          ? const Value.absent()
          : Value(environment),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      connectionType: Value(connectionType),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
    );
  }

  factory Server.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Server(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      host: serializer.fromJson<String>(json['host']),
      port: serializer.fromJson<int>(json['port']),
      username: serializer.fromJson<String>(json['username']),
      lastConnectedAt: serializer.fromJson<DateTime?>(json['lastConnectedAt']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      credentialId: serializer.fromJson<int?>(json['credentialId']),
      hostKeyFingerprint: serializer.fromJson<String?>(
        json['hostKeyFingerprint'],
      ),
      collectStats: serializer.fromJson<bool>(json['collectStats']),
      collectSystemInfo: serializer.fromJson<bool>(json['collectSystemInfo']),
      proxyType: serializer.fromJson<String?>(json['proxyType']),
      proxyHost: serializer.fromJson<String?>(json['proxyHost']),
      proxyPort: serializer.fromJson<int?>(json['proxyPort']),
      proxyUsername: serializer.fromJson<String?>(json['proxyUsername']),
      encryptedProxyPassword: serializer.fromJson<String?>(
        json['encryptedProxyPassword'],
      ),
      proxyPasswordNonce: serializer.fromJson<String?>(
        json['proxyPasswordNonce'],
      ),
      jumpHostServerId: serializer.fromJson<int?>(json['jumpHostServerId']),
      environment: serializer.fromJson<String?>(json['environment']),
      tags: serializer.fromJson<String?>(json['tags']),
      connectionType: serializer.fromJson<String>(json['connectionType']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'host': serializer.toJson<String>(host),
      'port': serializer.toJson<int>(port),
      'username': serializer.toJson<String>(username),
      'lastConnectedAt': serializer.toJson<DateTime?>(lastConnectedAt),
      'syncId': serializer.toJson<String?>(syncId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'credentialId': serializer.toJson<int?>(credentialId),
      'hostKeyFingerprint': serializer.toJson<String?>(hostKeyFingerprint),
      'collectStats': serializer.toJson<bool>(collectStats),
      'collectSystemInfo': serializer.toJson<bool>(collectSystemInfo),
      'proxyType': serializer.toJson<String?>(proxyType),
      'proxyHost': serializer.toJson<String?>(proxyHost),
      'proxyPort': serializer.toJson<int?>(proxyPort),
      'proxyUsername': serializer.toJson<String?>(proxyUsername),
      'encryptedProxyPassword': serializer.toJson<String?>(
        encryptedProxyPassword,
      ),
      'proxyPasswordNonce': serializer.toJson<String?>(proxyPasswordNonce),
      'jumpHostServerId': serializer.toJson<int?>(jumpHostServerId),
      'environment': serializer.toJson<String?>(environment),
      'tags': serializer.toJson<String?>(tags),
      'connectionType': serializer.toJson<String>(connectionType),
      'sortOrder': serializer.toJson<int?>(sortOrder),
    };
  }

  Server copyWith({
    int? id,
    String? name,
    String? host,
    int? port,
    String? username,
    Value<DateTime?> lastConnectedAt = const Value.absent(),
    Value<String?> syncId = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> credentialId = const Value.absent(),
    Value<String?> hostKeyFingerprint = const Value.absent(),
    bool? collectStats,
    bool? collectSystemInfo,
    Value<String?> proxyType = const Value.absent(),
    Value<String?> proxyHost = const Value.absent(),
    Value<int?> proxyPort = const Value.absent(),
    Value<String?> proxyUsername = const Value.absent(),
    Value<String?> encryptedProxyPassword = const Value.absent(),
    Value<String?> proxyPasswordNonce = const Value.absent(),
    Value<int?> jumpHostServerId = const Value.absent(),
    Value<String?> environment = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    String? connectionType,
    Value<int?> sortOrder = const Value.absent(),
  }) => Server(
    id: id ?? this.id,
    name: name ?? this.name,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    lastConnectedAt: lastConnectedAt.present
        ? lastConnectedAt.value
        : this.lastConnectedAt,
    syncId: syncId.present ? syncId.value : this.syncId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    credentialId: credentialId.present ? credentialId.value : this.credentialId,
    hostKeyFingerprint: hostKeyFingerprint.present
        ? hostKeyFingerprint.value
        : this.hostKeyFingerprint,
    collectStats: collectStats ?? this.collectStats,
    collectSystemInfo: collectSystemInfo ?? this.collectSystemInfo,
    proxyType: proxyType.present ? proxyType.value : this.proxyType,
    proxyHost: proxyHost.present ? proxyHost.value : this.proxyHost,
    proxyPort: proxyPort.present ? proxyPort.value : this.proxyPort,
    proxyUsername: proxyUsername.present
        ? proxyUsername.value
        : this.proxyUsername,
    encryptedProxyPassword: encryptedProxyPassword.present
        ? encryptedProxyPassword.value
        : this.encryptedProxyPassword,
    proxyPasswordNonce: proxyPasswordNonce.present
        ? proxyPasswordNonce.value
        : this.proxyPasswordNonce,
    jumpHostServerId: jumpHostServerId.present
        ? jumpHostServerId.value
        : this.jumpHostServerId,
    environment: environment.present ? environment.value : this.environment,
    tags: tags.present ? tags.value : this.tags,
    connectionType: connectionType ?? this.connectionType,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
  );
  Server copyWithCompanion(ServersCompanion data) {
    return Server(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      username: data.username.present ? data.username.value : this.username,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      credentialId: data.credentialId.present
          ? data.credentialId.value
          : this.credentialId,
      hostKeyFingerprint: data.hostKeyFingerprint.present
          ? data.hostKeyFingerprint.value
          : this.hostKeyFingerprint,
      collectStats: data.collectStats.present
          ? data.collectStats.value
          : this.collectStats,
      collectSystemInfo: data.collectSystemInfo.present
          ? data.collectSystemInfo.value
          : this.collectSystemInfo,
      proxyType: data.proxyType.present ? data.proxyType.value : this.proxyType,
      proxyHost: data.proxyHost.present ? data.proxyHost.value : this.proxyHost,
      proxyPort: data.proxyPort.present ? data.proxyPort.value : this.proxyPort,
      proxyUsername: data.proxyUsername.present
          ? data.proxyUsername.value
          : this.proxyUsername,
      encryptedProxyPassword: data.encryptedProxyPassword.present
          ? data.encryptedProxyPassword.value
          : this.encryptedProxyPassword,
      proxyPasswordNonce: data.proxyPasswordNonce.present
          ? data.proxyPasswordNonce.value
          : this.proxyPasswordNonce,
      jumpHostServerId: data.jumpHostServerId.present
          ? data.jumpHostServerId.value
          : this.jumpHostServerId,
      environment: data.environment.present
          ? data.environment.value
          : this.environment,
      tags: data.tags.present ? data.tags.value : this.tags,
      connectionType: data.connectionType.present
          ? data.connectionType.value
          : this.connectionType,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Server(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('syncId: $syncId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('credentialId: $credentialId, ')
          ..write('hostKeyFingerprint: $hostKeyFingerprint, ')
          ..write('collectStats: $collectStats, ')
          ..write('collectSystemInfo: $collectSystemInfo, ')
          ..write('proxyType: $proxyType, ')
          ..write('proxyHost: $proxyHost, ')
          ..write('proxyPort: $proxyPort, ')
          ..write('proxyUsername: $proxyUsername, ')
          ..write('encryptedProxyPassword: $encryptedProxyPassword, ')
          ..write('proxyPasswordNonce: $proxyPasswordNonce, ')
          ..write('jumpHostServerId: $jumpHostServerId, ')
          ..write('environment: $environment, ')
          ..write('tags: $tags, ')
          ..write('connectionType: $connectionType, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    host,
    port,
    username,
    lastConnectedAt,
    syncId,
    createdAt,
    updatedAt,
    deletedAt,
    credentialId,
    hostKeyFingerprint,
    collectStats,
    collectSystemInfo,
    proxyType,
    proxyHost,
    proxyPort,
    proxyUsername,
    encryptedProxyPassword,
    proxyPasswordNonce,
    jumpHostServerId,
    environment,
    tags,
    connectionType,
    sortOrder,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Server &&
          other.id == this.id &&
          other.name == this.name &&
          other.host == this.host &&
          other.port == this.port &&
          other.username == this.username &&
          other.lastConnectedAt == this.lastConnectedAt &&
          other.syncId == this.syncId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.credentialId == this.credentialId &&
          other.hostKeyFingerprint == this.hostKeyFingerprint &&
          other.collectStats == this.collectStats &&
          other.collectSystemInfo == this.collectSystemInfo &&
          other.proxyType == this.proxyType &&
          other.proxyHost == this.proxyHost &&
          other.proxyPort == this.proxyPort &&
          other.proxyUsername == this.proxyUsername &&
          other.encryptedProxyPassword == this.encryptedProxyPassword &&
          other.proxyPasswordNonce == this.proxyPasswordNonce &&
          other.jumpHostServerId == this.jumpHostServerId &&
          other.environment == this.environment &&
          other.tags == this.tags &&
          other.connectionType == this.connectionType &&
          other.sortOrder == this.sortOrder);
}

class ServersCompanion extends UpdateCompanion<Server> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> host;
  final Value<int> port;
  final Value<String> username;
  final Value<DateTime?> lastConnectedAt;
  final Value<String?> syncId;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> credentialId;
  final Value<String?> hostKeyFingerprint;
  final Value<bool> collectStats;
  final Value<bool> collectSystemInfo;
  final Value<String?> proxyType;
  final Value<String?> proxyHost;
  final Value<int?> proxyPort;
  final Value<String?> proxyUsername;
  final Value<String?> encryptedProxyPassword;
  final Value<String?> proxyPasswordNonce;
  final Value<int?> jumpHostServerId;
  final Value<String?> environment;
  final Value<String?> tags;
  final Value<String> connectionType;
  final Value<int?> sortOrder;
  const ServersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.username = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.credentialId = const Value.absent(),
    this.hostKeyFingerprint = const Value.absent(),
    this.collectStats = const Value.absent(),
    this.collectSystemInfo = const Value.absent(),
    this.proxyType = const Value.absent(),
    this.proxyHost = const Value.absent(),
    this.proxyPort = const Value.absent(),
    this.proxyUsername = const Value.absent(),
    this.encryptedProxyPassword = const Value.absent(),
    this.proxyPasswordNonce = const Value.absent(),
    this.jumpHostServerId = const Value.absent(),
    this.environment = const Value.absent(),
    this.tags = const Value.absent(),
    this.connectionType = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ServersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String host,
    this.port = const Value.absent(),
    required String username,
    this.lastConnectedAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.credentialId = const Value.absent(),
    this.hostKeyFingerprint = const Value.absent(),
    this.collectStats = const Value.absent(),
    this.collectSystemInfo = const Value.absent(),
    this.proxyType = const Value.absent(),
    this.proxyHost = const Value.absent(),
    this.proxyPort = const Value.absent(),
    this.proxyUsername = const Value.absent(),
    this.encryptedProxyPassword = const Value.absent(),
    this.proxyPasswordNonce = const Value.absent(),
    this.jumpHostServerId = const Value.absent(),
    this.environment = const Value.absent(),
    this.tags = const Value.absent(),
    this.connectionType = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name),
       host = Value(host),
       username = Value(username);
  static Insertable<Server> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? host,
    Expression<int>? port,
    Expression<String>? username,
    Expression<DateTime>? lastConnectedAt,
    Expression<String>? syncId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? credentialId,
    Expression<String>? hostKeyFingerprint,
    Expression<bool>? collectStats,
    Expression<bool>? collectSystemInfo,
    Expression<String>? proxyType,
    Expression<String>? proxyHost,
    Expression<int>? proxyPort,
    Expression<String>? proxyUsername,
    Expression<String>? encryptedProxyPassword,
    Expression<String>? proxyPasswordNonce,
    Expression<int>? jumpHostServerId,
    Expression<String>? environment,
    Expression<String>? tags,
    Expression<String>? connectionType,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (username != null) 'username': username,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (syncId != null) 'sync_id': syncId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (credentialId != null) 'credential_id': credentialId,
      if (hostKeyFingerprint != null)
        'host_key_fingerprint': hostKeyFingerprint,
      if (collectStats != null) 'collect_stats': collectStats,
      if (collectSystemInfo != null) 'collect_system_info': collectSystemInfo,
      if (proxyType != null) 'proxy_type': proxyType,
      if (proxyHost != null) 'proxy_host': proxyHost,
      if (proxyPort != null) 'proxy_port': proxyPort,
      if (proxyUsername != null) 'proxy_username': proxyUsername,
      if (encryptedProxyPassword != null)
        'encrypted_proxy_password': encryptedProxyPassword,
      if (proxyPasswordNonce != null)
        'proxy_password_nonce': proxyPasswordNonce,
      if (jumpHostServerId != null) 'jump_host_server_id': jumpHostServerId,
      if (environment != null) 'environment': environment,
      if (tags != null) 'tags': tags,
      if (connectionType != null) 'connection_type': connectionType,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ServersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? host,
    Value<int>? port,
    Value<String>? username,
    Value<DateTime?>? lastConnectedAt,
    Value<String?>? syncId,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? credentialId,
    Value<String?>? hostKeyFingerprint,
    Value<bool>? collectStats,
    Value<bool>? collectSystemInfo,
    Value<String?>? proxyType,
    Value<String?>? proxyHost,
    Value<int?>? proxyPort,
    Value<String?>? proxyUsername,
    Value<String?>? encryptedProxyPassword,
    Value<String?>? proxyPasswordNonce,
    Value<int?>? jumpHostServerId,
    Value<String?>? environment,
    Value<String?>? tags,
    Value<String>? connectionType,
    Value<int?>? sortOrder,
  }) {
    return ServersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      syncId: syncId ?? this.syncId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      credentialId: credentialId ?? this.credentialId,
      hostKeyFingerprint: hostKeyFingerprint ?? this.hostKeyFingerprint,
      collectStats: collectStats ?? this.collectStats,
      collectSystemInfo: collectSystemInfo ?? this.collectSystemInfo,
      proxyType: proxyType ?? this.proxyType,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      proxyUsername: proxyUsername ?? this.proxyUsername,
      encryptedProxyPassword:
          encryptedProxyPassword ?? this.encryptedProxyPassword,
      proxyPasswordNonce: proxyPasswordNonce ?? this.proxyPasswordNonce,
      jumpHostServerId: jumpHostServerId ?? this.jumpHostServerId,
      environment: environment ?? this.environment,
      tags: tags ?? this.tags,
      connectionType: connectionType ?? this.connectionType,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (credentialId.present) {
      map['credential_id'] = Variable<int>(credentialId.value);
    }
    if (hostKeyFingerprint.present) {
      map['host_key_fingerprint'] = Variable<String>(hostKeyFingerprint.value);
    }
    if (collectStats.present) {
      map['collect_stats'] = Variable<bool>(collectStats.value);
    }
    if (collectSystemInfo.present) {
      map['collect_system_info'] = Variable<bool>(collectSystemInfo.value);
    }
    if (proxyType.present) {
      map['proxy_type'] = Variable<String>(proxyType.value);
    }
    if (proxyHost.present) {
      map['proxy_host'] = Variable<String>(proxyHost.value);
    }
    if (proxyPort.present) {
      map['proxy_port'] = Variable<int>(proxyPort.value);
    }
    if (proxyUsername.present) {
      map['proxy_username'] = Variable<String>(proxyUsername.value);
    }
    if (encryptedProxyPassword.present) {
      map['encrypted_proxy_password'] = Variable<String>(
        encryptedProxyPassword.value,
      );
    }
    if (proxyPasswordNonce.present) {
      map['proxy_password_nonce'] = Variable<String>(proxyPasswordNonce.value);
    }
    if (jumpHostServerId.present) {
      map['jump_host_server_id'] = Variable<int>(jumpHostServerId.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (connectionType.present) {
      map['connection_type'] = Variable<String>(connectionType.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('syncId: $syncId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('credentialId: $credentialId, ')
          ..write('hostKeyFingerprint: $hostKeyFingerprint, ')
          ..write('collectStats: $collectStats, ')
          ..write('collectSystemInfo: $collectSystemInfo, ')
          ..write('proxyType: $proxyType, ')
          ..write('proxyHost: $proxyHost, ')
          ..write('proxyPort: $proxyPort, ')
          ..write('proxyUsername: $proxyUsername, ')
          ..write('encryptedProxyPassword: $encryptedProxyPassword, ')
          ..write('proxyPasswordNonce: $proxyPasswordNonce, ')
          ..write('jumpHostServerId: $jumpHostServerId, ')
          ..write('environment: $environment, ')
          ..write('tags: $tags, ')
          ..write('connectionType: $connectionType, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $SavedCredentialsTable extends SavedCredentials
    with TableInfo<$SavedCredentialsTable, SavedCredential> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedCredentialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _credentialTypeMeta = const VerificationMeta(
    'credentialType',
  );
  @override
  late final GeneratedColumn<String> credentialType = GeneratedColumn<String>(
    'credential_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedCredentialMeta =
      const VerificationMeta('encryptedCredential');
  @override
  late final GeneratedColumn<String> encryptedCredential =
      GeneratedColumn<String>(
        'encrypted_credential',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _credentialNonceMeta = const VerificationMeta(
    'credentialNonce',
  );
  @override
  late final GeneratedColumn<String> credentialNonce = GeneratedColumn<String>(
    'credential_nonce',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    credentialType,
    encryptedCredential,
    credentialNonce,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_credentials';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedCredential> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('credential_type')) {
      context.handle(
        _credentialTypeMeta,
        credentialType.isAcceptableOrUnknown(
          data['credential_type']!,
          _credentialTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_credentialTypeMeta);
    }
    if (data.containsKey('encrypted_credential')) {
      context.handle(
        _encryptedCredentialMeta,
        encryptedCredential.isAcceptableOrUnknown(
          data['encrypted_credential']!,
          _encryptedCredentialMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedCredentialMeta);
    }
    if (data.containsKey('credential_nonce')) {
      context.handle(
        _credentialNonceMeta,
        credentialNonce.isAcceptableOrUnknown(
          data['credential_nonce']!,
          _credentialNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_credentialNonceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedCredential map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedCredential(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      credentialType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_type'],
      )!,
      encryptedCredential: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_credential'],
      )!,
      credentialNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_nonce'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SavedCredentialsTable createAlias(String alias) {
    return $SavedCredentialsTable(attachedDatabase, alias);
  }
}

class SavedCredential extends DataClass implements Insertable<SavedCredential> {
  final int id;
  final String name;
  final String credentialType;
  final String encryptedCredential;
  final String credentialNonce;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SavedCredential({
    required this.id,
    required this.name,
    required this.credentialType,
    required this.encryptedCredential,
    required this.credentialNonce,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['credential_type'] = Variable<String>(credentialType);
    map['encrypted_credential'] = Variable<String>(encryptedCredential);
    map['credential_nonce'] = Variable<String>(credentialNonce);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SavedCredentialsCompanion toCompanion(bool nullToAbsent) {
    return SavedCredentialsCompanion(
      id: Value(id),
      name: Value(name),
      credentialType: Value(credentialType),
      encryptedCredential: Value(encryptedCredential),
      credentialNonce: Value(credentialNonce),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedCredential.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedCredential(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      credentialType: serializer.fromJson<String>(json['credentialType']),
      encryptedCredential: serializer.fromJson<String>(
        json['encryptedCredential'],
      ),
      credentialNonce: serializer.fromJson<String>(json['credentialNonce']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'credentialType': serializer.toJson<String>(credentialType),
      'encryptedCredential': serializer.toJson<String>(encryptedCredential),
      'credentialNonce': serializer.toJson<String>(credentialNonce),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SavedCredential copyWith({
    int? id,
    String? name,
    String? credentialType,
    String? encryptedCredential,
    String? credentialNonce,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SavedCredential(
    id: id ?? this.id,
    name: name ?? this.name,
    credentialType: credentialType ?? this.credentialType,
    encryptedCredential: encryptedCredential ?? this.encryptedCredential,
    credentialNonce: credentialNonce ?? this.credentialNonce,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SavedCredential copyWithCompanion(SavedCredentialsCompanion data) {
    return SavedCredential(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      credentialType: data.credentialType.present
          ? data.credentialType.value
          : this.credentialType,
      encryptedCredential: data.encryptedCredential.present
          ? data.encryptedCredential.value
          : this.encryptedCredential,
      credentialNonce: data.credentialNonce.present
          ? data.credentialNonce.value
          : this.credentialNonce,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedCredential(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('credentialType: $credentialType, ')
          ..write('encryptedCredential: $encryptedCredential, ')
          ..write('credentialNonce: $credentialNonce, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    credentialType,
    encryptedCredential,
    credentialNonce,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedCredential &&
          other.id == this.id &&
          other.name == this.name &&
          other.credentialType == this.credentialType &&
          other.encryptedCredential == this.encryptedCredential &&
          other.credentialNonce == this.credentialNonce &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SavedCredentialsCompanion extends UpdateCompanion<SavedCredential> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> credentialType;
  final Value<String> encryptedCredential;
  final Value<String> credentialNonce;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SavedCredentialsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.credentialType = const Value.absent(),
    this.encryptedCredential = const Value.absent(),
    this.credentialNonce = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SavedCredentialsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String credentialType,
    required String encryptedCredential,
    required String credentialNonce,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       credentialType = Value(credentialType),
       encryptedCredential = Value(encryptedCredential),
       credentialNonce = Value(credentialNonce),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedCredential> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? credentialType,
    Expression<String>? encryptedCredential,
    Expression<String>? credentialNonce,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (credentialType != null) 'credential_type': credentialType,
      if (encryptedCredential != null)
        'encrypted_credential': encryptedCredential,
      if (credentialNonce != null) 'credential_nonce': credentialNonce,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SavedCredentialsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? credentialType,
    Value<String>? encryptedCredential,
    Value<String>? credentialNonce,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SavedCredentialsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      credentialType: credentialType ?? this.credentialType,
      encryptedCredential: encryptedCredential ?? this.encryptedCredential,
      credentialNonce: credentialNonce ?? this.credentialNonce,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (credentialType.present) {
      map['credential_type'] = Variable<String>(credentialType.value);
    }
    if (encryptedCredential.present) {
      map['encrypted_credential'] = Variable<String>(encryptedCredential.value);
    }
    if (credentialNonce.present) {
      map['credential_nonce'] = Variable<String>(credentialNonce.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedCredentialsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('credentialType: $credentialType, ')
          ..write('encryptedCredential: $encryptedCredential, ')
          ..write('credentialNonce: $credentialNonce, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $VaultMetadataTable extends VaultMetadata
    with TableInfo<$VaultMetadataTable, VaultMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saltMeta = const VerificationMeta('salt');
  @override
  late final GeneratedColumn<String> salt = GeneratedColumn<String>(
    'salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrappedDataKeyMeta = const VerificationMeta(
    'wrappedDataKey',
  );
  @override
  late final GeneratedColumn<String> wrappedDataKey = GeneratedColumn<String>(
    'wrapped_data_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrappedDataKeyNonceMeta =
      const VerificationMeta('wrappedDataKeyNonce');
  @override
  late final GeneratedColumn<String> wrappedDataKeyNonce =
      GeneratedColumn<String>(
        'wrapped_data_key_nonce',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _verifierMeta = const VerificationMeta(
    'verifier',
  );
  @override
  late final GeneratedColumn<String> verifier = GeneratedColumn<String>(
    'verifier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifierNonceMeta = const VerificationMeta(
    'verifierNonce',
  );
  @override
  late final GeneratedColumn<String> verifierNonce = GeneratedColumn<String>(
    'verifier_nonce',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    formatVersion,
    salt,
    wrappedDataKey,
    wrappedDataKeyNonce,
    verifier,
    verifierNonce,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('salt')) {
      context.handle(
        _saltMeta,
        salt.isAcceptableOrUnknown(data['salt']!, _saltMeta),
      );
    } else if (isInserting) {
      context.missing(_saltMeta);
    }
    if (data.containsKey('wrapped_data_key')) {
      context.handle(
        _wrappedDataKeyMeta,
        wrappedDataKey.isAcceptableOrUnknown(
          data['wrapped_data_key']!,
          _wrappedDataKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wrappedDataKeyMeta);
    }
    if (data.containsKey('wrapped_data_key_nonce')) {
      context.handle(
        _wrappedDataKeyNonceMeta,
        wrappedDataKeyNonce.isAcceptableOrUnknown(
          data['wrapped_data_key_nonce']!,
          _wrappedDataKeyNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wrappedDataKeyNonceMeta);
    }
    if (data.containsKey('verifier')) {
      context.handle(
        _verifierMeta,
        verifier.isAcceptableOrUnknown(data['verifier']!, _verifierMeta),
      );
    } else if (isInserting) {
      context.missing(_verifierMeta);
    }
    if (data.containsKey('verifier_nonce')) {
      context.handle(
        _verifierNonceMeta,
        verifierNonce.isAcceptableOrUnknown(
          data['verifier_nonce']!,
          _verifierNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_verifierNonceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultMetadataData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      salt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salt'],
      )!,
      wrappedDataKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrapped_data_key'],
      )!,
      wrappedDataKeyNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrapped_data_key_nonce'],
      )!,
      verifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verifier'],
      )!,
      verifierNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verifier_nonce'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VaultMetadataTable createAlias(String alias) {
    return $VaultMetadataTable(attachedDatabase, alias);
  }
}

class VaultMetadataData extends DataClass
    implements Insertable<VaultMetadataData> {
  final int id;
  final int formatVersion;
  final String salt;
  final String wrappedDataKey;
  final String wrappedDataKeyNonce;
  final String verifier;
  final String verifierNonce;
  final DateTime createdAt;
  const VaultMetadataData({
    required this.id,
    required this.formatVersion,
    required this.salt,
    required this.wrappedDataKey,
    required this.wrappedDataKeyNonce,
    required this.verifier,
    required this.verifierNonce,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['format_version'] = Variable<int>(formatVersion);
    map['salt'] = Variable<String>(salt);
    map['wrapped_data_key'] = Variable<String>(wrappedDataKey);
    map['wrapped_data_key_nonce'] = Variable<String>(wrappedDataKeyNonce);
    map['verifier'] = Variable<String>(verifier);
    map['verifier_nonce'] = Variable<String>(verifierNonce);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VaultMetadataCompanion toCompanion(bool nullToAbsent) {
    return VaultMetadataCompanion(
      id: Value(id),
      formatVersion: Value(formatVersion),
      salt: Value(salt),
      wrappedDataKey: Value(wrappedDataKey),
      wrappedDataKeyNonce: Value(wrappedDataKeyNonce),
      verifier: Value(verifier),
      verifierNonce: Value(verifierNonce),
      createdAt: Value(createdAt),
    );
  }

  factory VaultMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultMetadataData(
      id: serializer.fromJson<int>(json['id']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      salt: serializer.fromJson<String>(json['salt']),
      wrappedDataKey: serializer.fromJson<String>(json['wrappedDataKey']),
      wrappedDataKeyNonce: serializer.fromJson<String>(
        json['wrappedDataKeyNonce'],
      ),
      verifier: serializer.fromJson<String>(json['verifier']),
      verifierNonce: serializer.fromJson<String>(json['verifierNonce']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'salt': serializer.toJson<String>(salt),
      'wrappedDataKey': serializer.toJson<String>(wrappedDataKey),
      'wrappedDataKeyNonce': serializer.toJson<String>(wrappedDataKeyNonce),
      'verifier': serializer.toJson<String>(verifier),
      'verifierNonce': serializer.toJson<String>(verifierNonce),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VaultMetadataData copyWith({
    int? id,
    int? formatVersion,
    String? salt,
    String? wrappedDataKey,
    String? wrappedDataKeyNonce,
    String? verifier,
    String? verifierNonce,
    DateTime? createdAt,
  }) => VaultMetadataData(
    id: id ?? this.id,
    formatVersion: formatVersion ?? this.formatVersion,
    salt: salt ?? this.salt,
    wrappedDataKey: wrappedDataKey ?? this.wrappedDataKey,
    wrappedDataKeyNonce: wrappedDataKeyNonce ?? this.wrappedDataKeyNonce,
    verifier: verifier ?? this.verifier,
    verifierNonce: verifierNonce ?? this.verifierNonce,
    createdAt: createdAt ?? this.createdAt,
  );
  VaultMetadataData copyWithCompanion(VaultMetadataCompanion data) {
    return VaultMetadataData(
      id: data.id.present ? data.id.value : this.id,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      salt: data.salt.present ? data.salt.value : this.salt,
      wrappedDataKey: data.wrappedDataKey.present
          ? data.wrappedDataKey.value
          : this.wrappedDataKey,
      wrappedDataKeyNonce: data.wrappedDataKeyNonce.present
          ? data.wrappedDataKeyNonce.value
          : this.wrappedDataKeyNonce,
      verifier: data.verifier.present ? data.verifier.value : this.verifier,
      verifierNonce: data.verifierNonce.present
          ? data.verifierNonce.value
          : this.verifierNonce,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetadataData(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('salt: $salt, ')
          ..write('wrappedDataKey: $wrappedDataKey, ')
          ..write('wrappedDataKeyNonce: $wrappedDataKeyNonce, ')
          ..write('verifier: $verifier, ')
          ..write('verifierNonce: $verifierNonce, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    formatVersion,
    salt,
    wrappedDataKey,
    wrappedDataKeyNonce,
    verifier,
    verifierNonce,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultMetadataData &&
          other.id == this.id &&
          other.formatVersion == this.formatVersion &&
          other.salt == this.salt &&
          other.wrappedDataKey == this.wrappedDataKey &&
          other.wrappedDataKeyNonce == this.wrappedDataKeyNonce &&
          other.verifier == this.verifier &&
          other.verifierNonce == this.verifierNonce &&
          other.createdAt == this.createdAt);
}

class VaultMetadataCompanion extends UpdateCompanion<VaultMetadataData> {
  final Value<int> id;
  final Value<int> formatVersion;
  final Value<String> salt;
  final Value<String> wrappedDataKey;
  final Value<String> wrappedDataKeyNonce;
  final Value<String> verifier;
  final Value<String> verifierNonce;
  final Value<DateTime> createdAt;
  const VaultMetadataCompanion({
    this.id = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.salt = const Value.absent(),
    this.wrappedDataKey = const Value.absent(),
    this.wrappedDataKeyNonce = const Value.absent(),
    this.verifier = const Value.absent(),
    this.verifierNonce = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  VaultMetadataCompanion.insert({
    this.id = const Value.absent(),
    required int formatVersion,
    required String salt,
    required String wrappedDataKey,
    required String wrappedDataKeyNonce,
    required String verifier,
    required String verifierNonce,
    required DateTime createdAt,
  }) : formatVersion = Value(formatVersion),
       salt = Value(salt),
       wrappedDataKey = Value(wrappedDataKey),
       wrappedDataKeyNonce = Value(wrappedDataKeyNonce),
       verifier = Value(verifier),
       verifierNonce = Value(verifierNonce),
       createdAt = Value(createdAt);
  static Insertable<VaultMetadataData> custom({
    Expression<int>? id,
    Expression<int>? formatVersion,
    Expression<String>? salt,
    Expression<String>? wrappedDataKey,
    Expression<String>? wrappedDataKeyNonce,
    Expression<String>? verifier,
    Expression<String>? verifierNonce,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (formatVersion != null) 'format_version': formatVersion,
      if (salt != null) 'salt': salt,
      if (wrappedDataKey != null) 'wrapped_data_key': wrappedDataKey,
      if (wrappedDataKeyNonce != null)
        'wrapped_data_key_nonce': wrappedDataKeyNonce,
      if (verifier != null) 'verifier': verifier,
      if (verifierNonce != null) 'verifier_nonce': verifierNonce,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  VaultMetadataCompanion copyWith({
    Value<int>? id,
    Value<int>? formatVersion,
    Value<String>? salt,
    Value<String>? wrappedDataKey,
    Value<String>? wrappedDataKeyNonce,
    Value<String>? verifier,
    Value<String>? verifierNonce,
    Value<DateTime>? createdAt,
  }) {
    return VaultMetadataCompanion(
      id: id ?? this.id,
      formatVersion: formatVersion ?? this.formatVersion,
      salt: salt ?? this.salt,
      wrappedDataKey: wrappedDataKey ?? this.wrappedDataKey,
      wrappedDataKeyNonce: wrappedDataKeyNonce ?? this.wrappedDataKeyNonce,
      verifier: verifier ?? this.verifier,
      verifierNonce: verifierNonce ?? this.verifierNonce,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (salt.present) {
      map['salt'] = Variable<String>(salt.value);
    }
    if (wrappedDataKey.present) {
      map['wrapped_data_key'] = Variable<String>(wrappedDataKey.value);
    }
    if (wrappedDataKeyNonce.present) {
      map['wrapped_data_key_nonce'] = Variable<String>(
        wrappedDataKeyNonce.value,
      );
    }
    if (verifier.present) {
      map['verifier'] = Variable<String>(verifier.value);
    }
    if (verifierNonce.present) {
      map['verifier_nonce'] = Variable<String>(verifierNonce.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetadataCompanion(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('salt: $salt, ')
          ..write('wrappedDataKey: $wrappedDataKey, ')
          ..write('wrappedDataKeyNonce: $wrappedDataKeyNonce, ')
          ..write('verifier: $verifier, ')
          ..write('verifierNonce: $verifierNonce, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GitHubConnectionsTable extends GitHubConnections
    with TableInfo<$GitHubConnectionsTable, GitHubConnection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GitHubConnectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountLoginMeta = const VerificationMeta(
    'accountLogin',
  );
  @override
  late final GeneratedColumn<String> accountLogin = GeneratedColumn<String>(
    'account_login',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _accountNameMeta = const VerificationMeta(
    'accountName',
  );
  @override
  late final GeneratedColumn<String> accountName = GeneratedColumn<String>(
    'account_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountLogin,
    accountName,
    avatarUrl,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'github_connections';
  @override
  VerificationContext validateIntegrity(
    Insertable<GitHubConnection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_login')) {
      context.handle(
        _accountLoginMeta,
        accountLogin.isAcceptableOrUnknown(
          data['account_login']!,
          _accountLoginMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountLoginMeta);
    }
    if (data.containsKey('account_name')) {
      context.handle(
        _accountNameMeta,
        accountName.isAcceptableOrUnknown(
          data['account_name']!,
          _accountNameMeta,
        ),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GitHubConnection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GitHubConnection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountLogin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_login'],
      )!,
      accountName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_name'],
      )!,
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GitHubConnectionsTable createAlias(String alias) {
    return $GitHubConnectionsTable(attachedDatabase, alias);
  }
}

class GitHubConnection extends DataClass
    implements Insertable<GitHubConnection> {
  final int id;
  final String accountLogin;
  final String accountName;
  final String avatarUrl;
  final DateTime createdAt;
  const GitHubConnection({
    required this.id,
    required this.accountLogin,
    required this.accountName,
    required this.avatarUrl,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_login'] = Variable<String>(accountLogin);
    map['account_name'] = Variable<String>(accountName);
    map['avatar_url'] = Variable<String>(avatarUrl);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GitHubConnectionsCompanion toCompanion(bool nullToAbsent) {
    return GitHubConnectionsCompanion(
      id: Value(id),
      accountLogin: Value(accountLogin),
      accountName: Value(accountName),
      avatarUrl: Value(avatarUrl),
      createdAt: Value(createdAt),
    );
  }

  factory GitHubConnection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GitHubConnection(
      id: serializer.fromJson<int>(json['id']),
      accountLogin: serializer.fromJson<String>(json['accountLogin']),
      accountName: serializer.fromJson<String>(json['accountName']),
      avatarUrl: serializer.fromJson<String>(json['avatarUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountLogin': serializer.toJson<String>(accountLogin),
      'accountName': serializer.toJson<String>(accountName),
      'avatarUrl': serializer.toJson<String>(avatarUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GitHubConnection copyWith({
    int? id,
    String? accountLogin,
    String? accountName,
    String? avatarUrl,
    DateTime? createdAt,
  }) => GitHubConnection(
    id: id ?? this.id,
    accountLogin: accountLogin ?? this.accountLogin,
    accountName: accountName ?? this.accountName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    createdAt: createdAt ?? this.createdAt,
  );
  GitHubConnection copyWithCompanion(GitHubConnectionsCompanion data) {
    return GitHubConnection(
      id: data.id.present ? data.id.value : this.id,
      accountLogin: data.accountLogin.present
          ? data.accountLogin.value
          : this.accountLogin,
      accountName: data.accountName.present
          ? data.accountName.value
          : this.accountName,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GitHubConnection(')
          ..write('id: $id, ')
          ..write('accountLogin: $accountLogin, ')
          ..write('accountName: $accountName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, accountLogin, accountName, avatarUrl, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GitHubConnection &&
          other.id == this.id &&
          other.accountLogin == this.accountLogin &&
          other.accountName == this.accountName &&
          other.avatarUrl == this.avatarUrl &&
          other.createdAt == this.createdAt);
}

class GitHubConnectionsCompanion extends UpdateCompanion<GitHubConnection> {
  final Value<int> id;
  final Value<String> accountLogin;
  final Value<String> accountName;
  final Value<String> avatarUrl;
  final Value<DateTime> createdAt;
  const GitHubConnectionsCompanion({
    this.id = const Value.absent(),
    this.accountLogin = const Value.absent(),
    this.accountName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GitHubConnectionsCompanion.insert({
    this.id = const Value.absent(),
    required String accountLogin,
    this.accountName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    required DateTime createdAt,
  }) : accountLogin = Value(accountLogin),
       createdAt = Value(createdAt);
  static Insertable<GitHubConnection> custom({
    Expression<int>? id,
    Expression<String>? accountLogin,
    Expression<String>? accountName,
    Expression<String>? avatarUrl,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountLogin != null) 'account_login': accountLogin,
      if (accountName != null) 'account_name': accountName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GitHubConnectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? accountLogin,
    Value<String>? accountName,
    Value<String>? avatarUrl,
    Value<DateTime>? createdAt,
  }) {
    return GitHubConnectionsCompanion(
      id: id ?? this.id,
      accountLogin: accountLogin ?? this.accountLogin,
      accountName: accountName ?? this.accountName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountLogin.present) {
      map['account_login'] = Variable<String>(accountLogin.value);
    }
    if (accountName.present) {
      map['account_name'] = Variable<String>(accountName.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GitHubConnectionsCompanion(')
          ..write('id: $id, ')
          ..write('accountLogin: $accountLogin, ')
          ..write('accountName: $accountName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GitHubRepoPinsTable extends GitHubRepoPins
    with TableInfo<$GitHubRepoPinsTable, GitHubRepoPin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GitHubRepoPinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<int> connectionId = GeneratedColumn<int>(
    'connection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES github_connections (id)',
    ),
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pinnedAt = GeneratedColumn<DateTime>(
    'pinned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    connectionId,
    owner,
    name,
    pinnedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'github_repo_pins';
  @override
  VerificationContext validateIntegrity(
    Insertable<GitHubRepoPin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionIdMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pinnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GitHubRepoPin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GitHubRepoPin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}connection_id'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pinned_at'],
      )!,
    );
  }

  @override
  $GitHubRepoPinsTable createAlias(String alias) {
    return $GitHubRepoPinsTable(attachedDatabase, alias);
  }
}

class GitHubRepoPin extends DataClass implements Insertable<GitHubRepoPin> {
  final int id;
  final int connectionId;
  final String owner;
  final String name;
  final DateTime pinnedAt;
  const GitHubRepoPin({
    required this.id,
    required this.connectionId,
    required this.owner,
    required this.name,
    required this.pinnedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['connection_id'] = Variable<int>(connectionId);
    map['owner'] = Variable<String>(owner);
    map['name'] = Variable<String>(name);
    map['pinned_at'] = Variable<DateTime>(pinnedAt);
    return map;
  }

  GitHubRepoPinsCompanion toCompanion(bool nullToAbsent) {
    return GitHubRepoPinsCompanion(
      id: Value(id),
      connectionId: Value(connectionId),
      owner: Value(owner),
      name: Value(name),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory GitHubRepoPin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GitHubRepoPin(
      id: serializer.fromJson<int>(json['id']),
      connectionId: serializer.fromJson<int>(json['connectionId']),
      owner: serializer.fromJson<String>(json['owner']),
      name: serializer.fromJson<String>(json['name']),
      pinnedAt: serializer.fromJson<DateTime>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'connectionId': serializer.toJson<int>(connectionId),
      'owner': serializer.toJson<String>(owner),
      'name': serializer.toJson<String>(name),
      'pinnedAt': serializer.toJson<DateTime>(pinnedAt),
    };
  }

  GitHubRepoPin copyWith({
    int? id,
    int? connectionId,
    String? owner,
    String? name,
    DateTime? pinnedAt,
  }) => GitHubRepoPin(
    id: id ?? this.id,
    connectionId: connectionId ?? this.connectionId,
    owner: owner ?? this.owner,
    name: name ?? this.name,
    pinnedAt: pinnedAt ?? this.pinnedAt,
  );
  GitHubRepoPin copyWithCompanion(GitHubRepoPinsCompanion data) {
    return GitHubRepoPin(
      id: data.id.present ? data.id.value : this.id,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      owner: data.owner.present ? data.owner.value : this.owner,
      name: data.name.present ? data.name.value : this.name,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GitHubRepoPin(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('owner: $owner, ')
          ..write('name: $name, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, connectionId, owner, name, pinnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GitHubRepoPin &&
          other.id == this.id &&
          other.connectionId == this.connectionId &&
          other.owner == this.owner &&
          other.name == this.name &&
          other.pinnedAt == this.pinnedAt);
}

class GitHubRepoPinsCompanion extends UpdateCompanion<GitHubRepoPin> {
  final Value<int> id;
  final Value<int> connectionId;
  final Value<String> owner;
  final Value<String> name;
  final Value<DateTime> pinnedAt;
  const GitHubRepoPinsCompanion({
    this.id = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.owner = const Value.absent(),
    this.name = const Value.absent(),
    this.pinnedAt = const Value.absent(),
  });
  GitHubRepoPinsCompanion.insert({
    this.id = const Value.absent(),
    required int connectionId,
    required String owner,
    required String name,
    required DateTime pinnedAt,
  }) : connectionId = Value(connectionId),
       owner = Value(owner),
       name = Value(name),
       pinnedAt = Value(pinnedAt);
  static Insertable<GitHubRepoPin> custom({
    Expression<int>? id,
    Expression<int>? connectionId,
    Expression<String>? owner,
    Expression<String>? name,
    Expression<DateTime>? pinnedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (connectionId != null) 'connection_id': connectionId,
      if (owner != null) 'owner': owner,
      if (name != null) 'name': name,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
    });
  }

  GitHubRepoPinsCompanion copyWith({
    Value<int>? id,
    Value<int>? connectionId,
    Value<String>? owner,
    Value<String>? name,
    Value<DateTime>? pinnedAt,
  }) {
    return GitHubRepoPinsCompanion(
      id: id ?? this.id,
      connectionId: connectionId ?? this.connectionId,
      owner: owner ?? this.owner,
      name: name ?? this.name,
      pinnedAt: pinnedAt ?? this.pinnedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<int>(connectionId.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GitHubRepoPinsCompanion(')
          ..write('id: $id, ')
          ..write('connectionId: $connectionId, ')
          ..write('owner: $owner, ')
          ..write('name: $name, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }
}

class $GitHubTokensTable extends GitHubTokens
    with TableInfo<$GitHubTokensTable, GitHubToken> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GitHubTokensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountLoginMeta = const VerificationMeta(
    'accountLogin',
  );
  @override
  late final GeneratedColumn<String> accountLogin = GeneratedColumn<String>(
    'account_login',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _encryptedTokenMeta = const VerificationMeta(
    'encryptedToken',
  );
  @override
  late final GeneratedColumn<String> encryptedToken = GeneratedColumn<String>(
    'encrypted_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenNonceMeta = const VerificationMeta(
    'tokenNonce',
  );
  @override
  late final GeneratedColumn<String> tokenNonce = GeneratedColumn<String>(
    'token_nonce',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountLogin,
    encryptedToken,
    tokenNonce,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'github_tokens';
  @override
  VerificationContext validateIntegrity(
    Insertable<GitHubToken> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_login')) {
      context.handle(
        _accountLoginMeta,
        accountLogin.isAcceptableOrUnknown(
          data['account_login']!,
          _accountLoginMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountLoginMeta);
    }
    if (data.containsKey('encrypted_token')) {
      context.handle(
        _encryptedTokenMeta,
        encryptedToken.isAcceptableOrUnknown(
          data['encrypted_token']!,
          _encryptedTokenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedTokenMeta);
    }
    if (data.containsKey('token_nonce')) {
      context.handle(
        _tokenNonceMeta,
        tokenNonce.isAcceptableOrUnknown(data['token_nonce']!, _tokenNonceMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenNonceMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GitHubToken map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GitHubToken(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountLogin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_login'],
      )!,
      encryptedToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_token'],
      )!,
      tokenNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_nonce'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GitHubTokensTable createAlias(String alias) {
    return $GitHubTokensTable(attachedDatabase, alias);
  }
}

class GitHubToken extends DataClass implements Insertable<GitHubToken> {
  final int id;
  final String accountLogin;
  final String encryptedToken;
  final String tokenNonce;
  final DateTime updatedAt;
  const GitHubToken({
    required this.id,
    required this.accountLogin,
    required this.encryptedToken,
    required this.tokenNonce,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_login'] = Variable<String>(accountLogin);
    map['encrypted_token'] = Variable<String>(encryptedToken);
    map['token_nonce'] = Variable<String>(tokenNonce);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GitHubTokensCompanion toCompanion(bool nullToAbsent) {
    return GitHubTokensCompanion(
      id: Value(id),
      accountLogin: Value(accountLogin),
      encryptedToken: Value(encryptedToken),
      tokenNonce: Value(tokenNonce),
      updatedAt: Value(updatedAt),
    );
  }

  factory GitHubToken.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GitHubToken(
      id: serializer.fromJson<int>(json['id']),
      accountLogin: serializer.fromJson<String>(json['accountLogin']),
      encryptedToken: serializer.fromJson<String>(json['encryptedToken']),
      tokenNonce: serializer.fromJson<String>(json['tokenNonce']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountLogin': serializer.toJson<String>(accountLogin),
      'encryptedToken': serializer.toJson<String>(encryptedToken),
      'tokenNonce': serializer.toJson<String>(tokenNonce),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GitHubToken copyWith({
    int? id,
    String? accountLogin,
    String? encryptedToken,
    String? tokenNonce,
    DateTime? updatedAt,
  }) => GitHubToken(
    id: id ?? this.id,
    accountLogin: accountLogin ?? this.accountLogin,
    encryptedToken: encryptedToken ?? this.encryptedToken,
    tokenNonce: tokenNonce ?? this.tokenNonce,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GitHubToken copyWithCompanion(GitHubTokensCompanion data) {
    return GitHubToken(
      id: data.id.present ? data.id.value : this.id,
      accountLogin: data.accountLogin.present
          ? data.accountLogin.value
          : this.accountLogin,
      encryptedToken: data.encryptedToken.present
          ? data.encryptedToken.value
          : this.encryptedToken,
      tokenNonce: data.tokenNonce.present
          ? data.tokenNonce.value
          : this.tokenNonce,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GitHubToken(')
          ..write('id: $id, ')
          ..write('accountLogin: $accountLogin, ')
          ..write('encryptedToken: $encryptedToken, ')
          ..write('tokenNonce: $tokenNonce, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, accountLogin, encryptedToken, tokenNonce, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GitHubToken &&
          other.id == this.id &&
          other.accountLogin == this.accountLogin &&
          other.encryptedToken == this.encryptedToken &&
          other.tokenNonce == this.tokenNonce &&
          other.updatedAt == this.updatedAt);
}

class GitHubTokensCompanion extends UpdateCompanion<GitHubToken> {
  final Value<int> id;
  final Value<String> accountLogin;
  final Value<String> encryptedToken;
  final Value<String> tokenNonce;
  final Value<DateTime> updatedAt;
  const GitHubTokensCompanion({
    this.id = const Value.absent(),
    this.accountLogin = const Value.absent(),
    this.encryptedToken = const Value.absent(),
    this.tokenNonce = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GitHubTokensCompanion.insert({
    this.id = const Value.absent(),
    required String accountLogin,
    required String encryptedToken,
    required String tokenNonce,
    required DateTime updatedAt,
  }) : accountLogin = Value(accountLogin),
       encryptedToken = Value(encryptedToken),
       tokenNonce = Value(tokenNonce),
       updatedAt = Value(updatedAt);
  static Insertable<GitHubToken> custom({
    Expression<int>? id,
    Expression<String>? accountLogin,
    Expression<String>? encryptedToken,
    Expression<String>? tokenNonce,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountLogin != null) 'account_login': accountLogin,
      if (encryptedToken != null) 'encrypted_token': encryptedToken,
      if (tokenNonce != null) 'token_nonce': tokenNonce,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GitHubTokensCompanion copyWith({
    Value<int>? id,
    Value<String>? accountLogin,
    Value<String>? encryptedToken,
    Value<String>? tokenNonce,
    Value<DateTime>? updatedAt,
  }) {
    return GitHubTokensCompanion(
      id: id ?? this.id,
      accountLogin: accountLogin ?? this.accountLogin,
      encryptedToken: encryptedToken ?? this.encryptedToken,
      tokenNonce: tokenNonce ?? this.tokenNonce,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountLogin.present) {
      map['account_login'] = Variable<String>(accountLogin.value);
    }
    if (encryptedToken.present) {
      map['encrypted_token'] = Variable<String>(encryptedToken.value);
    }
    if (tokenNonce.present) {
      map['token_nonce'] = Variable<String>(tokenNonce.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GitHubTokensCompanion(')
          ..write('id: $id, ')
          ..write('accountLogin: $accountLogin, ')
          ..write('encryptedToken: $encryptedToken, ')
          ..write('tokenNonce: $tokenNonce, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PortForwardConfigsTable extends PortForwardConfigs
    with TableInfo<$PortForwardConfigsTable, PortForwardConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortForwardConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bindHostMeta = const VerificationMeta(
    'bindHost',
  );
  @override
  late final GeneratedColumn<String> bindHost = GeneratedColumn<String>(
    'bind_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bindPortMeta = const VerificationMeta(
    'bindPort',
  );
  @override
  late final GeneratedColumn<int> bindPort = GeneratedColumn<int>(
    'bind_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetHostMeta = const VerificationMeta(
    'targetHost',
  );
  @override
  late final GeneratedColumn<String> targetHost = GeneratedColumn<String>(
    'target_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPortMeta = const VerificationMeta(
    'targetPort',
  );
  @override
  late final GeneratedColumn<int> targetPort = GeneratedColumn<int>(
    'target_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoStartMeta = const VerificationMeta(
    'autoStart',
  );
  @override
  late final GeneratedColumn<bool> autoStart = GeneratedColumn<bool>(
    'auto_start',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_start" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    direction,
    kind,
    bindHost,
    bindPort,
    targetHost,
    targetPort,
    autoStart,
    keepAlive,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'port_forward_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortForwardConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('bind_host')) {
      context.handle(
        _bindHostMeta,
        bindHost.isAcceptableOrUnknown(data['bind_host']!, _bindHostMeta),
      );
    } else if (isInserting) {
      context.missing(_bindHostMeta);
    }
    if (data.containsKey('bind_port')) {
      context.handle(
        _bindPortMeta,
        bindPort.isAcceptableOrUnknown(data['bind_port']!, _bindPortMeta),
      );
    } else if (isInserting) {
      context.missing(_bindPortMeta);
    }
    if (data.containsKey('target_host')) {
      context.handle(
        _targetHostMeta,
        targetHost.isAcceptableOrUnknown(data['target_host']!, _targetHostMeta),
      );
    } else if (isInserting) {
      context.missing(_targetHostMeta);
    }
    if (data.containsKey('target_port')) {
      context.handle(
        _targetPortMeta,
        targetPort.isAcceptableOrUnknown(data['target_port']!, _targetPortMeta),
      );
    } else if (isInserting) {
      context.missing(_targetPortMeta);
    }
    if (data.containsKey('auto_start')) {
      context.handle(
        _autoStartMeta,
        autoStart.isAcceptableOrUnknown(data['auto_start']!, _autoStartMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortForwardConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortForwardConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      bindHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bind_host'],
      )!,
      bindPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bind_port'],
      )!,
      targetHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_host'],
      )!,
      targetPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_port'],
      )!,
      autoStart: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_start'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PortForwardConfigsTable createAlias(String alias) {
    return $PortForwardConfigsTable(attachedDatabase, alias);
  }
}

class PortForwardConfig extends DataClass
    implements Insertable<PortForwardConfig> {
  final int id;
  final int serverId;
  final String direction;
  final String kind;
  final String bindHost;
  final int bindPort;
  final String targetHost;
  final int targetPort;
  final bool autoStart;

  /// Re-establish the forward with backoff whenever it drops while the SSH
  /// session itself stays connected.
  final bool keepAlive;

  /// Manual position in the forward table; null sorts after ordered rows,
  /// then by creation time.
  final int? sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PortForwardConfig({
    required this.id,
    required this.serverId,
    required this.direction,
    required this.kind,
    required this.bindHost,
    required this.bindPort,
    required this.targetHost,
    required this.targetPort,
    required this.autoStart,
    required this.keepAlive,
    this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_id'] = Variable<int>(serverId);
    map['direction'] = Variable<String>(direction);
    map['kind'] = Variable<String>(kind);
    map['bind_host'] = Variable<String>(bindHost);
    map['bind_port'] = Variable<int>(bindPort);
    map['target_host'] = Variable<String>(targetHost);
    map['target_port'] = Variable<int>(targetPort);
    map['auto_start'] = Variable<bool>(autoStart);
    map['keep_alive'] = Variable<bool>(keepAlive);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PortForwardConfigsCompanion toCompanion(bool nullToAbsent) {
    return PortForwardConfigsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      direction: Value(direction),
      kind: Value(kind),
      bindHost: Value(bindHost),
      bindPort: Value(bindPort),
      targetHost: Value(targetHost),
      targetPort: Value(targetPort),
      autoStart: Value(autoStart),
      keepAlive: Value(keepAlive),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PortForwardConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortForwardConfig(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int>(json['serverId']),
      direction: serializer.fromJson<String>(json['direction']),
      kind: serializer.fromJson<String>(json['kind']),
      bindHost: serializer.fromJson<String>(json['bindHost']),
      bindPort: serializer.fromJson<int>(json['bindPort']),
      targetHost: serializer.fromJson<String>(json['targetHost']),
      targetPort: serializer.fromJson<int>(json['targetPort']),
      autoStart: serializer.fromJson<bool>(json['autoStart']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int>(serverId),
      'direction': serializer.toJson<String>(direction),
      'kind': serializer.toJson<String>(kind),
      'bindHost': serializer.toJson<String>(bindHost),
      'bindPort': serializer.toJson<int>(bindPort),
      'targetHost': serializer.toJson<String>(targetHost),
      'targetPort': serializer.toJson<int>(targetPort),
      'autoStart': serializer.toJson<bool>(autoStart),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PortForwardConfig copyWith({
    int? id,
    int? serverId,
    String? direction,
    String? kind,
    String? bindHost,
    int? bindPort,
    String? targetHost,
    int? targetPort,
    bool? autoStart,
    bool? keepAlive,
    Value<int?> sortOrder = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PortForwardConfig(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    direction: direction ?? this.direction,
    kind: kind ?? this.kind,
    bindHost: bindHost ?? this.bindHost,
    bindPort: bindPort ?? this.bindPort,
    targetHost: targetHost ?? this.targetHost,
    targetPort: targetPort ?? this.targetPort,
    autoStart: autoStart ?? this.autoStart,
    keepAlive: keepAlive ?? this.keepAlive,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PortForwardConfig copyWithCompanion(PortForwardConfigsCompanion data) {
    return PortForwardConfig(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      direction: data.direction.present ? data.direction.value : this.direction,
      kind: data.kind.present ? data.kind.value : this.kind,
      bindHost: data.bindHost.present ? data.bindHost.value : this.bindHost,
      bindPort: data.bindPort.present ? data.bindPort.value : this.bindPort,
      targetHost: data.targetHost.present
          ? data.targetHost.value
          : this.targetHost,
      targetPort: data.targetPort.present
          ? data.targetPort.value
          : this.targetPort,
      autoStart: data.autoStart.present ? data.autoStart.value : this.autoStart,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortForwardConfig(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('direction: $direction, ')
          ..write('kind: $kind, ')
          ..write('bindHost: $bindHost, ')
          ..write('bindPort: $bindPort, ')
          ..write('targetHost: $targetHost, ')
          ..write('targetPort: $targetPort, ')
          ..write('autoStart: $autoStart, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    direction,
    kind,
    bindHost,
    bindPort,
    targetHost,
    targetPort,
    autoStart,
    keepAlive,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortForwardConfig &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.direction == this.direction &&
          other.kind == this.kind &&
          other.bindHost == this.bindHost &&
          other.bindPort == this.bindPort &&
          other.targetHost == this.targetHost &&
          other.targetPort == this.targetPort &&
          other.autoStart == this.autoStart &&
          other.keepAlive == this.keepAlive &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PortForwardConfigsCompanion extends UpdateCompanion<PortForwardConfig> {
  final Value<int> id;
  final Value<int> serverId;
  final Value<String> direction;
  final Value<String> kind;
  final Value<String> bindHost;
  final Value<int> bindPort;
  final Value<String> targetHost;
  final Value<int> targetPort;
  final Value<bool> autoStart;
  final Value<bool> keepAlive;
  final Value<int?> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PortForwardConfigsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.direction = const Value.absent(),
    this.kind = const Value.absent(),
    this.bindHost = const Value.absent(),
    this.bindPort = const Value.absent(),
    this.targetHost = const Value.absent(),
    this.targetPort = const Value.absent(),
    this.autoStart = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PortForwardConfigsCompanion.insert({
    this.id = const Value.absent(),
    required int serverId,
    required String direction,
    required String kind,
    required String bindHost,
    required int bindPort,
    required String targetHost,
    required int targetPort,
    this.autoStart = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : serverId = Value(serverId),
       direction = Value(direction),
       kind = Value(kind),
       bindHost = Value(bindHost),
       bindPort = Value(bindPort),
       targetHost = Value(targetHost),
       targetPort = Value(targetPort),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PortForwardConfig> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? direction,
    Expression<String>? kind,
    Expression<String>? bindHost,
    Expression<int>? bindPort,
    Expression<String>? targetHost,
    Expression<int>? targetPort,
    Expression<bool>? autoStart,
    Expression<bool>? keepAlive,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (direction != null) 'direction': direction,
      if (kind != null) 'kind': kind,
      if (bindHost != null) 'bind_host': bindHost,
      if (bindPort != null) 'bind_port': bindPort,
      if (targetHost != null) 'target_host': targetHost,
      if (targetPort != null) 'target_port': targetPort,
      if (autoStart != null) 'auto_start': autoStart,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PortForwardConfigsCompanion copyWith({
    Value<int>? id,
    Value<int>? serverId,
    Value<String>? direction,
    Value<String>? kind,
    Value<String>? bindHost,
    Value<int>? bindPort,
    Value<String>? targetHost,
    Value<int>? targetPort,
    Value<bool>? autoStart,
    Value<bool>? keepAlive,
    Value<int?>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PortForwardConfigsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      direction: direction ?? this.direction,
      kind: kind ?? this.kind,
      bindHost: bindHost ?? this.bindHost,
      bindPort: bindPort ?? this.bindPort,
      targetHost: targetHost ?? this.targetHost,
      targetPort: targetPort ?? this.targetPort,
      autoStart: autoStart ?? this.autoStart,
      keepAlive: keepAlive ?? this.keepAlive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (bindHost.present) {
      map['bind_host'] = Variable<String>(bindHost.value);
    }
    if (bindPort.present) {
      map['bind_port'] = Variable<int>(bindPort.value);
    }
    if (targetHost.present) {
      map['target_host'] = Variable<String>(targetHost.value);
    }
    if (targetPort.present) {
      map['target_port'] = Variable<int>(targetPort.value);
    }
    if (autoStart.present) {
      map['auto_start'] = Variable<bool>(autoStart.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortForwardConfigsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('direction: $direction, ')
          ..write('kind: $kind, ')
          ..write('bindHost: $bindHost, ')
          ..write('bindPort: $bindPort, ')
          ..write('targetHost: $targetHost, ')
          ..write('targetPort: $targetPort, ')
          ..write('autoStart: $autoStart, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServersTable servers = $ServersTable(this);
  late final $SavedCredentialsTable savedCredentials = $SavedCredentialsTable(
    this,
  );
  late final $VaultMetadataTable vaultMetadata = $VaultMetadataTable(this);
  late final $GitHubConnectionsTable gitHubConnections =
      $GitHubConnectionsTable(this);
  late final $GitHubRepoPinsTable gitHubRepoPins = $GitHubRepoPinsTable(this);
  late final $GitHubTokensTable gitHubTokens = $GitHubTokensTable(this);
  late final $PortForwardConfigsTable portForwardConfigs =
      $PortForwardConfigsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    servers,
    savedCredentials,
    vaultMetadata,
    gitHubConnections,
    gitHubRepoPins,
    gitHubTokens,
    portForwardConfigs,
    appSettings,
  ];
}

typedef $$ServersTableCreateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      required String name,
      required String host,
      Value<int> port,
      required String username,
      Value<DateTime?> lastConnectedAt,
      Value<String?> syncId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> credentialId,
      Value<String?> hostKeyFingerprint,
      Value<bool> collectStats,
      Value<bool> collectSystemInfo,
      Value<String?> proxyType,
      Value<String?> proxyHost,
      Value<int?> proxyPort,
      Value<String?> proxyUsername,
      Value<String?> encryptedProxyPassword,
      Value<String?> proxyPasswordNonce,
      Value<int?> jumpHostServerId,
      Value<String?> environment,
      Value<String?> tags,
      Value<String> connectionType,
      Value<int?> sortOrder,
    });
typedef $$ServersTableUpdateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> host,
      Value<int> port,
      Value<String> username,
      Value<DateTime?> lastConnectedAt,
      Value<String?> syncId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> credentialId,
      Value<String?> hostKeyFingerprint,
      Value<bool> collectStats,
      Value<bool> collectSystemInfo,
      Value<String?> proxyType,
      Value<String?> proxyHost,
      Value<int?> proxyPort,
      Value<String?> proxyUsername,
      Value<String?> encryptedProxyPassword,
      Value<String?> proxyPasswordNonce,
      Value<int?> jumpHostServerId,
      Value<String?> environment,
      Value<String?> tags,
      Value<String> connectionType,
      Value<int?> sortOrder,
    });

class $$ServersTableFilterComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get credentialId => $composableBuilder(
    column: $table.credentialId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostKeyFingerprint => $composableBuilder(
    column: $table.hostKeyFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collectStats => $composableBuilder(
    column: $table.collectStats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collectSystemInfo => $composableBuilder(
    column: $table.collectSystemInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxyType => $composableBuilder(
    column: $table.proxyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxyHost => $composableBuilder(
    column: $table.proxyHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proxyPort => $composableBuilder(
    column: $table.proxyPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxyUsername => $composableBuilder(
    column: $table.proxyUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedProxyPassword => $composableBuilder(
    column: $table.encryptedProxyPassword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxyPasswordNonce => $composableBuilder(
    column: $table.proxyPasswordNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get jumpHostServerId => $composableBuilder(
    column: $table.jumpHostServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get connectionType => $composableBuilder(
    column: $table.connectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServersTableOrderingComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get credentialId => $composableBuilder(
    column: $table.credentialId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostKeyFingerprint => $composableBuilder(
    column: $table.hostKeyFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collectStats => $composableBuilder(
    column: $table.collectStats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collectSystemInfo => $composableBuilder(
    column: $table.collectSystemInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxyType => $composableBuilder(
    column: $table.proxyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxyHost => $composableBuilder(
    column: $table.proxyHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proxyPort => $composableBuilder(
    column: $table.proxyPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxyUsername => $composableBuilder(
    column: $table.proxyUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedProxyPassword => $composableBuilder(
    column: $table.encryptedProxyPassword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxyPasswordNonce => $composableBuilder(
    column: $table.proxyPasswordNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get jumpHostServerId => $composableBuilder(
    column: $table.jumpHostServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get connectionType => $composableBuilder(
    column: $table.connectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get credentialId => $composableBuilder(
    column: $table.credentialId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hostKeyFingerprint => $composableBuilder(
    column: $table.hostKeyFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get collectStats => $composableBuilder(
    column: $table.collectStats,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get collectSystemInfo => $composableBuilder(
    column: $table.collectSystemInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proxyType =>
      $composableBuilder(column: $table.proxyType, builder: (column) => column);

  GeneratedColumn<String> get proxyHost =>
      $composableBuilder(column: $table.proxyHost, builder: (column) => column);

  GeneratedColumn<int> get proxyPort =>
      $composableBuilder(column: $table.proxyPort, builder: (column) => column);

  GeneratedColumn<String> get proxyUsername => $composableBuilder(
    column: $table.proxyUsername,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedProxyPassword => $composableBuilder(
    column: $table.encryptedProxyPassword,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proxyPasswordNonce => $composableBuilder(
    column: $table.proxyPasswordNonce,
    builder: (column) => column,
  );

  GeneratedColumn<int> get jumpHostServerId => $composableBuilder(
    column: $table.jumpHostServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get connectionType => $composableBuilder(
    column: $table.connectionType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ServersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServersTable,
          Server,
          $$ServersTableFilterComposer,
          $$ServersTableOrderingComposer,
          $$ServersTableAnnotationComposer,
          $$ServersTableCreateCompanionBuilder,
          $$ServersTableUpdateCompanionBuilder,
          (Server, BaseReferences<_$AppDatabase, $ServersTable, Server>),
          Server,
          PrefetchHooks Function()
        > {
  $$ServersTableTableManager(_$AppDatabase db, $ServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> credentialId = const Value.absent(),
                Value<String?> hostKeyFingerprint = const Value.absent(),
                Value<bool> collectStats = const Value.absent(),
                Value<bool> collectSystemInfo = const Value.absent(),
                Value<String?> proxyType = const Value.absent(),
                Value<String?> proxyHost = const Value.absent(),
                Value<int?> proxyPort = const Value.absent(),
                Value<String?> proxyUsername = const Value.absent(),
                Value<String?> encryptedProxyPassword = const Value.absent(),
                Value<String?> proxyPasswordNonce = const Value.absent(),
                Value<int?> jumpHostServerId = const Value.absent(),
                Value<String?> environment = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String> connectionType = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
              }) => ServersCompanion(
                id: id,
                name: name,
                host: host,
                port: port,
                username: username,
                lastConnectedAt: lastConnectedAt,
                syncId: syncId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                credentialId: credentialId,
                hostKeyFingerprint: hostKeyFingerprint,
                collectStats: collectStats,
                collectSystemInfo: collectSystemInfo,
                proxyType: proxyType,
                proxyHost: proxyHost,
                proxyPort: proxyPort,
                proxyUsername: proxyUsername,
                encryptedProxyPassword: encryptedProxyPassword,
                proxyPasswordNonce: proxyPasswordNonce,
                jumpHostServerId: jumpHostServerId,
                environment: environment,
                tags: tags,
                connectionType: connectionType,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String host,
                Value<int> port = const Value.absent(),
                required String username,
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> credentialId = const Value.absent(),
                Value<String?> hostKeyFingerprint = const Value.absent(),
                Value<bool> collectStats = const Value.absent(),
                Value<bool> collectSystemInfo = const Value.absent(),
                Value<String?> proxyType = const Value.absent(),
                Value<String?> proxyHost = const Value.absent(),
                Value<int?> proxyPort = const Value.absent(),
                Value<String?> proxyUsername = const Value.absent(),
                Value<String?> encryptedProxyPassword = const Value.absent(),
                Value<String?> proxyPasswordNonce = const Value.absent(),
                Value<int?> jumpHostServerId = const Value.absent(),
                Value<String?> environment = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String> connectionType = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
              }) => ServersCompanion.insert(
                id: id,
                name: name,
                host: host,
                port: port,
                username: username,
                lastConnectedAt: lastConnectedAt,
                syncId: syncId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                credentialId: credentialId,
                hostKeyFingerprint: hostKeyFingerprint,
                collectStats: collectStats,
                collectSystemInfo: collectSystemInfo,
                proxyType: proxyType,
                proxyHost: proxyHost,
                proxyPort: proxyPort,
                proxyUsername: proxyUsername,
                encryptedProxyPassword: encryptedProxyPassword,
                proxyPasswordNonce: proxyPasswordNonce,
                jumpHostServerId: jumpHostServerId,
                environment: environment,
                tags: tags,
                connectionType: connectionType,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServersTable,
      Server,
      $$ServersTableFilterComposer,
      $$ServersTableOrderingComposer,
      $$ServersTableAnnotationComposer,
      $$ServersTableCreateCompanionBuilder,
      $$ServersTableUpdateCompanionBuilder,
      (Server, BaseReferences<_$AppDatabase, $ServersTable, Server>),
      Server,
      PrefetchHooks Function()
    >;
typedef $$SavedCredentialsTableCreateCompanionBuilder =
    SavedCredentialsCompanion Function({
      Value<int> id,
      required String name,
      required String credentialType,
      required String encryptedCredential,
      required String credentialNonce,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$SavedCredentialsTableUpdateCompanionBuilder =
    SavedCredentialsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> credentialType,
      Value<String> encryptedCredential,
      Value<String> credentialNonce,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$SavedCredentialsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedCredentialsTable> {
  $$SavedCredentialsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialType => $composableBuilder(
    column: $table.credentialType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedCredential => $composableBuilder(
    column: $table.encryptedCredential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialNonce => $composableBuilder(
    column: $table.credentialNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedCredentialsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedCredentialsTable> {
  $$SavedCredentialsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialType => $composableBuilder(
    column: $table.credentialType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedCredential => $composableBuilder(
    column: $table.encryptedCredential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialNonce => $composableBuilder(
    column: $table.credentialNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedCredentialsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedCredentialsTable> {
  $$SavedCredentialsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get credentialType => $composableBuilder(
    column: $table.credentialType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedCredential => $composableBuilder(
    column: $table.encryptedCredential,
    builder: (column) => column,
  );

  GeneratedColumn<String> get credentialNonce => $composableBuilder(
    column: $table.credentialNonce,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SavedCredentialsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedCredentialsTable,
          SavedCredential,
          $$SavedCredentialsTableFilterComposer,
          $$SavedCredentialsTableOrderingComposer,
          $$SavedCredentialsTableAnnotationComposer,
          $$SavedCredentialsTableCreateCompanionBuilder,
          $$SavedCredentialsTableUpdateCompanionBuilder,
          (
            SavedCredential,
            BaseReferences<
              _$AppDatabase,
              $SavedCredentialsTable,
              SavedCredential
            >,
          ),
          SavedCredential,
          PrefetchHooks Function()
        > {
  $$SavedCredentialsTableTableManager(
    _$AppDatabase db,
    $SavedCredentialsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedCredentialsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedCredentialsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedCredentialsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> credentialType = const Value.absent(),
                Value<String> encryptedCredential = const Value.absent(),
                Value<String> credentialNonce = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SavedCredentialsCompanion(
                id: id,
                name: name,
                credentialType: credentialType,
                encryptedCredential: encryptedCredential,
                credentialNonce: credentialNonce,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String credentialType,
                required String encryptedCredential,
                required String credentialNonce,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => SavedCredentialsCompanion.insert(
                id: id,
                name: name,
                credentialType: credentialType,
                encryptedCredential: encryptedCredential,
                credentialNonce: credentialNonce,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedCredentialsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedCredentialsTable,
      SavedCredential,
      $$SavedCredentialsTableFilterComposer,
      $$SavedCredentialsTableOrderingComposer,
      $$SavedCredentialsTableAnnotationComposer,
      $$SavedCredentialsTableCreateCompanionBuilder,
      $$SavedCredentialsTableUpdateCompanionBuilder,
      (
        SavedCredential,
        BaseReferences<_$AppDatabase, $SavedCredentialsTable, SavedCredential>,
      ),
      SavedCredential,
      PrefetchHooks Function()
    >;
typedef $$VaultMetadataTableCreateCompanionBuilder =
    VaultMetadataCompanion Function({
      Value<int> id,
      required int formatVersion,
      required String salt,
      required String wrappedDataKey,
      required String wrappedDataKeyNonce,
      required String verifier,
      required String verifierNonce,
      required DateTime createdAt,
    });
typedef $$VaultMetadataTableUpdateCompanionBuilder =
    VaultMetadataCompanion Function({
      Value<int> id,
      Value<int> formatVersion,
      Value<String> salt,
      Value<String> wrappedDataKey,
      Value<String> wrappedDataKeyNonce,
      Value<String> verifier,
      Value<String> verifierNonce,
      Value<DateTime> createdAt,
    });

class $$VaultMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $VaultMetadataTable> {
  $$VaultMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrappedDataKey => $composableBuilder(
    column: $table.wrappedDataKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrappedDataKeyNonce => $composableBuilder(
    column: $table.wrappedDataKeyNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifier => $composableBuilder(
    column: $table.verifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifierNonce => $composableBuilder(
    column: $table.verifierNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultMetadataTable> {
  $$VaultMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrappedDataKey => $composableBuilder(
    column: $table.wrappedDataKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrappedDataKeyNonce => $composableBuilder(
    column: $table.wrappedDataKeyNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifier => $composableBuilder(
    column: $table.verifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifierNonce => $composableBuilder(
    column: $table.verifierNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultMetadataTable> {
  $$VaultMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get salt =>
      $composableBuilder(column: $table.salt, builder: (column) => column);

  GeneratedColumn<String> get wrappedDataKey => $composableBuilder(
    column: $table.wrappedDataKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wrappedDataKeyNonce => $composableBuilder(
    column: $table.wrappedDataKeyNonce,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verifier =>
      $composableBuilder(column: $table.verifier, builder: (column) => column);

  GeneratedColumn<String> get verifierNonce => $composableBuilder(
    column: $table.verifierNonce,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$VaultMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultMetadataTable,
          VaultMetadataData,
          $$VaultMetadataTableFilterComposer,
          $$VaultMetadataTableOrderingComposer,
          $$VaultMetadataTableAnnotationComposer,
          $$VaultMetadataTableCreateCompanionBuilder,
          $$VaultMetadataTableUpdateCompanionBuilder,
          (
            VaultMetadataData,
            BaseReferences<
              _$AppDatabase,
              $VaultMetadataTable,
              VaultMetadataData
            >,
          ),
          VaultMetadataData,
          PrefetchHooks Function()
        > {
  $$VaultMetadataTableTableManager(_$AppDatabase db, $VaultMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<String> salt = const Value.absent(),
                Value<String> wrappedDataKey = const Value.absent(),
                Value<String> wrappedDataKeyNonce = const Value.absent(),
                Value<String> verifier = const Value.absent(),
                Value<String> verifierNonce = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => VaultMetadataCompanion(
                id: id,
                formatVersion: formatVersion,
                salt: salt,
                wrappedDataKey: wrappedDataKey,
                wrappedDataKeyNonce: wrappedDataKeyNonce,
                verifier: verifier,
                verifierNonce: verifierNonce,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int formatVersion,
                required String salt,
                required String wrappedDataKey,
                required String wrappedDataKeyNonce,
                required String verifier,
                required String verifierNonce,
                required DateTime createdAt,
              }) => VaultMetadataCompanion.insert(
                id: id,
                formatVersion: formatVersion,
                salt: salt,
                wrappedDataKey: wrappedDataKey,
                wrappedDataKeyNonce: wrappedDataKeyNonce,
                verifier: verifier,
                verifierNonce: verifierNonce,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultMetadataTable,
      VaultMetadataData,
      $$VaultMetadataTableFilterComposer,
      $$VaultMetadataTableOrderingComposer,
      $$VaultMetadataTableAnnotationComposer,
      $$VaultMetadataTableCreateCompanionBuilder,
      $$VaultMetadataTableUpdateCompanionBuilder,
      (
        VaultMetadataData,
        BaseReferences<_$AppDatabase, $VaultMetadataTable, VaultMetadataData>,
      ),
      VaultMetadataData,
      PrefetchHooks Function()
    >;
typedef $$GitHubConnectionsTableCreateCompanionBuilder =
    GitHubConnectionsCompanion Function({
      Value<int> id,
      required String accountLogin,
      Value<String> accountName,
      Value<String> avatarUrl,
      required DateTime createdAt,
    });
typedef $$GitHubConnectionsTableUpdateCompanionBuilder =
    GitHubConnectionsCompanion Function({
      Value<int> id,
      Value<String> accountLogin,
      Value<String> accountName,
      Value<String> avatarUrl,
      Value<DateTime> createdAt,
    });

final class $$GitHubConnectionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GitHubConnectionsTable,
          GitHubConnection
        > {
  $$GitHubConnectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$GitHubRepoPinsTable, List<GitHubRepoPin>>
  _gitHubRepoPinsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gitHubRepoPins,
    aliasName: 'github_connections__id__github_repo_pins__connection_id',
  );

  $$GitHubRepoPinsTableProcessedTableManager get gitHubRepoPinsRefs {
    final manager = $$GitHubRepoPinsTableTableManager(
      $_db,
      $_db.gitHubRepoPins,
    ).filter((f) => f.connectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gitHubRepoPinsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GitHubConnectionsTableFilterComposer
    extends Composer<_$AppDatabase, $GitHubConnectionsTable> {
  $$GitHubConnectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountLogin => $composableBuilder(
    column: $table.accountLogin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountName => $composableBuilder(
    column: $table.accountName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> gitHubRepoPinsRefs(
    Expression<bool> Function($$GitHubRepoPinsTableFilterComposer f) f,
  ) {
    final $$GitHubRepoPinsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gitHubRepoPins,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GitHubRepoPinsTableFilterComposer(
            $db: $db,
            $table: $db.gitHubRepoPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GitHubConnectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $GitHubConnectionsTable> {
  $$GitHubConnectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountLogin => $composableBuilder(
    column: $table.accountLogin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountName => $composableBuilder(
    column: $table.accountName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GitHubConnectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GitHubConnectionsTable> {
  $$GitHubConnectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountLogin => $composableBuilder(
    column: $table.accountLogin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountName => $composableBuilder(
    column: $table.accountName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> gitHubRepoPinsRefs<T extends Object>(
    Expression<T> Function($$GitHubRepoPinsTableAnnotationComposer a) f,
  ) {
    final $$GitHubRepoPinsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gitHubRepoPins,
      getReferencedColumn: (t) => t.connectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GitHubRepoPinsTableAnnotationComposer(
            $db: $db,
            $table: $db.gitHubRepoPins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GitHubConnectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GitHubConnectionsTable,
          GitHubConnection,
          $$GitHubConnectionsTableFilterComposer,
          $$GitHubConnectionsTableOrderingComposer,
          $$GitHubConnectionsTableAnnotationComposer,
          $$GitHubConnectionsTableCreateCompanionBuilder,
          $$GitHubConnectionsTableUpdateCompanionBuilder,
          (GitHubConnection, $$GitHubConnectionsTableReferences),
          GitHubConnection,
          PrefetchHooks Function({bool gitHubRepoPinsRefs})
        > {
  $$GitHubConnectionsTableTableManager(
    _$AppDatabase db,
    $GitHubConnectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GitHubConnectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GitHubConnectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GitHubConnectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountLogin = const Value.absent(),
                Value<String> accountName = const Value.absent(),
                Value<String> avatarUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GitHubConnectionsCompanion(
                id: id,
                accountLogin: accountLogin,
                accountName: accountName,
                avatarUrl: avatarUrl,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountLogin,
                Value<String> accountName = const Value.absent(),
                Value<String> avatarUrl = const Value.absent(),
                required DateTime createdAt,
              }) => GitHubConnectionsCompanion.insert(
                id: id,
                accountLogin: accountLogin,
                accountName: accountName,
                avatarUrl: avatarUrl,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GitHubConnectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gitHubRepoPinsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (gitHubRepoPinsRefs) db.gitHubRepoPins,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (gitHubRepoPinsRefs)
                    await $_getPrefetchedData<
                      GitHubConnection,
                      $GitHubConnectionsTable,
                      GitHubRepoPin
                    >(
                      currentTable: table,
                      referencedTable: $$GitHubConnectionsTableReferences
                          ._gitHubRepoPinsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GitHubConnectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).gitHubRepoPinsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.connectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GitHubConnectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GitHubConnectionsTable,
      GitHubConnection,
      $$GitHubConnectionsTableFilterComposer,
      $$GitHubConnectionsTableOrderingComposer,
      $$GitHubConnectionsTableAnnotationComposer,
      $$GitHubConnectionsTableCreateCompanionBuilder,
      $$GitHubConnectionsTableUpdateCompanionBuilder,
      (GitHubConnection, $$GitHubConnectionsTableReferences),
      GitHubConnection,
      PrefetchHooks Function({bool gitHubRepoPinsRefs})
    >;
typedef $$GitHubRepoPinsTableCreateCompanionBuilder =
    GitHubRepoPinsCompanion Function({
      Value<int> id,
      required int connectionId,
      required String owner,
      required String name,
      required DateTime pinnedAt,
    });
typedef $$GitHubRepoPinsTableUpdateCompanionBuilder =
    GitHubRepoPinsCompanion Function({
      Value<int> id,
      Value<int> connectionId,
      Value<String> owner,
      Value<String> name,
      Value<DateTime> pinnedAt,
    });

final class $$GitHubRepoPinsTableReferences
    extends BaseReferences<_$AppDatabase, $GitHubRepoPinsTable, GitHubRepoPin> {
  $$GitHubRepoPinsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GitHubConnectionsTable _connectionIdTable(_$AppDatabase db) => db
      .gitHubConnections
      .createAlias('github_repo_pins__connection_id__github_connections__id');

  $$GitHubConnectionsTableProcessedTableManager get connectionId {
    final $_column = $_itemColumn<int>('connection_id')!;

    final manager = $$GitHubConnectionsTableTableManager(
      $_db,
      $_db.gitHubConnections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_connectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GitHubRepoPinsTableFilterComposer
    extends Composer<_$AppDatabase, $GitHubRepoPinsTable> {
  $$GitHubRepoPinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GitHubConnectionsTableFilterComposer get connectionId {
    final $$GitHubConnectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.gitHubConnections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GitHubConnectionsTableFilterComposer(
            $db: $db,
            $table: $db.gitHubConnections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GitHubRepoPinsTableOrderingComposer
    extends Composer<_$AppDatabase, $GitHubRepoPinsTable> {
  $$GitHubRepoPinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GitHubConnectionsTableOrderingComposer get connectionId {
    final $$GitHubConnectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.connectionId,
      referencedTable: $db.gitHubConnections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GitHubConnectionsTableOrderingComposer(
            $db: $db,
            $table: $db.gitHubConnections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GitHubRepoPinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GitHubRepoPinsTable> {
  $$GitHubRepoPinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);

  $$GitHubConnectionsTableAnnotationComposer get connectionId {
    final $$GitHubConnectionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.connectionId,
          referencedTable: $db.gitHubConnections,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GitHubConnectionsTableAnnotationComposer(
                $db: $db,
                $table: $db.gitHubConnections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$GitHubRepoPinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GitHubRepoPinsTable,
          GitHubRepoPin,
          $$GitHubRepoPinsTableFilterComposer,
          $$GitHubRepoPinsTableOrderingComposer,
          $$GitHubRepoPinsTableAnnotationComposer,
          $$GitHubRepoPinsTableCreateCompanionBuilder,
          $$GitHubRepoPinsTableUpdateCompanionBuilder,
          (GitHubRepoPin, $$GitHubRepoPinsTableReferences),
          GitHubRepoPin,
          PrefetchHooks Function({bool connectionId})
        > {
  $$GitHubRepoPinsTableTableManager(
    _$AppDatabase db,
    $GitHubRepoPinsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GitHubRepoPinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GitHubRepoPinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GitHubRepoPinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> connectionId = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> pinnedAt = const Value.absent(),
              }) => GitHubRepoPinsCompanion(
                id: id,
                connectionId: connectionId,
                owner: owner,
                name: name,
                pinnedAt: pinnedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int connectionId,
                required String owner,
                required String name,
                required DateTime pinnedAt,
              }) => GitHubRepoPinsCompanion.insert(
                id: id,
                connectionId: connectionId,
                owner: owner,
                name: name,
                pinnedAt: pinnedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GitHubRepoPinsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({connectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (connectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.connectionId,
                                referencedTable: $$GitHubRepoPinsTableReferences
                                    ._connectionIdTable(db),
                                referencedColumn:
                                    $$GitHubRepoPinsTableReferences
                                        ._connectionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GitHubRepoPinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GitHubRepoPinsTable,
      GitHubRepoPin,
      $$GitHubRepoPinsTableFilterComposer,
      $$GitHubRepoPinsTableOrderingComposer,
      $$GitHubRepoPinsTableAnnotationComposer,
      $$GitHubRepoPinsTableCreateCompanionBuilder,
      $$GitHubRepoPinsTableUpdateCompanionBuilder,
      (GitHubRepoPin, $$GitHubRepoPinsTableReferences),
      GitHubRepoPin,
      PrefetchHooks Function({bool connectionId})
    >;
typedef $$GitHubTokensTableCreateCompanionBuilder =
    GitHubTokensCompanion Function({
      Value<int> id,
      required String accountLogin,
      required String encryptedToken,
      required String tokenNonce,
      required DateTime updatedAt,
    });
typedef $$GitHubTokensTableUpdateCompanionBuilder =
    GitHubTokensCompanion Function({
      Value<int> id,
      Value<String> accountLogin,
      Value<String> encryptedToken,
      Value<String> tokenNonce,
      Value<DateTime> updatedAt,
    });

class $$GitHubTokensTableFilterComposer
    extends Composer<_$AppDatabase, $GitHubTokensTable> {
  $$GitHubTokensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountLogin => $composableBuilder(
    column: $table.accountLogin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedToken => $composableBuilder(
    column: $table.encryptedToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenNonce => $composableBuilder(
    column: $table.tokenNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GitHubTokensTableOrderingComposer
    extends Composer<_$AppDatabase, $GitHubTokensTable> {
  $$GitHubTokensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountLogin => $composableBuilder(
    column: $table.accountLogin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedToken => $composableBuilder(
    column: $table.encryptedToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenNonce => $composableBuilder(
    column: $table.tokenNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GitHubTokensTableAnnotationComposer
    extends Composer<_$AppDatabase, $GitHubTokensTable> {
  $$GitHubTokensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountLogin => $composableBuilder(
    column: $table.accountLogin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedToken => $composableBuilder(
    column: $table.encryptedToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokenNonce => $composableBuilder(
    column: $table.tokenNonce,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GitHubTokensTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GitHubTokensTable,
          GitHubToken,
          $$GitHubTokensTableFilterComposer,
          $$GitHubTokensTableOrderingComposer,
          $$GitHubTokensTableAnnotationComposer,
          $$GitHubTokensTableCreateCompanionBuilder,
          $$GitHubTokensTableUpdateCompanionBuilder,
          (
            GitHubToken,
            BaseReferences<_$AppDatabase, $GitHubTokensTable, GitHubToken>,
          ),
          GitHubToken,
          PrefetchHooks Function()
        > {
  $$GitHubTokensTableTableManager(_$AppDatabase db, $GitHubTokensTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GitHubTokensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GitHubTokensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GitHubTokensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountLogin = const Value.absent(),
                Value<String> encryptedToken = const Value.absent(),
                Value<String> tokenNonce = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GitHubTokensCompanion(
                id: id,
                accountLogin: accountLogin,
                encryptedToken: encryptedToken,
                tokenNonce: tokenNonce,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountLogin,
                required String encryptedToken,
                required String tokenNonce,
                required DateTime updatedAt,
              }) => GitHubTokensCompanion.insert(
                id: id,
                accountLogin: accountLogin,
                encryptedToken: encryptedToken,
                tokenNonce: tokenNonce,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GitHubTokensTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GitHubTokensTable,
      GitHubToken,
      $$GitHubTokensTableFilterComposer,
      $$GitHubTokensTableOrderingComposer,
      $$GitHubTokensTableAnnotationComposer,
      $$GitHubTokensTableCreateCompanionBuilder,
      $$GitHubTokensTableUpdateCompanionBuilder,
      (
        GitHubToken,
        BaseReferences<_$AppDatabase, $GitHubTokensTable, GitHubToken>,
      ),
      GitHubToken,
      PrefetchHooks Function()
    >;
typedef $$PortForwardConfigsTableCreateCompanionBuilder =
    PortForwardConfigsCompanion Function({
      Value<int> id,
      required int serverId,
      required String direction,
      required String kind,
      required String bindHost,
      required int bindPort,
      required String targetHost,
      required int targetPort,
      Value<bool> autoStart,
      Value<bool> keepAlive,
      Value<int?> sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$PortForwardConfigsTableUpdateCompanionBuilder =
    PortForwardConfigsCompanion Function({
      Value<int> id,
      Value<int> serverId,
      Value<String> direction,
      Value<String> kind,
      Value<String> bindHost,
      Value<int> bindPort,
      Value<String> targetHost,
      Value<int> targetPort,
      Value<bool> autoStart,
      Value<bool> keepAlive,
      Value<int?> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$PortForwardConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $PortForwardConfigsTable> {
  $$PortForwardConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bindHost => $composableBuilder(
    column: $table.bindHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bindPort => $composableBuilder(
    column: $table.bindPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetHost => $composableBuilder(
    column: $table.targetHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetPort => $composableBuilder(
    column: $table.targetPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoStart => $composableBuilder(
    column: $table.autoStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PortForwardConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $PortForwardConfigsTable> {
  $$PortForwardConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bindHost => $composableBuilder(
    column: $table.bindHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bindPort => $composableBuilder(
    column: $table.bindPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetHost => $composableBuilder(
    column: $table.targetHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetPort => $composableBuilder(
    column: $table.targetPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoStart => $composableBuilder(
    column: $table.autoStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PortForwardConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortForwardConfigsTable> {
  $$PortForwardConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get bindHost =>
      $composableBuilder(column: $table.bindHost, builder: (column) => column);

  GeneratedColumn<int> get bindPort =>
      $composableBuilder(column: $table.bindPort, builder: (column) => column);

  GeneratedColumn<String> get targetHost => $composableBuilder(
    column: $table.targetHost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetPort => $composableBuilder(
    column: $table.targetPort,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoStart =>
      $composableBuilder(column: $table.autoStart, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PortForwardConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortForwardConfigsTable,
          PortForwardConfig,
          $$PortForwardConfigsTableFilterComposer,
          $$PortForwardConfigsTableOrderingComposer,
          $$PortForwardConfigsTableAnnotationComposer,
          $$PortForwardConfigsTableCreateCompanionBuilder,
          $$PortForwardConfigsTableUpdateCompanionBuilder,
          (
            PortForwardConfig,
            BaseReferences<
              _$AppDatabase,
              $PortForwardConfigsTable,
              PortForwardConfig
            >,
          ),
          PortForwardConfig,
          PrefetchHooks Function()
        > {
  $$PortForwardConfigsTableTableManager(
    _$AppDatabase db,
    $PortForwardConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortForwardConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortForwardConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortForwardConfigsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> bindHost = const Value.absent(),
                Value<int> bindPort = const Value.absent(),
                Value<String> targetHost = const Value.absent(),
                Value<int> targetPort = const Value.absent(),
                Value<bool> autoStart = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PortForwardConfigsCompanion(
                id: id,
                serverId: serverId,
                direction: direction,
                kind: kind,
                bindHost: bindHost,
                bindPort: bindPort,
                targetHost: targetHost,
                targetPort: targetPort,
                autoStart: autoStart,
                keepAlive: keepAlive,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int serverId,
                required String direction,
                required String kind,
                required String bindHost,
                required int bindPort,
                required String targetHost,
                required int targetPort,
                Value<bool> autoStart = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => PortForwardConfigsCompanion.insert(
                id: id,
                serverId: serverId,
                direction: direction,
                kind: kind,
                bindHost: bindHost,
                bindPort: bindPort,
                targetHost: targetHost,
                targetPort: targetPort,
                autoStart: autoStart,
                keepAlive: keepAlive,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PortForwardConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortForwardConfigsTable,
      PortForwardConfig,
      $$PortForwardConfigsTableFilterComposer,
      $$PortForwardConfigsTableOrderingComposer,
      $$PortForwardConfigsTableAnnotationComposer,
      $$PortForwardConfigsTableCreateCompanionBuilder,
      $$PortForwardConfigsTableUpdateCompanionBuilder,
      (
        PortForwardConfig,
        BaseReferences<
          _$AppDatabase,
          $PortForwardConfigsTable,
          PortForwardConfig
        >,
      ),
      PortForwardConfig,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServersTableTableManager get servers =>
      $$ServersTableTableManager(_db, _db.servers);
  $$SavedCredentialsTableTableManager get savedCredentials =>
      $$SavedCredentialsTableTableManager(_db, _db.savedCredentials);
  $$VaultMetadataTableTableManager get vaultMetadata =>
      $$VaultMetadataTableTableManager(_db, _db.vaultMetadata);
  $$GitHubConnectionsTableTableManager get gitHubConnections =>
      $$GitHubConnectionsTableTableManager(_db, _db.gitHubConnections);
  $$GitHubRepoPinsTableTableManager get gitHubRepoPins =>
      $$GitHubRepoPinsTableTableManager(_db, _db.gitHubRepoPins);
  $$GitHubTokensTableTableManager get gitHubTokens =>
      $$GitHubTokensTableTableManager(_db, _db.gitHubTokens);
  $$PortForwardConfigsTableTableManager get portForwardConfigs =>
      $$PortForwardConfigsTableTableManager(_db, _db.portForwardConfigs);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
