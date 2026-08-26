import 'package:shared_preferences/shared_preferences.dart';

abstract interface class MetricsRefreshSettings {
  Duration get backgroundInterval;
  Duration get focusedInterval;

  Future<void> saveBackgroundInterval(Duration value);
  Future<void> saveFocusedInterval(Duration value);
}

class MetricsRefreshPreferences implements MetricsRefreshSettings {
  MetricsRefreshPreferences(
    this._preferences,
    this.backgroundInterval,
    this.focusedInterval,
  );

  static const _backgroundIntervalSecondsKey =
      'background_metrics_refresh_interval_seconds';
  static const _focusedIntervalSecondsKey =
      'focused_detail_refresh_interval_seconds';
  static const defaultBackgroundInterval = Duration(seconds: 30);
  static const defaultFocusedInterval = Duration(seconds: 3);

  final SharedPreferencesAsync _preferences;
  @override
  final Duration backgroundInterval;
  @override
  final Duration focusedInterval;

  static Future<MetricsRefreshPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    final backgroundSeconds = await store.getInt(_backgroundIntervalSecondsKey);
    final focusedSeconds = await store.getInt(_focusedIntervalSecondsKey);
    return MetricsRefreshPreferences(
      store,
      Duration(
        seconds: backgroundSeconds ?? defaultBackgroundInterval.inSeconds,
      ),
      Duration(seconds: focusedSeconds ?? defaultFocusedInterval.inSeconds),
    );
  }

  @override
  Future<void> saveBackgroundInterval(Duration value) =>
      _preferences.setInt(_backgroundIntervalSecondsKey, value.inSeconds);

  @override
  Future<void> saveFocusedInterval(Duration value) =>
      _preferences.setInt(_focusedIntervalSecondsKey, value.inSeconds);
}

class InMemoryMetricsRefreshSettings implements MetricsRefreshSettings {
  InMemoryMetricsRefreshSettings({
    this.backgroundInterval =
        MetricsRefreshPreferences.defaultBackgroundInterval,
    this.focusedInterval = MetricsRefreshPreferences.defaultFocusedInterval,
  });

  @override
  Duration backgroundInterval;
  @override
  Duration focusedInterval;

  @override
  Future<void> saveBackgroundInterval(Duration value) async {
    backgroundInterval = value;
  }

  @override
  Future<void> saveFocusedInterval(Duration value) async {
    focusedInterval = value;
  }
}
