/// Phase 7: Country → State → District configuration for venue import.
library;

/// Bounding box: south, west, north, east (Overpass order).
typedef ImportBBox = (double south, double west, double north, double east);

class ImportDistrictConfig {
  const ImportDistrictConfig({
    required this.name,
    this.bbox,
  });

  final String name;
  final ImportBBox? bbox;
}

class ImportStateConfig {
  const ImportStateConfig({
    required this.name,
    this.districts = const [],
  });

  final String name;
  final List<ImportDistrictConfig> districts;

  /// When true, importer may run state-wide OSM area query without a district.
  bool get allowsEntireState => districts.isEmpty || districts.any((d) => d.name == kEntireState);
}

class ImportCountryConfig {
  const ImportCountryConfig({
    required this.code,
    required this.label,
    required this.emoji,
    required this.states,
  });

  final String code;
  final String label;
  final String emoji;
  final List<ImportStateConfig> states;
}

/// Sentinel district meaning "whole state" OSM area search.
const kEntireState = 'Entire state';

/// Default OSM tag sets + Google type hints (mirrors DB mappings; used offline).
class ImportCategoryConfig {
  const ImportCategoryConfig({
    required this.slug,
    required this.displayName,
    required this.emoji,
    required this.osmTags,
    this.googlePlaceType = '',
    this.isActive = true,
  });

  final String slug;
  final String displayName;
  final String emoji;
  final List<String> osmTags;
  final String googlePlaceType;
  final bool isActive;

  ImportCategoryConfig copyWith({bool? isActive}) => ImportCategoryConfig(
        slug: slug,
        displayName: displayName,
        emoji: emoji,
        osmTags: osmTags,
        googlePlaceType: googlePlaceType,
        isActive: isActive ?? this.isActive,
      );
}

const kDefaultImportCategories = <ImportCategoryConfig>[
  ImportCategoryConfig(
    slug: 'function_hall',
    displayName: 'Function Hall',
    emoji: '🏛️',
    osmTags: [
      'amenity=events_venue',
      'amenity=community_centre',
      'name~=Function Hall|Kalyan|Marriage|Convention|Banquet|Mandapam',
    ],
    googlePlaceType: 'event_venue',
  ),
  ImportCategoryConfig(
    slug: 'marriage_hall',
    displayName: 'Marriage Hall',
    emoji: '💍',
    osmTags: [
      'amenity=events_venue',
      'name~=Marriage|Kalyan|Wedding|Mandapam',
    ],
    googlePlaceType: 'event_venue',
  ),
  ImportCategoryConfig(
    slug: 'convention_center',
    displayName: 'Convention Center',
    emoji: '🏨',
    osmTags: [
      'amenity=events_venue',
      'building=convention_centre',
      'name~=Convention|Banquet',
    ],
    googlePlaceType: 'convention_center',
  ),
  ImportCategoryConfig(
    slug: 'party_hall',
    displayName: 'Party Hall',
    emoji: '🎉',
    osmTags: ['amenity=events_venue', 'name~=Party Hall|Banquet'],
    googlePlaceType: 'event_venue',
  ),
  ImportCategoryConfig(
    slug: 'meeting_room',
    displayName: 'Meeting / Coworking',
    emoji: '🤝',
    osmTags: ['amenity=conference_centre', 'office=coworking'],
    googlePlaceType: 'conference_room',
  ),
  ImportCategoryConfig(
    slug: 'coworking_space',
    displayName: 'Coworking Space',
    emoji: '💻',
    osmTags: ['amenity=coworking_space', 'office=coworking'],
    googlePlaceType: 'coworking_space',
  ),
  ImportCategoryConfig(
    slug: 'community_hall',
    displayName: 'Community Hall',
    emoji: '🏛️',
    osmTags: ['amenity=community_centre'],
    googlePlaceType: 'community_center',
  ),
  ImportCategoryConfig(
    slug: 'sports_ground',
    displayName: 'Sports',
    emoji: '🏆',
    osmTags: ['leisure=sports_centre', 'leisure=pitch', 'leisure=stadium'],
    googlePlaceType: 'stadium',
  ),
  ImportCategoryConfig(
    slug: 'auditorium',
    displayName: 'Auditorium',
    emoji: '🎭',
    osmTags: ['amenity=theatre', 'amenity=arts_centre'],
    googlePlaceType: 'performing_arts_theater',
  ),
  ImportCategoryConfig(
    slug: 'hotel',
    displayName: 'Hotel',
    emoji: '🛏️',
    osmTags: ['tourism=hotel'],
    googlePlaceType: 'lodging',
  ),
  ImportCategoryConfig(
    slug: 'resort',
    displayName: 'Resort',
    emoji: '🌴',
    osmTags: ['tourism=resort', 'leisure=resort'],
    googlePlaceType: 'resort_hotel',
  ),
  ImportCategoryConfig(
    slug: 'institute',
    displayName: 'Institute',
    emoji: '🎓',
    osmTags: [
      'amenity=college',
      'amenity=university',
      'amenity=school',
      'name~=Institute|Academy|College',
    ],
    googlePlaceType: 'school',
  ),
  ImportCategoryConfig(
    slug: 'classroom',
    displayName: 'Classroom',
    emoji: '📚',
    osmTags: ['amenity=school', 'amenity=college', 'building=school'],
    googlePlaceType: 'school',
  ),
  ImportCategoryConfig(
    slug: 'event_space',
    displayName: 'Events',
    emoji: '🎪',
    osmTags: ['amenity=events_venue', 'amenity=community_centre'],
    googlePlaceType: 'event_venue',
  ),
];

/// Built-in geo tree. District bboxes are optional; OSM falls back to area name.
const kImportCountries = <ImportCountryConfig>[
  ImportCountryConfig(
    code: 'India',
    label: 'India',
    emoji: '🇮🇳',
    states: [
      ImportStateConfig(
        name: 'Andhra Pradesh',
        districts: [
          ImportDistrictConfig(name: kEntireState),
          ImportDistrictConfig(
            name: 'Prakasam',
            bbox: (15.20, 79.40, 16.00, 80.40),
          ),
          ImportDistrictConfig(
            name: 'Guntur',
            bbox: (15.90, 79.90, 16.70, 80.80),
          ),
          ImportDistrictConfig(
            name: 'Krishna',
            bbox: (16.00, 80.40, 16.90, 81.30),
          ),
          ImportDistrictConfig(
            name: 'Visakhapatnam',
            bbox: (17.40, 82.90, 18.10, 83.60),
          ),
          const ImportDistrictConfig(name: 'East Godavari'),
          const ImportDistrictConfig(name: 'West Godavari'),
          const ImportDistrictConfig(name: 'Nellore'),
          const ImportDistrictConfig(name: 'Chittoor'),
          const ImportDistrictConfig(name: 'Anantapur'),
          const ImportDistrictConfig(name: 'Kurnool'),
          const ImportDistrictConfig(name: 'Kadapa'),
          const ImportDistrictConfig(name: 'Srikakulam'),
          const ImportDistrictConfig(name: 'Vizianagaram'),
        ],
      ),
      ImportStateConfig(
        name: 'Telangana',
        districts: const [
          ImportDistrictConfig(name: kEntireState),
          ImportDistrictConfig(name: 'Hyderabad'),
          ImportDistrictConfig(name: 'Rangareddy'),
          ImportDistrictConfig(name: 'Medchal'),
          ImportDistrictConfig(name: 'Warangal'),
        ],
      ),
      ImportStateConfig(
        name: 'Tamil Nadu',
        districts: const [
          ImportDistrictConfig(name: kEntireState),
          ImportDistrictConfig(name: 'Chennai'),
          ImportDistrictConfig(name: 'Coimbatore'),
          ImportDistrictConfig(name: 'Madurai'),
        ],
      ),
      ImportStateConfig(
        name: 'Karnataka',
        districts: const [
          ImportDistrictConfig(name: kEntireState),
          ImportDistrictConfig(name: 'Bengaluru Urban'),
          ImportDistrictConfig(name: 'Mysuru'),
        ],
      ),
      ImportStateConfig(
        name: 'Maharashtra',
        districts: const [
          ImportDistrictConfig(name: kEntireState),
          ImportDistrictConfig(name: 'Mumbai'),
          ImportDistrictConfig(name: 'Pune'),
          ImportDistrictConfig(name: 'Nagpur'),
        ],
      ),
      ImportStateConfig(
        name: 'Kerala',
        districts: const [
          ImportDistrictConfig(name: kEntireState),
          ImportDistrictConfig(name: 'Ernakulam'),
          ImportDistrictConfig(name: 'Thiruvananthapuram'),
        ],
      ),
      ImportStateConfig(
        name: 'Delhi',
        districts: const [
          ImportDistrictConfig(name: kEntireState),
        ],
      ),
      // Remaining states: entire-state import until district lists expand.
      ImportStateConfig(name: 'Arunachal Pradesh'),
      ImportStateConfig(name: 'Assam'),
      ImportStateConfig(name: 'Bihar'),
      ImportStateConfig(name: 'Chhattisgarh'),
      ImportStateConfig(name: 'Goa'),
      ImportStateConfig(name: 'Gujarat'),
      ImportStateConfig(name: 'Haryana'),
      ImportStateConfig(name: 'Himachal Pradesh'),
      ImportStateConfig(name: 'Jharkhand'),
      ImportStateConfig(name: 'Madhya Pradesh'),
      ImportStateConfig(name: 'Manipur'),
      ImportStateConfig(name: 'Meghalaya'),
      ImportStateConfig(name: 'Mizoram'),
      ImportStateConfig(name: 'Nagaland'),
      ImportStateConfig(name: 'Odisha'),
      ImportStateConfig(name: 'Punjab'),
      ImportStateConfig(name: 'Rajasthan'),
      ImportStateConfig(name: 'Sikkim'),
      ImportStateConfig(name: 'Tripura'),
      ImportStateConfig(name: 'Uttar Pradesh'),
      ImportStateConfig(name: 'Uttarakhand'),
      ImportStateConfig(name: 'West Bengal'),
    ],
  ),
];

ImportCountryConfig? importCountryByCode(String code) {
  for (final c in kImportCountries) {
    if (c.code == code) return c;
  }
  return null;
}

ImportStateConfig? importStateConfig(String country, String state) {
  final c = importCountryByCode(country);
  if (c == null) return null;
  for (final s in c.states) {
    if (s.name == state) return s;
  }
  return null;
}

ImportDistrictConfig? importDistrictConfig(
  String country,
  String state,
  String district,
) {
  final s = importStateConfig(country, state);
  if (s == null) return null;
  for (final d in s.districts) {
    if (d.name == district) return d;
  }
  return null;
}

ImportCategoryConfig? importCategoryBySlug(String slug) {
  for (final c in kDefaultImportCategories) {
    if (c.slug == slug) return c;
  }
  return null;
}

List<String> indianStateNames() =>
    importCountryByCode('India')?.states.map((s) => s.name).toList() ??
    const [];
