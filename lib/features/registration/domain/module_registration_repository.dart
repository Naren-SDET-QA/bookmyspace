import 'module_registration.dart';

abstract interface class ModuleRegistrationRepository {
  Future<ModuleFeatureConfig?> featureConfig(
    String moduleKey, {
    String? venueId,
  });
  Future<List<ModuleFormVersion>> publishedForms(
    String moduleKey, {
    String? venueId,
  });
  Future<String> submit({
    required String moduleKey,
    String? venueId,
    String? bookingId,
    required String formVersionId,
    required Map<String, dynamic> values,
    required String idempotencyKey,
  });
}
