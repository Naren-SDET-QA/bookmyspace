import 'auth_configuration.dart';

abstract interface class AuthConfigurationRepository {
  Future<AuthConfiguration> load();
  Future<void> update(Map<String, bool> flags);
}
