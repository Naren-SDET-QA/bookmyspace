import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores only the non-sensitive fields needed to resume email-confirmed
/// owner registration after the browser returns from Supabase Auth.
class PendingOwnerRegistrationStore {
  PendingOwnerRegistrationStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _emailKey = 'bms_pending_owner_email';
  static const _nameKey = 'bms_pending_owner_name';

  final FlutterSecureStorage _storage;

  Future<void> save({required String email, required String name}) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _nameKey, value: name);
  }

  Future<({String email, String name})?> read() async {
    final email = await _storage.read(key: _emailKey);
    final name = await _storage.read(key: _nameKey);
    if (email == null || name == null || email.isEmpty || name.isEmpty) {
      return null;
    }
    return (email: email, name: name);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nameKey);
  }
}
