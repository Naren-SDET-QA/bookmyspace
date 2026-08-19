import '../../venues/domain/venue.dart';

/// Shared customer first-screen contract.
///
/// Mirrors the Compose [CustomerSectionCatalog] so Android and Flutter
/// iOS/Web show the same four sections and never mix results.
enum CustomerSection {
  functionHalls,
  lodgeRooms,
  pgHostels,
  institutesClasses;

  String get id => switch (this) {
    CustomerSection.functionHalls => 'function_halls',
    CustomerSection.lodgeRooms => 'lodge_rooms',
    CustomerSection.pgHostels => 'pg_hostels',
    CustomerSection.institutesClasses => 'institutes_classes',
  };

  String get title => switch (this) {
    CustomerSection.functionHalls => 'Function Halls',
    CustomerSection.lodgeRooms => 'Lodge / Rooms',
    CustomerSection.pgHostels => 'PG / Hostels',
    CustomerSection.institutesClasses => 'Institutes / Classes',
  };

  String get subtitle => switch (this) {
    CustomerSection.functionHalls =>
      'Marriage, Convention, Party, Community & Govt Halls',
    CustomerSection.lodgeRooms => 'Hotels, Lodges, Guest Houses & Day Rooms',
    CustomerSection.pgHostels => 'Gents PG, Ladies PG, Hostels & Co-living',
    CustomerSection.institutesClasses =>
      'Coaching, Tuition, Computer, Dance, Music & Sports',
  };

  String get emoji => switch (this) {
    CustomerSection.functionHalls => '🏛️',
    CustomerSection.lodgeRooms => '🏨',
    CustomerSection.pgHostels => '🏠',
    CustomerSection.institutesClasses => '🎓',
  };

  String get imageUrl => switch (this) {
    CustomerSection.functionHalls =>
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=900&auto=format&fit=crop&q=80',
    CustomerSection.lodgeRooms =>
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=900&auto=format&fit=crop&q=80',
    CustomerSection.pgHostels =>
      'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=900&auto=format&fit=crop&q=80',
    CustomerSection.institutesClasses =>
      'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=900&auto=format&fit=crop&q=80',
  };

  bool get isBookable => this != CustomerSection.institutesClasses;

  Set<String> get categorySlugs => switch (this) {
    CustomerSection.functionHalls => {
      'function_hall',
      'banquet_hall',
      'marriage_hall',
      'party_lawn',
      'convention_center',
      'community_hall',
      'govt_hall',
      'auditorium',
      'party_hall',
      'venues_function_halls',
    },
    CustomerSection.lodgeRooms => {
      'hotel_stay',
      'hotel',
      'lodge',
      'guest_house',
      'hourly_room',
      'resort',
      'homestay',
      'hotels_rooms',
      'room',
    },
    CustomerSection.pgHostels => {
      'pg_hostel',
      'hostel',
      'co_living',
      'gents_pg',
      'ladies_pg',
      'student_hostel',
      'pg_hostels',
      'pg',
      'pg_coliving',
    },
    CustomerSection.institutesClasses => {
      'institute',
      'class',
      'coaching',
      'academy',
      'badminton',
      'sports_turf',
      'sports_ground',
      'dance',
      'music',
      'institutes_classes',
      'computer_it',
      'dance_academy',
      'music_class',
      'sports_academy',
    },
  };

  List<CustomerSectionCategory> get categories => switch (this) {
    CustomerSection.functionHalls => const [
      CustomerSectionCategory('all', 'All Halls', '✨'),
      CustomerSectionCategory('marriage_hall', 'Marriage Hall', '💒'),
      CustomerSectionCategory('convention_center', 'Convention Hall', '🏛️'),
      CustomerSectionCategory('banquet_hall', 'Party Hall / Banquet', '🍸'),
      CustomerSectionCategory('community_hall', 'Community Hall', '🤝'),
      CustomerSectionCategory('govt_hall', 'Government Hall', '🏢'),
      CustomerSectionCategory('party_lawn', 'Open Lawn Ground', '🌳'),
    ],
    CustomerSection.lodgeRooms => const [
      CustomerSectionCategory('all', 'All Stays', '✨'),
      CustomerSectionCategory('hotel', 'Hotel', '🏨'),
      CustomerSectionCategory('lodge', 'Lodge', '🛏️'),
      CustomerSectionCategory('guest_house', 'Guest House', '🏡'),
      CustomerSectionCategory('hourly_room', 'Hourly / Day Room', '⏱️'),
      CustomerSectionCategory('resort', 'Resort / Homestay', '🌴'),
    ],
    CustomerSection.pgHostels => const [
      CustomerSectionCategory('all', 'All PG & Hostels', '✨'),
      CustomerSectionCategory('gents_pg', 'Gents PG', '👨'),
      CustomerSectionCategory('ladies_pg', 'Ladies PG', '👩'),
      CustomerSectionCategory('student_hostel', 'Student Hostel', '🎒'),
      CustomerSectionCategory('co_living', 'Co-living Spaces', '🤝'),
      CustomerSectionCategory('single_room', 'Single Sharing Room', '🔑'),
    ],
    CustomerSection.institutesClasses => const [
      CustomerSectionCategory('all', 'All Classes', '✨'),
      CustomerSectionCategory('coaching', 'Coaching & Tuition', '📚'),
      CustomerSectionCategory('computer_it', 'Computer & IT Classes', '💻'),
      CustomerSectionCategory('dance_academy', 'Dance Academy', '💃'),
      CustomerSectionCategory('music_class', 'Music & Singing', '🎵'),
      CustomerSectionCategory('sports_academy', 'Sports Academy & Turfs', '🏸'),
    ],
  };

  static CustomerSection? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final section in CustomerSection.values) {
      if (section.id == id) return section;
    }
    return CustomerSectionCatalog.fromAny(id);
  }
}

class CustomerSectionCategory {
  const CustomerSectionCategory(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

class AmenityFilterSpec {
  const AmenityFilterSpec(this.id, this.label, this.emoji, this.keywords);
  final String id;
  final String label;
  final String emoji;
  final List<String> keywords;
}

class CustomerSectionCatalog {
  const CustomerSectionCatalog._();

  static CustomerSection? fromAny(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final section in CustomerSection.values) {
      if (section.id == lower) return section;
      if (section.categorySlugs.contains(lower)) return section;
      if (section.categories.any((c) => c.id == lower)) return section;
    }
    return null;
  }

  static CustomerSection? sectionForVenue(Venue venue) {
    final slug = venue.category?.slug.toLowerCase() ?? '';
    if (CustomerSection.pgHostels.categorySlugs.contains(slug)) {
      return CustomerSection.pgHostels;
    }
    if (CustomerSection.lodgeRooms.categorySlugs.contains(slug)) {
      return CustomerSection.lodgeRooms;
    }
    if (CustomerSection.institutesClasses.categorySlugs.contains(slug)) {
      return CustomerSection.institutesClasses;
    }
    if (CustomerSection.functionHalls.categorySlugs.contains(slug)) {
      return CustomerSection.functionHalls;
    }
    // 0002-only DBs have no lodge/PG slugs. Owner listings still tag
    // the section in name/facilities so they do not land in halls.
    return sectionFromListingText(_haystack(venue));
  }

  static CustomerSection? sectionFromListingText(String haystack) {
    final hay = haystack.toLowerCase();
    bool has(List<String> tokens) => tokens.any(hay.contains);
    if (has(const [
      'ladies pg',
      'gents pg',
      'pg / hostels',
      'pg hostel',
      'pg_coliving',
      'paying guest',
      'co-living',
      'coliving',
      'student hostel',
      'hostel',
    ])) {
      return CustomerSection.pgHostels;
    }
    if (has(const [
      'lodge / rooms',
      'hotel stay',
      'guest house',
      'hourly /',
      'homestay',
      ' lodge',
      'resort',
      'hotel',
    ])) {
      return CustomerSection.lodgeRooms;
    }
    return null;
  }

  static bool matchesVenue(
    Venue venue,
    CustomerSection section, [
    String? categorySlug = 'all',
  ]) {
    if (sectionForVenue(venue) != section) return false;
    final selected = categorySlug?.toLowerCase();
    if (selected == null || selected.isEmpty || selected == 'all') return true;
    return _matchesCategory(venue, section, selected);
  }

  static List<AmenityFilterSpec> amenityFilters(CustomerSection section) {
    return switch (section) {
      CustomerSection.functionHalls => const [
        AmenityFilterSpec('parking', 'Parking', '🅿️', [
          'parking',
          'valet',
          'car',
        ]),
        AmenityFilterSpec('wifi', 'Wi-Fi', '📶', ['wifi', 'wi-fi', 'internet']),
        AmenityFilterSpec('ac', 'Air Conditioned', '❄️', [
          'ac',
          'air condition',
          'cooling',
        ]),
        AmenityFilterSpec('power_backup', 'Power Backup', '⚡', [
          'generator',
          'power',
        ]),
        AmenityFilterSpec('catering', 'In-House Food', '🍽️', [
          'cater',
          'food',
          'dining',
        ]),
      ],
      CustomerSection.lodgeRooms => const [
        AmenityFilterSpec('wifi', 'Wi-Fi', '📶', ['wifi', 'wi-fi']),
        AmenityFilterSpec('ac', 'Air Conditioned', '❄️', ['ac', 'air condition']),
        AmenityFilterSpec('parking', 'Parking', '🅿️', ['parking', 'valet']),
        AmenityFilterSpec('pool', 'Swimming Pool', '🏊', ['pool', 'swimming']),
      ],
      CustomerSection.pgHostels => const [
        AmenityFilterSpec('wifi', 'Wi-Fi', '📶', ['wifi', 'wi-fi']),
        AmenityFilterSpec('food', 'Food / Mess', '🍽️', ['meal', 'food', 'mess']),
        AmenityFilterSpec('ac', 'Air Conditioned', '❄️', ['ac', 'air condition']),
        AmenityFilterSpec('security', 'CCTV / Security', '📹', [
          'cctv',
          'security',
        ]),
      ],
      CustomerSection.institutesClasses => const [
        AmenityFilterSpec('parking', 'Parking', '🅿️', ['parking']),
        AmenityFilterSpec('wifi', 'Wi-Fi', '📶', ['wifi', 'wi-fi']),
        AmenityFilterSpec('ac', 'Air Conditioned', '❄️', ['ac', 'air condition']),
      ],
    };
  }

  static String bookingCtaLabel(CustomerSection? section) {
    return switch (section) {
      CustomerSection.pgHostels => 'Reserve',
      CustomerSection.lodgeRooms => 'Book Stay',
      CustomerSection.institutesClasses => 'Enquire',
      CustomerSection.functionHalls || null => 'Book Now',
    };
  }

  static String bookingScreenTitle(CustomerSection? section) {
    return switch (section) {
      CustomerSection.pgHostels => 'Reserve PG',
      CustomerSection.lodgeRooms => 'Book Stay',
      CustomerSection.institutesClasses => 'Institute Listing',
      _ => 'Book Hall Slot',
    };
  }

  /// Owner phone stays hidden on bookable listings until a confirmed/paid booking.
  /// Institute listings keep Call / WhatsApp available.
  static bool canRevealOwnerContact({
    required CustomerSection? section,
    required bool hasConfirmedPaidBooking,
  }) {
    if (section == CustomerSection.institutesClasses) return true;
    return hasConfirmedPaidBooking;
  }

  static List<CustomerDetailField> requiredCustomerFields(
    CustomerSection? section,
  ) {
    return switch (section) {
      CustomerSection.functionHalls => const [
        CustomerDetailField.fullName,
        CustomerDetailField.phone,
        CustomerDetailField.eventType,
      ],
      CustomerSection.lodgeRooms => const [
        CustomerDetailField.fullName,
        CustomerDetailField.phone,
      ],
      CustomerSection.pgHostels => const [
        CustomerDetailField.fullName,
        CustomerDetailField.phone,
        CustomerDetailField.idNumber,
        CustomerDetailField.address,
      ],
      CustomerSection.institutesClasses || null => const [],
    };
  }

  static bool matchesAmenities(Venue venue, Set<String> amenityIds) {
    if (amenityIds.isEmpty) return true;
    final section = sectionForVenue(venue);
    if (section == null) return false;
    final options = amenityFilters(section);
    final hay = _haystack(venue);
    return amenityIds.every((id) {
      final option = options.where((o) => o.id == id);
      if (option.isEmpty) return true;
      return option.first.keywords.any(hay.contains);
    });
  }

  static bool _matchesCategory(
    Venue venue,
    CustomerSection section,
    String categoryId,
  ) {
    final slug = venue.category?.slug.toLowerCase() ?? '';
    final hay = _haystack(venue);
    return switch (section) {
      CustomerSection.functionHalls => switch (categoryId) {
        'marriage_hall' =>
          slug == 'marriage_hall' ||
              hay.contains('wedding') ||
              hay.contains('marriage'),
        'convention_center' =>
          slug == 'convention_center' || hay.contains('convention'),
        'banquet_hall' =>
          slug == 'banquet_hall' ||
              slug == 'party_hall' ||
              hay.contains('banquet'),
        'community_hall' => slug == 'community_hall' || hay.contains('community'),
        'govt_hall' => slug == 'govt_hall' || hay.contains('government'),
        'party_lawn' => slug == 'party_lawn' || hay.contains('lawn'),
        _ => slug == categoryId || slug.contains(categoryId),
      },
      CustomerSection.lodgeRooms => switch (categoryId) {
        'hotel' => slug.contains('hotel'),
        'lodge' => slug.contains('lodge') || hay.contains('lodge'),
        'guest_house' => hay.contains('guest'),
        'hourly_room' => hay.contains('flexi') || hay.contains('hour'),
        'resort' => hay.contains('resort') || hay.contains('homestay'),
        _ => slug == categoryId || slug.contains(categoryId),
      },
      CustomerSection.pgHostels => switch (categoryId) {
        'gents_pg' => hay.contains('gent') || hay.contains('men'),
        'ladies_pg' =>
          hay.contains('lad') ||
              hay.contains('women') ||
              hay.contains('female'),
        'student_hostel' => hay.contains('hostel') || hay.contains('student'),
        'co_living' => hay.contains('co-living') || hay.contains('coliving'),
        'single_room' => hay.contains('single'),
        _ => slug == categoryId || slug.contains(categoryId),
      },
      CustomerSection.institutesClasses => switch (categoryId) {
        'coaching' =>
          hay.contains('coaching') ||
              hay.contains('tuition') ||
              hay.contains('academic'),
        'computer_it' =>
          hay.contains('computer') ||
              hay.contains('coding') ||
              hay.contains('stem'),
        'dance_academy' => hay.contains('dance'),
        'music_class' => hay.contains('music') || hay.contains('vocal'),
        'sports_academy' =>
          hay.contains('sport') ||
              hay.contains('badminton') ||
              hay.contains('turf'),
        _ => slug == categoryId || hay.contains(categoryId.replaceAll('_', ' ')),
      },
    };
  }

  static String _haystack(Venue venue) {
    return [
      venue.name,
      venue.description,
      venue.category?.name ?? '',
      venue.category?.slug ?? '',
      ...venue.facilities.map((f) => f.facility),
    ].join(' ').toLowerCase();
  }

  /// Categories an owner may pick (excludes the customer "All" chip).
  static List<CustomerSectionCategory> ownerCategories(
    CustomerSection section,
  ) {
    return section.categories.where((c) => c.id != 'all').toList();
  }

  /// DB slug that keeps the listing inside [section].
  ///
  /// Exact catalog ids are tried first by [resolveDbCategory]. These
  /// fallbacks are rows from migrations `0002` and `0019` — not seed_dev.
  static String persistableCategorySlug(
    CustomerSection section,
    String catalogCategoryId,
  ) {
    final selected = catalogCategoryId.toLowerCase();
    return switch (section) {
      CustomerSection.functionHalls => switch (selected) {
        'marriage_hall' => 'marriage_hall',
        'convention_center' => 'convention_center',
        'banquet_hall' => 'banquet_hall',
        'community_hall' => 'community_hall',
        'govt_hall' => 'govt_hall',
        'party_lawn' => 'party_lawn',
        _ => 'function_hall',
      },
      CustomerSection.lodgeRooms => switch (selected) {
        'lodge' => 'lodge',
        'guest_house' => 'guest_house',
        'hourly_room' => 'hourly_room',
        'resort' => 'resort',
        _ => 'hotel_stay',
      },
      CustomerSection.pgHostels => switch (selected) {
        'gents_pg' => 'gents_pg',
        'ladies_pg' => 'ladies_pg',
        'student_hostel' => 'student_hostel',
        'co_living' => 'co_living',
        _ => 'pg_coliving',
      },
      CustomerSection.institutesClasses => switch (selected) {
        'coaching' => 'coaching',
        'computer_it' => 'computer_it',
        'dance_academy' => 'dance_academy',
        'music_class' => 'music_class',
        'sports_academy' => 'sports_academy',
        _ => 'sports_ground',
      },
    };
  }

  static bool slugBelongsToSection(CustomerSection section, String? slug) {
    if (slug == null || slug.isEmpty) return false;
    return fromAny(slug) == section;
  }

  /// Picks a `venue_categories` row that belongs to [section].
  ///
  /// Throws if the database has no compatible slug — never falls back
  /// to a different customer section.
  static VenueCategory resolveDbCategory({
    required List<VenueCategory> dbCategories,
    required CustomerSection section,
    required String catalogCategoryId,
  }) {
    VenueCategory? find(String slug) {
      final lower = slug.toLowerCase();
      for (final category in dbCategories) {
        if (category.slug.toLowerCase() == lower) return category;
      }
      return null;
    }

    final candidates = <String>[
      catalogCategoryId,
      persistableCategorySlug(section, catalogCategoryId),
      ...section.categorySlugs,
    ];
    final seen = <String>{};
    for (final slug in candidates) {
      final key = slug.toLowerCase();
      if (!seen.add(key)) continue;
      final match = find(key);
      if (match != null && fromAny(match.slug) == section) {
        return match;
      }
    }
    // Base migration 0002 has meeting_room but no lodge/PG slugs.
    // Never reuse a Function Hall / Institute slug.
    if (section == CustomerSection.lodgeRooms ||
        section == CustomerSection.pgHostels) {
      final unmapped = find('meeting_room');
      if (unmapped != null && fromAny(unmapped.slug) == null) {
        return unmapped;
      }
    }
    throw StateError(
      'No ${section.title} category is configured. Pick a category from this section.',
    );
  }
}

enum CustomerDetailField { fullName, phone, eventType, idNumber, address }

class CustomerBookingDetails {
  const CustomerBookingDetails({
    this.fullName = '',
    this.phone = '',
    this.eventType = '',
    this.idNumber = '',
    this.address = '',
  });

  final String fullName;
  final String phone;
  final String eventType;
  final String idNumber;
  final String address;

  CustomerBookingDetails copyWith({
    String? fullName,
    String? phone,
    String? eventType,
    String? idNumber,
    String? address,
  }) {
    return CustomerBookingDetails(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      eventType: eventType ?? this.eventType,
      idNumber: idNumber ?? this.idNumber,
      address: address ?? this.address,
    );
  }
}
