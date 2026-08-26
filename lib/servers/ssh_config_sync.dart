import 'dart:io';

import 'ssh_key_preferences.dart';

/// A `Host` entry Conduit manages in the local OpenSSH client config.
class SshConfigEntry {
  const SshConfigEntry({
    required this.alias,
    required this.hostName,
    required this.user,
    required this.port,
    this.identityFile,
  });

  final String alias;
  final String hostName;
  final String user;
  final int port;

  /// Private key path as written to the config (`~/`-form preferred). Null
  /// for password logins: existing IdentityFile lines are then left alone.
  final String? identityFile;
}

/// A parsed `Host` block from the local config, for display and editing.
class SshConfigHost {
  const SshConfigHost({
    required this.alias,
    this.extraPatterns = const [],
    this.hostName,
    this.user,
    this.port,
    this.identityFile,
  });

  /// The first pattern on the `Host` line.
  final String alias;

  /// Remaining patterns of a multi-pattern `Host` line.
  final List<String> extraPatterns;

  final String? hostName;
  final String? user;
  final int? port;
  final String? identityFile;

  /// Whether [alias] is a wildcard pattern (e.g. `Host *` defaults) rather
  /// than a concrete host entry. Such blocks must not be edited with the
  /// managed-option merge.
  bool get isWildcard => alias.contains('*') || alias.contains('?');
}

/// Parses every `Host` block of [content]. `Match` blocks and options above
/// the first `Host` line are skipped; the first value wins for a repeated
/// option, matching OpenSSH.
List<SshConfigHost> parseSshConfigHosts(String content) {
  final lines = content.split('\n');
  final hosts = <SshConfigHost>[];
  var index = 0;
  while (index < lines.length) {
    final patterns = _hostPatterns(lines[index]);
    if (patterns == null) {
      index++;
      continue;
    }
    final end = _blockEnd(lines, index);
    String? hostName, user, identityFile;
    int? port;
    for (var i = index + 1; i < end; i++) {
      final key = _optionKey(lines[i]);
      if (key == null) continue;
      final value = _optionValue(lines[i]);
      if (value == null || value.isEmpty) continue;
      switch (key) {
        case 'hostname':
          hostName ??= value;
        case 'user':
          user ??= value;
        case 'port':
          port ??= int.tryParse(value);
        case 'identityfile':
          identityFile ??= value;
      }
    }
    hosts.add(
      SshConfigHost(
        alias: patterns.first,
        extraPatterns: patterns.sublist(1),
        hostName: hostName,
        user: user,
        port: port,
        identityFile: identityFile,
      ),
    );
    index = end;
  }
  return hosts;
}

/// Removes the `Host` block whose patterns include [alias], along with the
/// blank lines that followed it. Everything else is untouched; the input is
/// returned unchanged when no block matches.
String removeSshConfigHost(String existing, String alias) {
  final lines = existing.isEmpty ? <String>[] : existing.split('\n');
  final hadTrailingNewline = existing.endsWith('\n');
  if (hadTrailingNewline && lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  final start = _findBlock(lines, alias);
  if (start == null) return existing;
  var end = _blockEnd(lines, start);
  while (end < lines.length && lines[end].trim().isEmpty) {
    end++;
  }
  final output = [...lines.sublist(0, start), ...lines.sublist(end)];
  while (output.isNotEmpty && output.last.trim().isEmpty) {
    output.removeLast();
  }
  return output.isEmpty ? '' : '${output.join('\n')}\n';
}

/// Rewrites [existing] with its `Host` blocks in the order of
/// [orderedAliases] (first pattern of each block). Everything that is not a
/// `Host` block — leading options, `Match` blocks, comments between blocks —
/// keeps its position; blocks are separated by a single blank line. Aliases
/// not present are ignored and blocks not listed keep their relative order
/// after the listed ones.
String reorderSshConfigHosts(String existing, List<String> orderedAliases) {
  final lines = existing.isEmpty ? <String>[] : existing.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();

  // Segment into chunks: host blocks (with their trailing blank lines) and
  // fixed runs of anything else.
  final chunks = <(String? alias, List<String> lines)>[];
  var index = 0;
  var fixedStart = 0;
  while (index < lines.length) {
    final patterns = _hostPatterns(lines[index]);
    if (patterns == null) {
      index++;
      continue;
    }
    if (index > fixedStart) {
      chunks.add((null, lines.sublist(fixedStart, index)));
    }
    var end = _blockEnd(lines, index);
    while (end < lines.length && lines[end].trim().isEmpty) {
      end++;
    }
    chunks.add((patterns.first, lines.sublist(index, end)));
    index = end;
    fixedStart = end;
  }
  if (fixedStart < lines.length) {
    chunks.add((null, lines.sublist(fixedStart)));
  }

  final hostChunks = [
    for (final chunk in chunks)
      if (chunk.$1 != null) chunk,
  ];
  if (hostChunks.length < 2) return existing;
  final rank = {for (final (i, alias) in orderedAliases.indexed) alias: i};
  final sorted = [...hostChunks]
    ..sort((a, b) {
      final ra = rank[a.$1!] ?? orderedAliases.length + hostChunks.indexOf(a);
      final rb = rank[b.$1!] ?? orderedAliases.length + hostChunks.indexOf(b);
      return ra.compareTo(rb);
    });

  final output = <String>[];
  var next = 0;
  for (final chunk in chunks) {
    final block = chunk.$1 == null ? chunk.$2 : sorted[next++].$2;
    final trimmed = [...block];
    while (trimmed.isNotEmpty && trimmed.last.trim().isEmpty) {
      trimmed.removeLast();
    }
    if (trimmed.isEmpty) continue;
    if (output.isNotEmpty) output.add('');
    output.addAll(trimmed);
  }
  return output.isEmpty ? '' : '${output.join('\n')}\n';
}

/// Reads and parses the config at [configPath]; a missing file is an empty
/// list.
Future<List<SshConfigHost>> readSshConfigHosts({
  required String configPath,
}) async {
  final file = File(expandLocalPath(configPath, fallback: '~/.ssh/config'));
  if (!await file.exists()) return const [];
  return parseSshConfigHosts(await file.readAsString());
}

/// Rewrites the config file with its `Host` blocks in [orderedAliases]
/// order. Returns whether the file changed.
Future<bool> reorderSshConfigHostsFile(
  List<String> orderedAliases, {
  required String configPath,
}) async {
  final file = File(expandLocalPath(configPath, fallback: '~/.ssh/config'));
  if (!await file.exists()) return false;
  final existing = await file.readAsString();
  final updated = reorderSshConfigHosts(existing, orderedAliases);
  if (updated == existing) return false;
  await file.writeAsString(updated, flush: true);
  return true;
}

/// Removes the aliased `Host` block from the config file. Returns whether a
/// block was actually removed.
Future<bool> removeSshConfigHostFile(
  String alias, {
  required String configPath,
}) async {
  final file = File(expandLocalPath(configPath, fallback: '~/.ssh/config'));
  if (!await file.exists()) return false;
  final existing = await file.readAsString();
  final updated = removeSshConfigHost(existing, alias);
  if (updated == existing) return false;
  await file.writeAsString(updated, flush: true);
  return true;
}

/// Derives a config alias from a server name: whitespace becomes `-`,
/// characters OpenSSH treats specially in patterns are dropped.
String sshConfigAliasFor(String serverName) {
  final alias = serverName
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[*?!#"\x27]'), '');
  return alias.isEmpty ? 'server' : alias;
}

/// Rewrites a path under the home directory into `~/...` so the config stays
/// portable across accounts that share it.
String tildePath(String path) {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.isNotEmpty && path.startsWith('$home/')) {
    return '~${path.substring(home.length)}';
  }
  return path;
}

/// The options Conduit owns inside a managed block, in write order.
const _managedOptions = [
  'hostname',
  'user',
  'port',
  'identityfile',
  'identitiesonly',
];

/// Merges [entry] into [existing] config text.
///
/// A block whose `Host` line lists the alias (case-insensitively) is updated
/// in place: the managed options are replaced (every `IdentityFile` line is
/// collapsed into the new one), other options and comments are kept, and the
/// block's own indentation is reused. Otherwise a new block is appended.
String mergeSshConfig(String existing, SshConfigEntry entry) {
  final lines = existing.isEmpty ? <String>[] : existing.split('\n');
  // Drop a trailing empty element produced by a final newline so the text
  // can be reassembled without doubling it.
  final hadTrailingNewline = existing.endsWith('\n');
  if (hadTrailingNewline && lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }

  final blockStart = _findBlock(lines, entry.alias);
  final managed = <String, String>{
    'hostname': 'HostName ${entry.hostName}',
    'user': 'User ${entry.user}',
    'port': 'Port ${entry.port}',
    if (entry.identityFile != null) ...{
      'identityfile': 'IdentityFile ${entry.identityFile}',
      'identitiesonly': 'IdentitiesOnly yes',
    },
  };
  final order = [
    for (final key in _managedOptions)
      if (managed.containsKey(key)) key,
  ];

  if (blockStart == null) {
    final block = <String>[
      'Host ${entry.alias}',
      for (final key in order) '  ${managed[key]}',
    ];
    final output = [...lines];
    if (output.isNotEmpty && output.last.trim().isNotEmpty) output.add('');
    output.addAll(block);
    return '${output.join('\n')}\n';
  }

  final blockEnd = _blockEnd(lines, blockStart);
  final indent = _blockIndent(lines, blockStart, blockEnd);
  final seen = <String>{};
  final rebuilt = <String>[lines[blockStart]];
  for (var index = blockStart + 1; index < blockEnd; index++) {
    final line = lines[index];
    final key = _optionKey(line);
    if (key != null && managed.containsKey(key)) {
      if (seen.add(key)) rebuilt.add('$indent${managed[key]}');
      continue; // duplicates (e.g. several IdentityFile lines) are dropped
    }
    rebuilt.add(line);
  }
  // Options the block lacked go right after the Host line, keeping the
  // managed order.
  final missing = [
    for (final key in order)
      if (!seen.contains(key)) '$indent${managed[key]}',
  ];
  rebuilt.insertAll(1, missing);

  final output = [
    ...lines.sublist(0, blockStart),
    ...rebuilt,
    ...lines.sublist(blockEnd),
  ];
  return '${output.join('\n')}${hadTrailingNewline ? '\n' : ''}';
}

/// Reads the config at [configPath] (creating it, mode 600, if absent),
/// merges [entry], and writes it back. Returns the resolved path.
Future<String> syncSshConfigFile(
  SshConfigEntry entry, {
  required String configPath,
}) async {
  final file = File(expandLocalPath(configPath, fallback: '~/.ssh/config'));
  await file.parent.create(recursive: true);
  final existing = await file.exists() ? await file.readAsString() : '';
  final merged = mergeSshConfig(existing, entry);
  if (merged != existing) await file.writeAsString(merged, flush: true);
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', file.path]);
  }
  return file.path;
}

int? _findBlock(List<String> lines, String alias) {
  for (var index = 0; index < lines.length; index++) {
    final patterns = _hostPatterns(lines[index]);
    if (patterns == null) continue;
    if (patterns.any((p) => p.toLowerCase() == alias.toLowerCase())) {
      return index;
    }
  }
  return null;
}

/// The patterns of a `Host` line, or null for any other line.
List<String>? _hostPatterns(String line) {
  final match = RegExp(
    r'^\s*host(?:\s+|\s*=\s*)(.+)$',
    caseSensitive: false,
  ).firstMatch(_stripComment(line));
  if (match == null) return null;
  return match.group(1)!.trim().split(RegExp(r'\s+'));
}

bool _startsBlock(String line) =>
    RegExp(r'^\s*(host|match)\b', caseSensitive: false).hasMatch(line);

int _blockEnd(List<String> lines, int start) {
  for (var index = start + 1; index < lines.length; index++) {
    if (_startsBlock(lines[index])) return index;
  }
  return lines.length;
}

String _blockIndent(List<String> lines, int start, int end) {
  for (var index = start + 1; index < end; index++) {
    if (_optionKey(lines[index]) != null) {
      return RegExp(r'^\s*').firstMatch(lines[index])!.group(0)!;
    }
  }
  return '  ';
}

String? _optionKey(String line) {
  final stripped = _stripComment(line).trim();
  if (stripped.isEmpty) return null;
  final match = RegExp(r'^([A-Za-z][A-Za-z0-9]*)(?:\s|=)').firstMatch(stripped);
  return match?.group(1)!.toLowerCase();
}

/// The value of an option line, quotes stripped, or null for non-options.
String? _optionValue(String line) {
  final stripped = _stripComment(line).trim();
  final match = RegExp(
    r'^[A-Za-z][A-Za-z0-9]*(?:\s+|\s*=\s*)(.*)$',
  ).firstMatch(stripped);
  final value = match?.group(1)?.trim();
  return value?.replaceAll('"', '');
}

String _stripComment(String line) {
  final hash = line.indexOf('#');
  return hash == -1 ? line : line.substring(0, hash);
}
