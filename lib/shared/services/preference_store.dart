import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key/value settings storage backed by `SharedPreferencesAsync`.
///
/// Every stored value is read into memory once by [load], so reads are
/// synchronous and providers can build without awaiting; writes update the
/// cache and persist through to the platform store. [PreferenceStore.inMemory]
/// keeps everything in the cache only, for tests and for the default provider
/// value before `main` supplies the loaded store.
class PreferenceStore {
  PreferenceStore._(this._backing, Map<String, Object?> values)
    : _values = values;

  /// A store that never touches disk; [initial] seeds the cache.
  PreferenceStore.inMemory([Map<String, Object?> initial = const {}])
    : _backing = null,
      _values = {...initial};

  /// Loads every stored value from [preferences] (the platform store by
  /// default) so subsequent reads are synchronous.
  static Future<PreferenceStore> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final backing = preferences ?? SharedPreferencesAsync();
    return PreferenceStore._(backing, await backing.getAll());
  }

  final SharedPreferencesAsync? _backing;
  final Map<String, Object?> _values;

  /// The stored value for [key] when it is a [T]; null when missing or when
  /// the stored value has another type.
  T? read<T extends Object>(String key) {
    final value = _values[key];
    return value is T ? value : null;
  }

  /// Persists [value] under [key]; null removes the entry. Supported types
  /// are the ones `SharedPreferences` stores: bool, int, double, String and
  /// `List<String>`.
  Future<void> write(String key, Object? value) async {
    if (value == null) {
      _values.remove(key);
      await _backing?.remove(key);
      return;
    }
    if (value is! bool &&
        value is! int &&
        value is! double &&
        value is! String &&
        value is! List<String>) {
      throw ArgumentError.value(value, 'value', 'Unsupported preference');
    }
    _values[key] = value;
    final backing = _backing;
    if (backing == null) return;
    switch (value) {
      case bool flag:
        await backing.setBool(key, flag);
      case int number:
        await backing.setInt(key, number);
      case double number:
        await backing.setDouble(key, number);
      case String text:
        await backing.setString(key, text);
      case List<String> list:
        await backing.setStringList(key, list);
    }
  }
}

/// The app's settings store. Defaults to an in-memory store so widget tests
/// need no platform channel; `main` overrides it with the loaded one.
final preferenceStoreProvider = Provider<PreferenceStore>(
  (ref) => PreferenceStore.inMemory(),
);

/// A setting persisted under one preference key.
///
/// Subclasses name the [key], supply the [defaultValue] and convert between
/// the typed value and its stored representation; everything else — the
/// initial read, the update and the write-through — lives here.
abstract class PreferenceNotifier<T> extends Notifier<T> {
  String get key;
  T get defaultValue;

  /// The stored form of [value]: one of the types [PreferenceStore.write]
  /// accepts.
  Object encode(T value);

  /// The typed value for a stored [raw] entry, or null when it cannot be
  /// decoded (the default is used instead).
  T? decode(Object raw);

  @override
  T build() {
    final raw = ref.watch(preferenceStoreProvider).read<Object>(key);
    return raw == null ? defaultValue : decode(raw) ?? defaultValue;
  }

  /// Updates the value and persists it.
  Future<void> set(T value) async {
    state = value;
    await ref.read(preferenceStoreProvider).write(key, encode(value));
  }
}
