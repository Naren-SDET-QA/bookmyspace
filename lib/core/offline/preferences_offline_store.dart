import '../config/settings_controller.dart';
import 'offline_store.dart';

/// Persists cache/search/help keys through the existing Preferences layer.
class PreferencesOfflineStore implements OfflineStore {
  PreferencesOfflineStore(this._prefs);

  final Preferences _prefs;
  final _memory = MemoryOfflineStore();

  @override
  Future<String?> read(String key) async {
    try {
      return await _prefs.read(key) ?? await _memory.read(key);
    } catch (_) {
      return _memory.read(key);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _memory.write(key, value);
    try {
      await _prefs.write(key, value);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    await _memory.delete(key);
    try {
      await _prefs.delete(key);
    } catch (_) {}
  }
}
