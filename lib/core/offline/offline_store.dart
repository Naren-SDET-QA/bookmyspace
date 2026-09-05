/// Key-value persistence used for browse/search/booking cache and recent
/// searches. Default is in-memory so widget tests stay plugin-free; production
/// overrides this with [PreferencesOfflineStore].
abstract class OfflineStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemoryOfflineStore implements OfflineStore {
  MemoryOfflineStore([Map<String, String>? seed]) : _data = {...?seed};

  final Map<String, String> _data;

  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
