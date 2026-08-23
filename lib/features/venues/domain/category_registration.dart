import 'category_configuration.dart';

/// Per-category unified registration knobs stored on [CategoryConfiguration]
/// metadata. Not a second registration or booking engine.
class CategoryRegistrationConfig {
  const CategoryRegistrationConfig({
    this.enabled = false,
    this.kycRequired = false,
    this.requiredFields = const [],
    this.optionalFields = const [],
  });

  final bool enabled;
  final bool kycRequired;
  final List<String> requiredFields;
  final List<String> optionalFields;

  bool get enforcedForBooking => enabled;

  factory CategoryRegistrationConfig.from(CategoryConfiguration? config) {
    if (config == null) return const CategoryRegistrationConfig();
    return CategoryRegistrationConfig(
      enabled: config.registrationRequired,
      kycRequired: config.kycRequired,
      requiredFields: config.registrationRequiredFields,
      optionalFields: config.registrationOptionalFields,
    );
  }

  List<String> missing(Map<String, Object?> values) {
    if (!enabled) return const [];
    final absent = <String>[
      for (final key in requiredFields)
        if (_isEmpty(values[key])) key,
    ];
    if (kycRequired && _isEmpty(values['kyc_document'])) {
      absent.add('kyc_document');
    }
    return absent;
  }

  static bool _isEmpty(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return '$value'.trim().isEmpty;
  }
}
