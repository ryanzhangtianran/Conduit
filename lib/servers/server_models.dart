import 'dart:convert';

enum CredentialType { password, privateKey }

class ServerCredential {
  const ServerCredential.password(this.password)
    : type = CredentialType.password,
      privateKey = null,
      keyPassphrase = null;

  const ServerCredential.privateKey({
    required this.privateKey,
    this.keyPassphrase,
  }) : type = CredentialType.privateKey,
       password = null;

  final CredentialType type;
  final String? password;
  final String? privateKey;
  final String? keyPassphrase;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'password': password,
    'privateKey': privateKey,
    'keyPassphrase': keyPassphrase,
  };

  String encode() => jsonEncode(toJson());

  factory ServerCredential.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    final type = CredentialType.values.byName(json['type'] as String);
    return switch (type) {
      CredentialType.password => ServerCredential.password(
        json['password'] as String,
      ),
      CredentialType.privateKey => ServerCredential.privateKey(
        privateKey: json['privateKey'] as String,
        keyPassphrase: json['keyPassphrase'] as String?,
      ),
    };
  }
}

class ServerDraft {
  const ServerDraft({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.credential,
    this.credentialId,
    this.credentialName,
    this.collectStats = true,
    this.collectSystemInfo = true,
    this.proxy,
    this.jumpHostServerId,
    this.environment = const {},
    this.tags = const [],
    this.connectionType = ServerConnectionType.ssh,
  });

  final String name;
  final String host;
  final int port;
  final String username;

  /// A new credential to save, or an existing [credentialId] to reuse.
  final ServerCredential? credential;
  final int? credentialId;
  final String? credentialName;
  final bool collectStats;
  final bool collectSystemInfo;

  /// Optional per-server HTTP CONNECT / SOCKS5 proxy. During an edit, a null
  /// [ServerProxy.password] keeps the stored proxy password unchanged.
  final ServerProxy? proxy;

  /// Another saved SSH server used as the first hop to reach this server.
  ///
  /// The referenced server may itself use a jump host, allowing chains such
  /// as A -> B -> C. Credentials are always taken from the referenced server.
  final int? jumpHostServerId;

  /// Environment variables exported into terminals opened on this server.
  final Map<String, String> environment;

  /// Free-form labels shown on the server card and usable as filters.
  final List<String> tags;

  /// Transport used to reach this server. Persisted as its name in the
  /// `connection_type` column; only SSH is supported.
  final ServerConnectionType connectionType;
}

/// JSON-encodes [environment] for storage, or null when it is empty.
String? encodeEnvironmentMap(Map<String, String> environment) =>
    environment.isEmpty ? null : jsonEncode(environment);

/// Decodes a stored environment JSON column.
Map<String, String> decodeEnvironmentMap(String? value) {
  if (value == null || value.isEmpty) return const {};
  final decoded = jsonDecode(value);
  if (decoded is! Map<String, dynamic>) return const {};
  return decoded.map((key, item) => MapEntry(key, item.toString()));
}

/// JSON-encodes [values] for storage, or null when it is empty.
String? encodeStringList(List<String> values) =>
    values.isEmpty ? null : jsonEncode(values);

/// Decodes a stored JSON string-list column (tags).
List<String> decodeStringList(String? value) {
  if (value == null || value.isEmpty) return const [];
  final decoded = jsonDecode(value);
  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is String && item.isNotEmpty) item,
  ];
}

enum ServerConnectionType { ssh }

enum ServerProxyType { none, http, socks5 }

/// A per-server HTTP CONNECT or SOCKS5 proxy used to reach the SSH host.
///
/// The proxy establishes the underlying TCP connection, so DNS resolution
/// happens at the proxy rather than on this device.
class ServerProxy {
  const ServerProxy({
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  final ServerProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;
}

enum SessionStatus { connecting, connected, failed, closed }

/// Raised when an operation needs the server's retained SSH connection.
class ServerConnectionRequiredException implements Exception {
  const ServerConnectionRequiredException();

  @override
  String toString() => 'Connect to this server before running an operation.';
}

/// Raised when a configured jump host is not connected yet.
class JumpHostConnectionRequiredException implements Exception {
  const JumpHostConnectionRequiredException(this.jumpHostServerId);

  final int jumpHostServerId;

  @override
  String toString() =>
      'Connect to jump host $jumpHostServerId before connecting this server.';
}

class ServerGpuStats {
  const ServerGpuStats({
    required this.index,
    required this.name,
    this.utilizationPercent,
    this.memoryUsedKb,
    this.memoryTotalKb,
    this.temperatureC,
  });

  final int index;
  final String name;
  final double? utilizationPercent;
  final int? memoryUsedKb;
  final int? memoryTotalKb;
  final double? temperatureC;
}

class ServerStats {
  const ServerStats({
    required this.collectorId,
    required this.updatedAt,
    this.loadAverage,
    this.loadAverage5,
    this.loadAverage15,
    this.cpuCount,
    this.memoryTotalKb,
    this.memoryAvailableKb,
    this.swapTotalKb,
    this.swapFreeKb,
    this.diskTotalKb,
    this.diskAvailableKb,
    this.uptime,
    this.gpus = const [],
  });

  final String collectorId;
  final DateTime updatedAt;
  final double? loadAverage;
  final double? loadAverage5;
  final double? loadAverage15;
  final int? cpuCount;
  final int? memoryTotalKb;
  final int? memoryAvailableKb;
  final int? swapTotalKb;
  final int? swapFreeKb;
  final int? diskTotalKb;
  final int? diskAvailableKb;
  final Duration? uptime;
  final List<ServerGpuStats> gpus;
}

class ServerProcess {
  const ServerProcess({
    required this.pid,
    required this.user,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.rssKb,
    required this.command,
  });

  final int pid;
  final String user;
  final double cpuPercent;
  final double memoryPercent;
  final int rssKb;
  final String command;
}

class ServerSystemInfo {
  const ServerSystemInfo({this.distribution, this.kernel});

  final String? distribution;
  final String? kernel;
}

class SshSessionInfo {
  const SshSessionInfo({
    required this.serverId,
    required this.serverName,
    required this.connectedAt,
    required this.status,
    this.error,
    this.stats,
    this.systemInfo,
    this.networkLatency,
    this.authMethod,
  });

  final int serverId;
  final String serverName;
  final DateTime connectedAt;
  final SessionStatus status;
  final String? error;
  final ServerStats? stats;
  final ServerSystemInfo? systemInfo;

  /// SSH round-trip latency measured on the live session, shown on cards.
  final Duration? networkLatency;

  /// Credential this session was opened with, so the UI can say whether a
  /// server signs in with a key or a password.
  final CredentialType? authMethod;

  /// [clearError] drops a stale [error] when the session becomes healthy
  /// again; passing [error] alone can only replace it.
  SshSessionInfo copyWith({
    SessionStatus? status,
    String? error,
    bool clearError = false,
    ServerStats? stats,
    ServerSystemInfo? systemInfo,
    Duration? networkLatency,
    CredentialType? authMethod,
  }) => SshSessionInfo(
    serverId: serverId,
    serverName: serverName,
    connectedAt: connectedAt,
    status: status ?? this.status,
    error: clearError ? null : error ?? this.error,
    stats: stats ?? this.stats,
    systemInfo: systemInfo ?? this.systemInfo,
    networkLatency: networkLatency ?? this.networkLatency,
    authMethod: authMethod ?? this.authMethod,
  );
}

class HostKeyPrompt {
  const HostKeyPrompt({
    required this.algorithm,
    required this.fingerprint,
    this.replacesExisting = false,
  });

  final String algorithm;
  final String fingerprint;
  final bool replacesExisting;
}
