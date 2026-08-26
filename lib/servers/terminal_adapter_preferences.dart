import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'terminal_color_scheme.dart';

class TerminalFontOption {
  const TerminalFontOption({required this.label, required this.family});

  /// Display name, without weight/style suffixes (e.g. `SFMono`).
  final String label;

  /// Font file name registered in the engine and used for rendering
  /// (e.g. `SFMono-Regular`).
  final String family;
}

abstract final class TerminalFonts {
  static const defaultFamily = 'IBM Plex Mono';

  static const _variantKeywords = <String>[
    // Longest-first so greedy decomposition splits compound variants
    // (e.g. `ExtraLightItalic` -> extra + light + italic).
    'extralightitalic',
    'extrabolditalic',
    'semibolditalic',
    'mediumitalic',
    'lightitalic',
    'blackitalic',
    'thinitalic',
    'bolditalic',
    'extralight',
    'extrabold',
    'semilight',
    'condensed',
    'semibold',
    'expanded',
    'regular',
    'oblique',
    'medium',
    'italic',
    'retina',
    'heavy',
    'black',
    'light',
    'ultra',
    'book',
    'bold',
    'demi',
    'thin',
    'text',
  ];

  static String sanitize(String family) {
    final trimmed = family.trim();
    return trimmed.isEmpty ? defaultFamily : trimmed;
  }

  static bool _isVariantSegment(String segment) {
    var rest = segment.toLowerCase();
    var matched = false;
    while (rest.isNotEmpty) {
      String? keyword;
      for (final candidate in _variantKeywords) {
        if (rest.startsWith(candidate)) {
          keyword = candidate;
          break;
        }
      }
      if (keyword == null) return false;
      matched = true;
      rest = rest.substring(keyword.length);
    }
    return matched;
  }

  static String _stripVariantSuffix(String name) {
    final dash = name.lastIndexOf('-');
    if (dash == -1) return name;
    final segment = name.substring(dash + 1);
    if (_isVariantSegment(segment)) {
      return name.substring(0, dash);
    }
    return name;
  }

  static String _pickRegular(List<String> names) {
    for (final name in names) {
      if (name.toLowerCase().endsWith('-regular')) return name;
    }
    final sorted = [...names]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted.first;
  }

  /// Collapses font files of the same family into a single [TerminalFontOption],
  /// preferring the regular weight variant over bold/light/italic files.
  static List<TerminalFontOption> dedupe(List<String> families) {
    final byBase = <String, List<String>>{};
    for (final family in families) {
      byBase.putIfAbsent(_stripVariantSuffix(family), () => []).add(family);
    }
    final options = [
      for (final entry in byBase.entries)
        TerminalFontOption(label: entry.key, family: _pickRegular(entry.value)),
    ];
    options.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return options;
  }
}

/// Bounds and default for the terminal font size setting.
const double kTerminalFontSizeMin = 9;
const double kTerminalFontSizeMax = 24;
const double kTerminalFontSizeDefault = 14;

double sanitizeTerminalFontSize(double value) => value.isFinite
    ? value.clamp(kTerminalFontSizeMin, kTerminalFontSizeMax)
    : kTerminalFontSizeDefault;

const double kTerminalLineHeightMin = 1.0;
const double kTerminalLineHeightMax = 1.6;
const double kTerminalLineHeightDefault = 1.0;

double sanitizeTerminalLineHeight(double value) => value.isFinite
    ? value.clamp(kTerminalLineHeightMin, kTerminalLineHeightMax)
    : kTerminalLineHeightDefault;

abstract interface class TerminalAdapterSettings {
  bool get cursorAnimationEnabled;
  String get terminalFontFamily;
  double get terminalFontSize;
  double get terminalLineHeight;
  TerminalColorScheme get lightTheme;
  TerminalColorScheme get darkTheme;

  Future<void> saveCursorAnimationEnabled(bool enabled);
  Future<void> saveTerminalFontFamily(String family);
  Future<void> saveTerminalFontSize(double size);
  Future<void> saveTerminalLineHeight(double lineHeight);
  Future<void> saveLightTheme(TerminalColorScheme theme);
  Future<void> saveDarkTheme(TerminalColorScheme theme);
}

class TerminalAdapterPreferences implements TerminalAdapterSettings {
  TerminalAdapterPreferences(
    this._preferences,
    this.cursorAnimationEnabled,
    this.terminalFontFamily,
    this.terminalFontSize,
    this.terminalLineHeight,
    this.lightTheme,
    this.darkTheme,
  );

  static const _cursorAnimationEnabledKey = 'cursor_animation_enabled';
  static const _terminalFontFamilyKey = 'terminal_font_family';
  static const _terminalFontSizeKey = 'terminal_font_size';
  static const _terminalLineHeightKey = 'terminal_line_height';
  static const _lightThemeKey = 'terminal_light_theme';
  static const _darkThemeKey = 'terminal_dark_theme';

  final SharedPreferencesAsync _preferences;
  @override
  final bool cursorAnimationEnabled;
  @override
  final String terminalFontFamily;
  @override
  final double terminalFontSize;
  @override
  final double terminalLineHeight;
  @override
  final TerminalColorScheme lightTheme;
  @override
  final TerminalColorScheme darkTheme;

  static Future<TerminalAdapterPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return TerminalAdapterPreferences(
      store,
      await store.getBool(_cursorAnimationEnabledKey) ?? true,
      TerminalFonts.sanitize(
        await store.getString(_terminalFontFamilyKey) ??
            TerminalFonts.defaultFamily,
      ),
      sanitizeTerminalFontSize(
        await store.getDouble(_terminalFontSizeKey) ?? kTerminalFontSizeDefault,
      ),
      sanitizeTerminalLineHeight(
        await store.getDouble(_terminalLineHeightKey) ??
            kTerminalLineHeightDefault,
      ),
      _decodeTheme(await store.getString(_lightThemeKey)) ??
          TerminalColorSchemes.defaultLightScheme,
      _decodeTheme(await store.getString(_darkThemeKey)) ??
          TerminalColorSchemes.defaultScheme,
    );
  }

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) =>
      _preferences.setBool(_cursorAnimationEnabledKey, enabled);

  @override
  Future<void> saveTerminalFontFamily(String family) =>
      _preferences.setString(_terminalFontFamilyKey, family);

  @override
  Future<void> saveTerminalFontSize(double size) =>
      _preferences.setDouble(_terminalFontSizeKey, size);

  @override
  Future<void> saveTerminalLineHeight(double lineHeight) =>
      _preferences.setDouble(_terminalLineHeightKey, lineHeight);

  @override
  Future<void> saveLightTheme(TerminalColorScheme theme) =>
      _preferences.setString(_lightThemeKey, _encodeTheme(theme));

  @override
  Future<void> saveDarkTheme(TerminalColorScheme theme) =>
      _preferences.setString(_darkThemeKey, _encodeTheme(theme));

  static String _encodeTheme(TerminalColorScheme theme) => jsonEncode({
    'id': theme.id,
    'label': theme.label,
    'background': theme.background.toARGB32(),
    'foreground': theme.foreground.toARGB32(),
    'cursor': theme.cursor.toARGB32(),
    'selection': theme.selection.toARGB32(),
    'ansi': theme.ansiColors.map((color) => color.toARGB32()).toList(),
  });

  static TerminalColorScheme? _decodeTheme(String? encoded) {
    if (encoded == null) return null;
    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final ansi = (json['ansi'] as List<dynamic>)
          .map((value) => Color(value as int))
          .toList();
      return TerminalColorScheme(
        id: json['id'] as String? ?? 'custom',
        label: json['label'] as String? ?? 'Custom',
        background: Color(json['background'] as int),
        foreground: Color(json['foreground'] as int),
        cursor: Color(json['cursor'] as int),
        selection: Color(json['selection'] as int),
        ansiColors: ansi,
      );
    } catch (_) {
      return null;
    }
  }
}

class InMemoryTerminalAdapterSettings implements TerminalAdapterSettings {
  InMemoryTerminalAdapterSettings({
    this.cursorAnimationEnabled = true,
    this.terminalFontFamily = TerminalFonts.defaultFamily,
    this.terminalFontSize = kTerminalFontSizeDefault,
    this.terminalLineHeight = kTerminalLineHeightDefault,
    this.lightTheme = TerminalColorSchemes.defaultLightScheme,
    this.darkTheme = TerminalColorSchemes.defaultScheme,
  });

  @override
  bool cursorAnimationEnabled;
  @override
  String terminalFontFamily;
  @override
  double terminalFontSize;
  @override
  double terminalLineHeight;
  @override
  TerminalColorScheme lightTheme;
  @override
  TerminalColorScheme darkTheme;

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) async {
    cursorAnimationEnabled = enabled;
  }

  @override
  Future<void> saveTerminalFontFamily(String family) async {
    terminalFontFamily = family;
  }

  @override
  Future<void> saveTerminalFontSize(double size) async {
    terminalFontSize = size;
  }

  @override
  Future<void> saveTerminalLineHeight(double lineHeight) async {
    terminalLineHeight = lineHeight;
  }

  @override
  Future<void> saveLightTheme(TerminalColorScheme theme) async {
    lightTheme = theme;
  }

  @override
  Future<void> saveDarkTheme(TerminalColorScheme theme) async {
    darkTheme = theme;
  }
}
