import 'package:shared_preferences/shared_preferences.dart';

abstract interface class StartupConnectionSettings {
  bool get connectOnStartup;

  Future<void> saveConnectOnStartup(bool value);
}

class StartupConnectionPreferences implements StartupConnectionSettings {
  StartupConnectionPreferences(this._preferences, this.connectOnStartup);

  static const _connectOnStartupKey = 'connect_on_startup';

  final SharedPreferencesAsync _preferences;
  @override
  final bool connectOnStartup;

  static Future<StartupConnectionPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return StartupConnectionPreferences(
      store,
      await store.getBool(_connectOnStartupKey) ?? false,
    );
  }

  @override
  Future<void> saveConnectOnStartup(bool value) =>
      _preferences.setBool(_connectOnStartupKey, value);
}

class InMemoryStartupConnectionSettings implements StartupConnectionSettings {
  InMemoryStartupConnectionSettings([this.connectOnStartup = false]);

  @override
  bool connectOnStartup;

  @override
  Future<void> saveConnectOnStartup(bool value) async {
    connectOnStartup = value;
  }
}
