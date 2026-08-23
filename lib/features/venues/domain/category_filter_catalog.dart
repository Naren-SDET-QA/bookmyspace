import '../../home/domain/customer_section_catalog.dart';
import 'category_configuration.dart';

/// Converts database category metadata into the existing search filter model.
/// Unknown filter keys are ignored safely; legacy section defaults are used
/// only when no loaded category supplies configuration.
class CategoryFilterCatalog {
  const CategoryFilterCatalog._();

  static const _fields = <String, SectionFilterField>{
    'date': SectionFilterField.date,
    'guests': SectionFilterField.guests,
    'price_range': SectionFilterField.priceRange,
    'amenities': SectionFilterField.amenities,
    'check_in_out': SectionFilterField.checkInOut,
    'check_in': SectionFilterField.checkInOut,
    'room_type': SectionFilterField.roomType,
    'min_rating': SectionFilterField.minRating,
    'rating': SectionFilterField.minRating,
    'gender': SectionFilterField.gender,
    'sharing': SectionFilterField.sharing,
    'food': SectionFilterField.food,
    'deposit': SectionFilterField.deposit,
    'class_type': SectionFilterField.classType,
    'mode': SectionFilterField.mode,
  };

  static const _labels = <SectionFilterField, String>{
    SectionFilterField.date: 'Event Date',
    SectionFilterField.guests: 'Guests',
    SectionFilterField.priceRange: 'Price Range',
    SectionFilterField.amenities: 'Amenities',
    SectionFilterField.checkInOut: 'Check-in / Check-out',
    SectionFilterField.roomType: 'Room Type',
    SectionFilterField.minRating: 'Rating',
    SectionFilterField.gender: 'Gender',
    SectionFilterField.sharing: 'Sharing',
    SectionFilterField.food: 'Food',
    SectionFilterField.deposit: 'Security Deposit',
    SectionFilterField.classType: 'Class Type',
    SectionFilterField.mode: 'Mode',
  };

  static const _icons = <SectionFilterField, String>{
    SectionFilterField.date: '📅',
    SectionFilterField.guests: '👥',
    SectionFilterField.priceRange: '💰',
    SectionFilterField.amenities: '✨',
    SectionFilterField.checkInOut: '🗓️',
    SectionFilterField.roomType: '🛏️',
    SectionFilterField.minRating: '⭐',
    SectionFilterField.gender: '⚧️',
    SectionFilterField.sharing: '🛏️',
    SectionFilterField.food: '🍽️',
    SectionFilterField.deposit: '💳',
    SectionFilterField.classType: '🎓',
    SectionFilterField.mode: '🖥️',
  };

  static List<SectionFilterSpec> specs(
    List<CategoryConfiguration> configurations, {
    required String? sectionId,
    List<SectionFilterSpec> fallback = const [],
  }) {
    final fields = <SectionFilterField>[];
    for (final config in configurations) {
      if (sectionId != null && config.sectionId != sectionId) continue;
      if (!config.visible || !config.searchable) continue;
      for (final key in config.filters) {
        final field = _fields[key.trim().toLowerCase()];
        if (field != null && !fields.contains(field)) fields.add(field);
      }
    }
    if (fields.isEmpty) return fallback;
    return [
      for (final field in fields)
        SectionFilterSpec(field, _labels[field]!, _icons[field]!),
    ];
  }

  static List<AmenityFilterSpec> amenities(
    List<CategoryConfiguration> configurations, {
    required String? sectionId,
    List<AmenityFilterSpec> fallback = const [],
  }) {
    final values = <String>{};
    for (final config in configurations) {
      if (sectionId != null && config.sectionId != sectionId) continue;
      if (!config.visible || !config.searchable) continue;
      values.addAll(config.amenities.map((v) => v.trim().toLowerCase()));
    }
    if (values.isEmpty) return fallback;
    return [
      for (final value in values)
        if (value.isNotEmpty)
          AmenityFilterSpec(value, _title(value), '✨', [value]),
    ];
  }

  static String _title(String value) => value
      .split(RegExp(r'[_-]+'))
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
