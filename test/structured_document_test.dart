import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/structured_document.dart';

void main() {
  group('structuredKindForFileName', () {
    test('detects json yaml toml extensions', () {
      expect(structuredKindForFileName('a.json'), StructuredDocumentKind.json);
      expect(structuredKindForFileName('a.YAML'), StructuredDocumentKind.yaml);
      expect(structuredKindForFileName('a.yml'), StructuredDocumentKind.yaml);
      expect(structuredKindForFileName('a.toml'), StructuredDocumentKind.toml);
      expect(structuredKindForFileName('readme.md'), isNull);
    });
  });

  group('formatStructuredDocument', () {
    test('pretty-prints JSON', () {
      final formatted = formatStructuredDocument(
        '{"b":1,"a":[2,3]}',
        StructuredDocumentKind.json,
      );
      expect(formatted, '{\n  "b": 1,\n  "a": [\n    2,\n    3\n  ]\n}\n');
    });

    test('formats JSON without changing duplicate keys or value tokens', () {
      final formatted = formatStructuredDocument(
        '{"key":1,"key":2,"number":1.2300e+04,"text":"\\u0041"}',
        StructuredDocumentKind.json,
      );

      expect(
        formatted,
        '{\n'
        '  "key": 1,\n'
        '  "key": 2,\n'
        '  "number": 1.2300e+04,\n'
        '  "text": "\\u0041"\n'
        '}\n',
      );
    });

    test('pretty-prints YAML', () {
      final formatted = formatStructuredDocument(
        'b: 1\na: [2, 3]',
        StructuredDocumentKind.yaml,
      );
      expect(formatted, contains('b: 1'));
      expect(formatted, contains('a:'));
      expect(formatted, contains('- 2'));
      expect(formatted, contains('- 3'));
    });

    test('pretty-prints TOML', () {
      final formatted = formatStructuredDocument(
        'b=1\na="x"',
        StructuredDocumentKind.toml,
      );
      expect(formatted, contains('b = 1'));
      expect(formatted, contains("a = 'x'"));
    });
  });

  group('lintStructuredDocument', () {
    test('reports JSON syntax errors with line', () {
      final issues = lintStructuredDocument(
        '{\n  "a":\n}',
        StructuredDocumentKind.json,
      );
      expect(issues, isNotEmpty);
      expect(issues.first.line, greaterThanOrEqualTo(0));
      expect(issues.first.message, isNotEmpty);
    });

    test('accepts valid YAML', () {
      final issues = lintStructuredDocument(
        'services:\n  web:\n    image: nginx\n',
        StructuredDocumentKind.yaml,
      );
      expect(issues, isEmpty);
    });

    test('reports YAML errors', () {
      final issues = lintStructuredDocument(
        'a: [\n',
        StructuredDocumentKind.yaml,
      );
      expect(issues, isNotEmpty);
    });

    test('accepts valid TOML', () {
      final issues = lintStructuredDocument(
        '[table]\nkey = "value"\n',
        StructuredDocumentKind.toml,
      );
      expect(issues, isEmpty);
    });

    test('reports TOML errors with line', () {
      final issues = lintStructuredDocument(
        '[table\nkey = 1\n',
        StructuredDocumentKind.toml,
      );
      expect(issues, isNotEmpty);
      expect(issues.first.line, 0);
    });
  });
}
