import '../../../core/modular/feature_id.dart';
import '../../../core/modular/feature_registry.dart';
import '../../venues/domain/category_configuration.dart';

class BookingFieldSpec {
  const BookingFieldSpec({required this.key, this.required = true});

  final String key;
  final bool required;

  String get inputKind {
    return switch (key) {
      'date' || 'check_in' || 'check_out' || 'move_in' || 'schedule' => 'date',
      'time' => 'time',
      'guests' || 'occupants' || 'ticket_quantity' || 'duration' => 'number',
      _ => 'text',
    };
  }
}

class BookingFieldValues {
  const BookingFieldValues([this.values = const {}]);

  final Map<String, Object?> values;

  BookingFieldValues copyWith(String key, Object? value) {
    return BookingFieldValues({...values, key: value});
  }

  List<String> missing(List<BookingFieldSpec> fields) {
    return [
      for (final field in fields)
        if (field.required && _isEmpty(values[field.key])) field.key,
    ];
  }

  Map<String, dynamic> toMetadata() {
    return {
      for (final entry in values.entries)
        if (entry.value != null && '${entry.value}'.trim().isNotEmpty)
          entry.key: entry.value,
    };
  }

  static bool _isEmpty(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is num) return false;
    return '$value'.trim().isEmpty;
  }
}

class ConfigurableBookingFields {
  const ConfigurableBookingFields._();

  static List<BookingFieldSpec> from(CategoryConfiguration? config) {
    if (config == null || config.isListingOnly) return const [];
    final required = _clean(config.bookingRequiredFields);
    final optional = _clean(config.bookingOptionalFields);
    if (required.isEmpty && optional.isEmpty) return const [];
    return [
      for (final key in required) BookingFieldSpec(key: key),
      for (final key in optional) BookingFieldSpec(key: key, required: false),
    ];
  }

  static List<BookingFieldSpec> resolve({
    CategoryConfiguration? config,
    String? sectionId,
    FeatureRegistry? registry,
  }) {
    final configured = from(config);
    if (configured.isNotEmpty) return configured;
    if (config?.isListingOnly == true) return const [];
    final fromAdmin = _fromFeatureConfig(registry, sectionId);
    if (fromAdmin.isNotEmpty) return fromAdmin;
    return switch (sectionId) {
      'function_halls' => const [BookingFieldSpec(key: 'guests')],
      'lodge_rooms' => const [
        BookingFieldSpec(key: 'check_in'),
        BookingFieldSpec(key: 'check_out'),
        BookingFieldSpec(key: 'guests', required: false),
      ],
      'pg_hostels' => const [
        BookingFieldSpec(key: 'move_in'),
        BookingFieldSpec(key: 'duration'),
        BookingFieldSpec(key: 'occupants'),
      ],
      'events' => const [
        BookingFieldSpec(key: 'event_session'),
        BookingFieldSpec(key: 'ticket_quantity'),
      ],
      'courses' => const [
        BookingFieldSpec(key: 'schedule'),
        BookingFieldSpec(key: 'student_name'),
      ],
      _ => const [],
    };
  }

  static List<BookingFieldSpec> _fromFeatureConfig(
    FeatureRegistry? registry,
    String? sectionId,
  ) {
    if (registry == null || sectionId == null) return const [];
    final id = switch (sectionId) {
      'function_halls' => FeatureId.functionHall,
      'lodge_rooms' => FeatureId.hotels,
      'pg_hostels' => FeatureId.pg,
      'institutes_classes' => FeatureId.institutes,
      'events' => FeatureId.events,
      'courses' => FeatureId.courses,
      _ => null,
    };
    if (id == null || !registry.isBookingEnabled(id)) return const [];
    final metadata = registry.configOf(id).config;
    final required = _clean(_asStrings(metadata['booking_required_fields']));
    final optional = _clean(_asStrings(metadata['booking_optional_fields']));
    if (required.isEmpty && optional.isEmpty) return const [];
    return [
      for (final key in required) BookingFieldSpec(key: key),
      for (final key in optional) BookingFieldSpec(key: key, required: false),
    ];
  }

  static List<String> _asStrings(Object? raw) {
    if (raw is List) {
      return raw.map((item) => item.toString()).toList(growable: false);
    }
    return const [];
  }

  static List<String> _clean(List<String> raw) => raw
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}
