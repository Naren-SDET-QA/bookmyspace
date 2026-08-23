/// Lazy, disposable plugin. SDKs must not initialize in [main].
abstract interface class AppPlugin {
  String get id;
  bool get initialized;
  Future<void> ensureInitialized();
  Future<void> dispose();
}
