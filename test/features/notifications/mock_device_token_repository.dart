import 'package:bookmyspace/features/notifications/domain/device_token_repository.dart';

/// In-memory device token repository for tests.
class MockDeviceTokenRepository implements DeviceTokenRepository {
  final Map<String, String> _registered = {};
  final List<String> _deregistered = [];

  /// Currently-registered tokens, keyed by token value, mapped to platform.
  Map<String, String> get registered => Map.unmodifiable(_registered);

  /// Tokens that were deregistered, in order.
  List<String> get deregistered => List.unmodifiable(_deregistered);

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    _registered[token] = platform;
  }

  @override
  Future<void> deregisterToken(String token) async {
    _registered.remove(token);
    _deregistered.add(token);
  }
}
