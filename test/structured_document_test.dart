import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/structured_document.dart';

void main() {
  group('structuredKindForFileName', () {
    test('detects json jsonc yaml toml extensions', () {
      expect(structuredKindForFileName('a.json'), StructuredDocumentKind.json);
      expect(
        structuredKindForFileName('settings.jsonc'),
        StructuredDocumentKind.jsonc,
      );
      expect(structuredKindForFileName('a.YAML'), StructuredDocumentKind.yaml);
      expect(structuredKindForFileName('a.yml'), StructuredDocumentKind.yaml);
      expect(structuredKindForFileName('a.toml'), StructuredDocumentKind.toml);
      expect(structuredKindForFileName('readme.md'), isNull);
    });
  });

  group('canFormatStructuredDocument', () {
    test('only JSON kinds can be formatted', () {
      expect(canFormatStructuredDocument(StructuredDocumentKind.json), isTrue);
      expect(canFormatStructuredDocument(StructuredDocumentKind.jsonc), isTrue);
      expect(canFormatStructuredDocument(StructuredDocumentKind.yaml), isFalse);
      expect(canFormatStructuredDocument(StructuredDocumentKind.toml), isFalse);
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

    test('strict JSON rejects comments', () {
      expect(
        () => formatStructuredDocument(
          '{"a": 1 // c\n}',
          StructuredDocumentKind.json,
        ),
        throwsFormatException,
      );
    });

    test('formats JSONC keeping comments on their own lines', () {
      final formatted = formatStructuredDocument(
        '/* head */\n{"a":1, // trailing\n"url":"http://x", "b":{}}',
        StructuredDocumentKind.jsonc,
      );
      expect(
        formatted,
        '/* head */\n'
        '{\n'
        '  "a": 1,\n'
        '  // trailing\n'
        '  "url": "http://x",\n'
        '  "b": {}\n'
        '}\n',
      );
    });

    test('refuses YAML and TOML instead of rewriting them', () {
      expect(
        () => formatStructuredDocument('b: 1\n', StructuredDocumentKind.yaml),
        throwsUnsupportedError,
      );
      expect(
        () => formatStructuredDocument('b = 1\n', StructuredDocumentKind.toml),
        throwsUnsupportedError,
      );
    });
  });

  group('stripJsonComments', () {
    test('blanks comments but keeps offsets and strings intact', () {
      const source = '{"u": "a//b", /* x\ny */ "n": 1 // tail\n}';
      final stripped = stripJsonComments(source);
      expect(stripped.length, source.length);
      expect(stripped.split('\n').length, source.split('\n').length);
      expect(stripped, contains('"a//b"'));
      expect(stripped, isNot(contains('/*')));
      expect(stripped, isNot(contains('// tail')));
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

    test('accepts JSONC with comments', () {
      final issues = lintStructuredDocument(
        '// settings\n{\n  "a": 1, /* inline */\n  "b": "// not a comment"\n}',
        StructuredDocumentKind.jsonc,
      );
      expect(issues, isEmpty);
    });

    test('reports JSONC errors on the original line', () {
      final issues = lintStructuredDocument(
        '// line 0\n{\n  "a": 1,\n  "b":\n}',
        StructuredDocumentKind.jsonc,
      );
      expect(issues, hasLength(1));
      expect(issues.first.line, 4);
    });

    test('strict JSON flags comments', () {
      final issues = lintStructuredDocument(
        '{"a": 1} // c',
        StructuredDocumentKind.json,
      );
      expect(issues, isNotEmpty);
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
