import 'dart:convert';

import 'package:toml/toml.dart';
import 'package:yaml/yaml.dart';

/// Supported structured document kinds for format/lint in the file editor.
enum StructuredDocumentKind { json, yaml, toml }

/// A lint diagnostic produced by [lintStructuredDocument].
class StructuredDocumentIssue {
  const StructuredDocumentIssue({required this.line, required this.message});

  /// Zero-based line index.
  final int line;
  final String message;
}

/// Detects JSON / YAML / TOML from a file name extension.
StructuredDocumentKind? structuredKindForFileName(String name) {
  final extension = _extensionOf(name);
  return switch (extension) {
    'json' || 'jsonc' => StructuredDocumentKind.json,
    'yaml' || 'yml' => StructuredDocumentKind.yaml,
    'toml' => StructuredDocumentKind.toml,
    _ => null,
  };
}

/// Formats [text] for [kind]. Throws when the document is invalid.
String formatStructuredDocument(String text, StructuredDocumentKind kind) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return text;

  return switch (kind) {
    StructuredDocumentKind.json => _formatJson(text),
    StructuredDocumentKind.yaml => _formatYaml(text),
    StructuredDocumentKind.toml => _formatToml(text),
  };
}

/// Returns parse diagnostics for [text]. Empty when the document is valid.
List<StructuredDocumentIssue> lintStructuredDocument(
  String text,
  StructuredDocumentKind kind,
) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  return switch (kind) {
    StructuredDocumentKind.json => _lintJson(text),
    StructuredDocumentKind.yaml => _lintYaml(text),
    StructuredDocumentKind.toml => _lintToml(text),
  };
}

String _formatJson(String text) {
  // Validate first, then format the original tokens. Decoding and encoding
  // through Dart objects loses duplicate keys and normalizes number/string
  // representations, which is unsafe for a file editor formatter.
  jsonDecode(text);
  final tokens = _jsonTokens(text);
  final buffer = StringBuffer();
  var indent = 0;

  for (var index = 0; index < tokens.length; index++) {
    final token = tokens[index];
    final previous = index == 0 ? null : tokens[index - 1];
    final next = index + 1 == tokens.length ? null : tokens[index + 1];
    switch (token) {
      case '{' || '[':
        buffer.write(token);
        indent++;
        if (next != '}' && next != ']') {
          buffer
            ..writeln()
            ..write('  ' * indent);
        }
      case '}' || ']':
        indent--;
        if (previous != '{' && previous != '[') {
          buffer
            ..writeln()
            ..write('  ' * indent);
        }
        buffer.write(token);
      case ',':
        buffer
          ..write(',')
          ..writeln()
          ..write('  ' * indent);
      case ':':
        buffer.write(': ');
      default:
        buffer.write(token);
    }
  }
  return '${buffer.toString().trimRight()}\n';
}

/// Splits valid JSON into its original syntax tokens without changing values.
List<String> _jsonTokens(String text) {
  final tokens = <String>[];
  var index = 0;
  while (index < text.length) {
    final codeUnit = text.codeUnitAt(index);
    if (_isJsonWhitespace(codeUnit)) {
      index++;
      continue;
    }
    if (codeUnit == 0x22) {
      final start = index++;
      while (index < text.length) {
        final current = text.codeUnitAt(index++);
        if (current == 0x5C) {
          index++;
        } else if (current == 0x22) {
          break;
        }
      }
      tokens.add(text.substring(start, index));
      continue;
    }
    if ('{}[],:'.contains(String.fromCharCode(codeUnit))) {
      tokens.add(String.fromCharCode(codeUnit));
      index++;
      continue;
    }
    final start = index;
    while (index < text.length) {
      final current = text.codeUnitAt(index);
      if (_isJsonWhitespace(current) ||
          '{}[],:'.contains(String.fromCharCode(current))) {
        break;
      }
      index++;
    }
    tokens.add(text.substring(start, index));
  }
  return tokens;
}

bool _isJsonWhitespace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == 0x0A ||
    codeUnit == 0x0D;

String _formatYaml(String text) {
  final node = loadYaml(text);
  final buffer = StringBuffer();
  _writeYaml(buffer, _plainYaml(node), 0, isRoot: true);
  final result = buffer.toString();
  if (result.isEmpty) return '\n';
  return result.endsWith('\n') ? result : '$result\n';
}

String _formatToml(String text) {
  final document = TomlDocument.parse(text);
  final map = document.toMap();
  return '${TomlDocument.fromMap(map)}\n';
}

List<StructuredDocumentIssue> _lintJson(String text) {
  try {
    jsonDecode(text);
    return const [];
  } on FormatException catch (error) {
    return [
      StructuredDocumentIssue(
        line: _lineFromOffset(text, error.offset),
        message: error.message,
      ),
    ];
  }
}

List<StructuredDocumentIssue> _lintYaml(String text) {
  try {
    loadYaml(text);
    return const [];
  } on YamlException catch (error) {
    final span = error.span;
    final line = span == null ? 0 : span.start.line;
    return [StructuredDocumentIssue(line: line, message: error.message)];
  }
}

List<StructuredDocumentIssue> _lintToml(String text) {
  try {
    TomlDocument.parse(text);
    return const [];
  } on TomlParserException catch (error) {
    return [
      StructuredDocumentIssue(
        line: (error.line - 1).clamp(0, 1 << 30),
        message: error.message,
      ),
    ];
  } on TomlException catch (error) {
    return [StructuredDocumentIssue(line: 0, message: error.message)];
  }
}

int _lineFromOffset(String text, int? offset) {
  if (offset == null || offset <= 0) return 0;
  final end = offset.clamp(0, text.length);
  var line = 0;
  for (var i = 0; i < end; i++) {
    if (text.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

Object? _plainYaml(Object? value) {
  if (value is YamlMap) {
    return {
      for (final entry in value.entries)
        _plainYaml(entry.key): _plainYaml(entry.value),
    };
  }
  if (value is YamlList) {
    return [for (final item in value) _plainYaml(item)];
  }
  if (value is YamlScalar) return value.value;
  return value;
}

void _writeYaml(
  StringBuffer buffer,
  Object? value,
  int indent, {
  bool isRoot = false,
}) {
  if (value is Map) {
    if (value.isEmpty) {
      buffer.write('{}');
      return;
    }
    var first = true;
    for (final entry in value.entries) {
      if (!first) buffer.writeln();
      first = false;
      if (!isRoot || indent > 0) {
        // Non-root maps are always indented at their indent level.
      }
      buffer
        ..write('  ' * indent)
        ..write(_yamlKey(entry.key))
        ..write(':');
      final child = entry.value;
      if (child is Map) {
        if (child.isEmpty) {
          buffer.write(' {}');
        } else {
          buffer.writeln();
          _writeYaml(buffer, child, indent + 1);
        }
      } else if (child is List) {
        if (child.isEmpty) {
          buffer.write(' []');
        } else {
          buffer.writeln();
          _writeYaml(buffer, child, indent + 1);
        }
      } else {
        buffer.write(' ');
        _writeYaml(buffer, child, indent);
      }
    }
    return;
  }

  if (value is List) {
    if (value.isEmpty) {
      buffer.write('[]');
      return;
    }
    for (var i = 0; i < value.length; i++) {
      if (i > 0) buffer.writeln();
      buffer
        ..write('  ' * indent)
        ..write('-');
      final child = value[i];
      if (child is Map) {
        if (child.isEmpty) {
          buffer.write(' {}');
        } else {
          buffer.writeln();
          _writeYaml(buffer, child, indent + 1);
        }
      } else if (child is List) {
        if (child.isEmpty) {
          buffer.write(' []');
        } else {
          buffer.writeln();
          _writeYaml(buffer, child, indent + 1);
        }
      } else {
        buffer.write(' ');
        _writeYaml(buffer, child, indent);
      }
    }
    return;
  }

  buffer.write(_yamlScalar(value));
}

String _yamlKey(Object? key) {
  if (key is String) {
    if (_needsYamlQuotes(key)) return jsonEncode(key);
    return key;
  }
  return key.toString();
}

String _yamlScalar(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.toString();
  if (value is String) {
    if (value.isEmpty) return "''";
    if (_needsYamlQuotes(value)) return jsonEncode(value);
    return value;
  }
  return jsonEncode(value.toString());
}

bool _needsYamlQuotes(String value) {
  if (value.isEmpty) return true;
  if (RegExp(r'^[\s]|[\s]$').hasMatch(value)) return true;
  if (RegExp(r'[:#\[\]\{\},&\*?|>!%@`]').hasMatch(value)) return true;
  if (RegExp(
    r'^(true|false|null|yes|no|on|off)$',
    caseSensitive: false,
  ).hasMatch(value)) {
    return true;
  }
  if (num.tryParse(value) != null) return true;
  return false;
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}
