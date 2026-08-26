import 'dart:io';

import 'server_models.dart';

/// A parsed connection from a Conduit export or a third-party client,
/// ready for review before import.
class ImportedConnection {
  const ImportedConnection({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.connectionType,
    this.credential,
    this.proxy,
    this.sourceSyncId,
    this.jumpHostSyncId,
    this.environment = const {},
    this.tags = const [],
    this.source = 'Conduit',
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final ServerConnectionType connectionType;
  final String? sourceSyncId;

  /// Null when the source was redacted or the secret could not be decrypted;
  /// the user assigns a credential after import.
  final ServerCredential? credential;

  /// Proxy with password already decrypted from the secrets block.
  final ServerProxy? proxy;

  /// Sync id of another exported server used as this connection's jump host.
  final String? jumpHostSyncId;

  final Map<String, String> environment;
  final List<String> tags;

  /// Origin label shown in the import preview, e.g. "OpenSSH config".
  final String source;
}

/// Parses connection data produced by another SSH client.
abstract interface class ConnectionImportAdapter {
  String get name;

  /// Whether [content] looks like this client's format. Must not throw.
  bool supports(String content);

  List<ImportedConnection> parse(String content, {String? baseDirectory});
}

/// Returns the adapter matching [content], or null when nothing does.
ConnectionImportAdapter? detectThirdPartyAdapter(String content) {
  final adapter = OpenSshConfigAdapter();
  return adapter.supports(content) ? adapter : null;
}

/// OpenSSH `~/.ssh/config`-style files: `Host` blocks with indented options.
///
/// OpenSSH applies the first value found for each option while walking matching
/// `Host` blocks in file order. The parser mirrors that behavior for concrete
/// host aliases, so defaults from `Host *` (including `IdentityFile`) are
/// retained when a later host block does not override them.
class OpenSshConfigAdapter implements ConnectionImportAdapter {
  @override
  String get name => 'OpenSSH config';

  @override
  bool supports(String content) => content.split('\n').any((rawLine) {
    final line = rawLine.trim();
    return line.isNotEmpty &&
        !line.startsWith('#') &&
        RegExp(r'^host(?:\s+|=)\S', caseSensitive: false).hasMatch(line);
  });

  @override
  List<ImportedConnection> parse(String content, {String? baseDirectory}) {
    final document = _parseOpenSshConfig(content, baseDirectory: baseDirectory);
    final aliases = <String>[];
    for (final block in document.blocks) {
      for (final pattern in block.patterns) {
        if (_isConcreteHostPattern(pattern) && !aliases.contains(pattern)) {
          aliases.add(pattern);
          break;
        }
      }
    }

    final connections = <ImportedConnection>[];
    for (final alias in aliases) {
      final options = <String, String>{...document.globalOptions};
      for (final block in document.blocks) {
        if (!_hostBlockMatches(block.patterns, alias)) continue;
        for (final entry in block.options.entries) {
          options.putIfAbsent(entry.key, () => entry.value);
        }
      }

      final host = _unquoteOpenSshValue(options['hostname']) ?? alias;
      final user = _unquoteOpenSshValue(options['user']) ?? '';
      final port =
          int.tryParse(_unquoteOpenSshValue(options['port']) ?? '') ?? 22;
      final identityFile = _unquoteOpenSshValue(options['identityfile']) ?? '';

      connections.add(
        ImportedConnection(
          name: alias,
          host: host,
          port: port,
          username: user,
          credential: _readKeyCredential(
            identityFile,
            baseDirectory,
            host: alias,
            username: user,
          ),
          connectionType: ServerConnectionType.ssh,
          source: name,
        ),
      );
    }
    return connections;
  }
}

class _OpenSshConfigDocument {
  const _OpenSshConfigDocument({
    required this.globalOptions,
    required this.blocks,
  });

  final Map<String, String> globalOptions;
  final List<_OpenSshConfigBlock> blocks;
}

class _OpenSshConfigBlock {
  _OpenSshConfigBlock(this.patterns);

  final List<String> patterns;
  final Map<String, String> options = {};
}

// ---------------------------------------------------------------------------
// Shared helpers.
// ---------------------------------------------------------------------------

_OpenSshConfigDocument _parseOpenSshConfig(
  String content, {
  String? baseDirectory,
  Set<String>? includedFiles,
}) {
  final globalOptions = <String, String>{};
  final blocks = <_OpenSshConfigBlock>[];
  final seenIncludes = includedFiles ?? <String>{};
  _OpenSshConfigBlock? current;

  for (final rawLine in content.split('\n')) {
    final line = _stripOpenSshComment(rawLine.trim());
    if (line.isEmpty) continue;
    final match = RegExp(
      r'^([A-Za-z][A-Za-z0-9]*)\s*(?:=\s*|\s+)(.*)$',
    ).firstMatch(line);
    if (match == null) continue;

    final key = match.group(1)!.toLowerCase();
    final value = match.group(2)!.trim();
    if (key == 'host') {
      current = _OpenSshConfigBlock(
        value
            .split(RegExp(r'\s+'))
            .map(_unquoteOpenSshValue)
            .whereType<String>()
            .toList(),
      );
      blocks.add(current);
      continue;
    }
    if (key == 'include') {
      for (final includePath in _openSshIncludePaths(value, baseDirectory)) {
        if (!seenIncludes.add(includePath)) continue;
        try {
          final included = _parseOpenSshConfig(
            File(includePath).readAsStringSync(),
            baseDirectory: File(includePath).parent.path,
            includedFiles: seenIncludes,
          );
          globalOptions.addAll(included.globalOptions);
          blocks.addAll(included.blocks);
        } catch (_) {
          // Includes are optional in OpenSSH; an unavailable one should not
          // prevent the rest of the selected config from being imported.
        }
      }
      continue;
    }

    final normalizedValue = _unquoteOpenSshValue(value);
    if (normalizedValue == null) continue;
    if (current == null) {
      globalOptions.putIfAbsent(key, () => normalizedValue);
    } else {
      current.options.putIfAbsent(key, () => normalizedValue);
    }
  }

  return _OpenSshConfigDocument(globalOptions: globalOptions, blocks: blocks);
}

String _stripOpenSshComment(String line) {
  var quoted = false;
  var escaped = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character == '\\') {
      escaped = true;
    } else if (character == '"') {
      quoted = !quoted;
    } else if (character == '#' && !quoted) {
      return line.substring(0, index).trimRight();
    }
  }
  return line;
}

String? _unquoteOpenSshValue(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed.isEmpty ? null : trimmed;
}

bool _isConcreteHostPattern(String pattern) =>
    pattern.isNotEmpty &&
    !pattern.startsWith('!') &&
    !pattern.contains('*') &&
    !pattern.contains('?');

bool _hostBlockMatches(List<String> patterns, String host) {
  var matchesPositive = false;
  for (final pattern in patterns) {
    final negated = pattern.startsWith('!');
    final candidate = negated ? pattern.substring(1) : pattern;
    if (!_globMatches(candidate, host)) continue;
    if (negated) return false;
    matchesPositive = true;
  }
  return matchesPositive ||
      patterns.every((pattern) => pattern.startsWith('!'));
}

bool _globMatches(String pattern, String value) {
  final escaped = StringBuffer('^');
  for (var index = 0; index < pattern.length; index++) {
    final character = pattern[index];
    if (character == '*') {
      escaped.write('.*');
    } else if (character == '?') {
      escaped.write('.');
    } else {
      escaped.write(RegExp.escape(character));
    }
  }
  escaped.write(r'$');
  return RegExp(escaped.toString(), caseSensitive: false).hasMatch(value);
}

List<String> _openSshIncludePaths(String value, String? baseDirectory) {
  final paths = <String>[];
  for (final token in value.split(RegExp(r'\s+'))) {
    final resolved = _resolvePath(token, baseDirectory);
    if (resolved == null) continue;
    if (!RegExp(r'[*?\[]').hasMatch(resolved)) {
      paths.add(resolved);
      continue;
    }
    final directory = File(resolved).parent;
    if (!directory.existsSync()) continue;
    final filePattern = resolved.substring(directory.path.length + 1);
    final matcher = RegExp(
      '^${filePattern.split('').map((character) {
        if (character == '*') return '.*';
        if (character == '?') return '.';
        return RegExp.escape(character);
      }).join()}\$',
      caseSensitive: false,
    );
    for (final entity in directory.listSync()) {
      final name = entity.path.substring(entity.path.lastIndexOf('/') + 1);
      if (matcher.hasMatch(name)) paths.add(entity.path);
    }
  }
  return paths;
}

/// Reads a private-key file into a credential, or null when the path is
/// empty, points at a file outside this machine, or is unreadable.
ServerCredential? _readKeyCredential(
  String path,
  String? baseDirectory, {
  String? host,
  String? username,
}) {
  if (path.isEmpty) return null;
  final resolved = _resolvePath(
    path,
    baseDirectory,
    host: host,
    username: username,
  );
  if (resolved == null) return null;
  try {
    final content = File(resolved).readAsStringSync();
    if (content.trim().isEmpty) return null;
    return ServerCredential.privateKey(privateKey: content);
  } catch (_) {
    return null;
  }
}

/// Resolves a key path: `~/` expands to the home directory, relative paths
/// resolve against [baseDirectory] (the folder of the imported file), and
/// foreign Windows paths (e.g. `C:\...` on macOS) yield null.
String? _resolvePath(
  String path,
  String? baseDirectory, {
  String? host,
  String? username,
}) {
  var expanded = path.trim();
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(expanded)) return null;
  final home = Platform.environment['HOME'];
  expanded = expanded
      .replaceAll('%d', home ?? '')
      .replaceAll('%h', host ?? '')
      .replaceAll('%r', username ?? '');
  if (expanded.contains('%')) return null;
  if (expanded.startsWith('~/')) {
    if (home == null) return null;
    expanded = '$home/${expanded.substring(2)}';
  } else if (!expanded.startsWith('/') &&
      !expanded.startsWith('\\') &&
      baseDirectory != null) {
    expanded = '$baseDirectory/$expanded';
  }
  return expanded;
}
