import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppThemeSettings {
  Color get seedColor;
  ThemeMode get themeMode;

  Future<void> saveSeedColor(Color color);
  Future<void> saveThemeMode(ThemeMode mode);
}

class AppThemePreferences implements AppThemeSettings {
  AppThemePreferences(this._preferences, this.seedColor, this.themeMode);

  static const _seedColorKey = 'app_theme_seed_color';
  static const _themeModeKey = 'app_theme_mode';
  static const _defaultSeedColor = Color(0xFF0F766E);

  final SharedPreferencesAsync _preferences;
  @override
  final Color seedColor;
  @override
  final ThemeMode themeMode;

  static Future<AppThemePreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return AppThemePreferences(
      store,
      Color(await store.getInt(_seedColorKey) ?? _defaultSeedColor.toARGB32()),
      _decodeThemeMode(await store.getString(_themeModeKey)),
    );
  }

  static ThemeMode _decodeThemeMode(String? value) =>
      ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
      ThemeMode.system;

  @override
  Future<void> saveSeedColor(Color color) async {
    await _preferences.setInt(_seedColorKey, color.toARGB32());
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) =>
      _preferences.setString(_themeModeKey, mode.name);
}

class InMemoryAppThemeSettings implements AppThemeSettings {
  InMemoryAppThemeSettings({
    this.seedColor = const Color(0xFF0F766E),
    this.themeMode = ThemeMode.system,
  });

  @override
  Color seedColor;
  @override
  ThemeMode themeMode;

  @override
  Future<void> saveSeedColor(Color color) async => seedColor = color;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async => themeMode = mode;
}
