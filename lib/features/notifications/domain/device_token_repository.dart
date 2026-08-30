/// Registers/deregisters this device's push notification token against
/// the signed-in user. The token is this device's OneSignal push-
/// subscription id (see OneSignalPushService), kept here for local
/// observability -- the actual send-time targeting uses OneSignal's own
/// External ID association (OneSignal.login/logout), not this table.
abstract interface class DeviceTokenRepository {
  /// Registers (or refreshes) this device's push token for the current
  /// user. Safe to call repeatedly (e.g. on every app start and whenever
  /// the token rotates via `onTokenRefresh`).
  Future<void> registerToken({required String token, required String platform});

  /// Removes a single device token, e.g. on sign-out, so a shared device
  /// stops receiving push notifications meant for the previous account.
  Future<void> deregisterToken(String token);
}
