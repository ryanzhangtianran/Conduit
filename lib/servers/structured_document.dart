import 'dart:convert';

import 'package:toml/toml.dart';
import 'package:yaml/yaml.dart';

import 'package:conduit/shared/formatters.dart';

/// Format/lint support for structured documents in the file editor.
///
/// Every kind can be linted. Only JSON and JSONC can be formatted: the JSON
/// formatter re-indents the original tokens without decoding, so duplicate
/// keys, number spellings and escapes survive, and JSONC comments are kept
/// (each on its own line). YAML and TOML are lint-only on purpose: the only
/// way to format them with the available parsers is to round-trip through Dart
/// objects, which drops comments, anchors, quoting and key order, and an
/// editor must not do that silently.
enum StructuredDocumentKind { json, jsonc, yaml, toml }

/// A lint diagnostic produced by [lintStructuredDocument].
class StructuredDocumentIssue {
  const StructuredDocumentIssue({required this.line, required this.message});

  /// Zero-based line index.
  final int line;
  final String message;
}

/// Detects JSON / JSONC / YAML / TOML from a file name extension.
StructuredDocumentKind? structuredKindForFileName(String name) {
  return switch (extensionOf(name)) {
    'json' => StructuredDocumentKind.json,
    'jsonc' => StructuredDocumentKind.jsonc,
    'yaml' || 'yml' => StructuredDocumentKind.yaml,
    'toml' => StructuredDocumentKind.toml,
    _ => null,
  };
}

/// Whether [formatStructuredDocument] supports [kind]. See the library note
/// for why YAML and TOML are lint-only.
bool canFormatStructuredDocument(StructuredDocumentKind kind) => switch (kind) {
  StructuredDocumentKind.json || StructuredDocumentKind.jsonc => true,
  StructuredDocumentKind.yaml || StructuredDocumentKind.toml => false,
};

/// Formats [text] for [kind]. Throws [FormatException] when the document is
/// invalid and [UnsupportedError] when [kind] cannot be formatted.
String formatStructuredDocument(String text, StructuredDocumentKind kind) {
  if (!canFormatStructuredDocument(kind)) {
    throw UnsupportedError('${kind.name.toUpperCase()} is lint-only.');
  }
  final trimmed = text.trim();
  if (trimmed.isEmpty) return text;
  return _formatJson(text, allowComments: kind == StructuredDocumentKind.jsonc);
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
    StructuredDocumentKind.jsonc => _lintJson(stripJsonComments(text)),
    StructuredDocumentKind.yaml => _lintYaml(text),
    StructuredDocumentKind.toml => _lintToml(text),
  };
}

/// Replaces `//` and `/* */` comments with spaces, keeping newlines so every
/// offset and line in the result matches [text]. Comment markers inside
/// strings are left alone.
String stripJsonComments(String text) {
  final out = StringBuffer();
  var index = 0;
  while (index < text.length) {
    final unit = text.codeUnitAt(index);
    if (unit == 0x22) {
      final end = _skipJsonString(text, index);
      out.write(text.substring(index, end));
      index = end;
      continue;
    }
    if (unit == 0x2F && index + 1 < text.length) {
      final next = text.codeUnitAt(index + 1);
      if (next == 0x2F) {
        while (index < text.length && text.codeUnitAt(index) != 0x0A) {
          out.write(' ');
          index++;
        }
        continue;
      }
      if (next == 0x2A) {
        final close = text.indexOf('*/', index + 2);
        final end = close == -1 ? text.length : close + 2;
        for (var i = index; i < end; i++) {
          out.write(text.codeUnitAt(i) == 0x0A ? '\n' : ' ');
        }
        index = end;
        continue;
      }
    }
    out.writeCharCode(unit);
    index++;
  }
  return out.toString();
}

/// Index just past the string literal that starts at [start].
int _skipJsonString(String text, int start) {
  var index = start + 1;
  while (index < text.length) {
    final current = text.codeUnitAt(index++);
    if (current == 0x5C) {
      index++;
    } else if (current == 0x22) {
      break;
    }
  }
  return index;
}

String _formatJson(String text, {required bool allowComments}) {
  // Validate first, then re-indent the original tokens. Decoding and
  // encoding through Dart objects would lose duplicate keys and normalize
  // number/string representations, which is unsafe for a file editor.
  jsonDecode(allowComments ? stripJsonComments(text) : text);
  final tokens = _jsonTokens(text, allowComments: allowComments);
  final buffer = StringBuffer();
  var indent = 0;
  var pendingNewline = false;

  void emit(String token) {
    if (pendingNewline) {
      buffer
        ..writeln()
        ..write('  ' * indent);
      pendingNewline = false;
    }
    buffer.write(token);
  }

  for (var index = 0; index < tokens.length; index++) {
    final token = tokens[index];
    final previous = index == 0 ? null : tokens[index - 1];
    final next = index + 1 == tokens.length ? null : tokens[index + 1];
    switch (token) {
      case '{' || '[':
        emit(token);
        indent++;
        if (next != '}' && next != ']') pendingNewline = true;
      case '}' || ']':
        indent--;
        if (previous != '{' && previous != '[') pendingNewline = true;
        emit(token);
      case ',':
        emit(',');
        pendingNewline = true;
      case ':':
        emit(': ');
      default:
        emit(token);
        if (_isJsonComment(token)) pendingNewline = true;
    }
  }
  return '${buffer.toString().trimRight()}\n';
}

bool _isJsonComment(String token) =>
    token.startsWith('//') || token.startsWith('/*');

/// Splits valid JSON into its original syntax tokens without changing values.
/// With [allowComments], `//` and `/* */` comments become tokens too.
List<String> _jsonTokens(String text, {required bool allowComments}) {
  final tokens = <String>[];
  var index = 0;
  while (index < text.length) {
    final codeUnit = text.codeUnitAt(index);
    if (_isJsonWhitespace(codeUnit)) {
      index++;
      continue;
    }
    if (codeUnit == 0x22) {
      final end = _skipJsonString(text, index);
      tokens.add(text.substring(index, end));
      index = end;
      continue;
    }
    if (allowComments && codeUnit == 0x2F && index + 1 < text.length) {
      final next = text.codeUnitAt(index + 1);
      if (next == 0x2F) {
        var end = text.indexOf('\n', index);
        if (end == -1) end = text.length;
        tokens.add(text.substring(index, end).trimRight());
        index = end;
        continue;
      }
      if (next == 0x2A) {
        final close = text.indexOf('*/', index + 2);
        final end = close == -1 ? text.length : close + 2;
        tokens.add(text.substring(index, end));
        index = end;
        continue;
      }
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
          '{}[],:'.contains(String.fromCharCode(current)) ||
          (allowComments && current == 0x2F)) {
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
