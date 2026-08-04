import '../../../core/theme/prototype_visuals.dart';

/// Homepage / content CMS models backed by remote config tables.
class HomepageSection {
  const HomepageSection({
    required this.id,
    required this.sectionKey,
    required this.title,
    this.emoji = '',
    this.sortOrder = 0,
    this.isVisible = true,
    this.config = const {},
  });

  final String id;
  final String sectionKey;
  final String title;
  final String emoji;
  final int sortOrder;
  final bool isVisible;
  final Map<String, dynamic> config;

  factory HomepageSection.fromJson(Map<String, dynamic> json) =>
      HomepageSection(
        id: json['id'] as String? ?? '',
        sectionKey: json['section_key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isVisible: json['is_visible'] as bool? ?? true,
        config: json['config'] is Map
            ? Map<String, dynamic>.from(json['config'] as Map)
            : const {},
      );

  String get displayTitle =>
      emoji.trim().isEmpty ? title : '$emoji $title';
}

class HomeCategoryTile {
  const HomeCategoryTile({
    required this.id,
    required this.tileKey,
    required this.label,
    required this.emoji,
    required this.routeTarget,
    this.sortOrder = 0,
    this.isVisible = true,
  });

  final String id;
  final String tileKey;
  final String label;
  final String emoji;
  final String routeTarget;
  final int sortOrder;
  final bool isVisible;

  factory HomeCategoryTile.fromJson(Map<String, dynamic> json) {
    final tileKey = json['tile_key'] as String? ?? '';
    final rawEmoji = (json['emoji'] as String? ?? '').trim();
    return HomeCategoryTile(
      id: json['id'] as String? ?? '',
      tileKey: tileKey,
      label: json['label'] as String? ?? '',
      // Coalesce blank DB icons to prototype CATS map by slug.
      emoji: PrototypeVisuals.emojiForCategorySlug(tileKey, icon: rawEmoji),
      routeTarget: json['route_target'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isVisible: json['is_visible'] as bool? ?? true,
    );
  }
}

class HomepageContentConfig {
  const HomepageContentConfig({
    this.sections = const [],
    this.categoryTiles = const [],
    this.venueCategories = const [],
    this.homeBanner = const {},
    this.featuredOffer = const {},
    this.defaultCommissionRate = 10,
  });

  final List<HomepageSection> sections;
  final List<HomeCategoryTile> categoryTiles;
  final List<Map<String, dynamic>> venueCategories;
  final Map<String, dynamic> homeBanner;
  final Map<String, dynamic> featuredOffer;
  final double defaultCommissionRate;

  factory HomepageContentConfig.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final tilesRaw = json['category_tiles'];
    final catsRaw = json['venue_categories'];
    final commission = json['default_commission_rate'];
    return HomepageContentConfig(
      sections: _mapList(sectionsRaw, HomepageSection.fromJson),
      categoryTiles: _mapList(tilesRaw, HomeCategoryTile.fromJson),
      venueCategories: _mapList(catsRaw, (m) => m),
      homeBanner: json['home_banner'] is Map
          ? Map<String, dynamic>.from(json['home_banner'] as Map)
          : const {},
      featuredOffer: json['featured_offer'] is Map
          ? Map<String, dynamic>.from(json['featured_offer'] as Map)
          : const {},
      defaultCommissionRate: commission is Map
          ? (commission['rate'] as num?)?.toDouble() ?? 10
          : 10,
    );
  }

  static List<T> _mapList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) map,
  ) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) map(Map<String, dynamic>.from(item)),
    ];
  }

  bool isSectionVisible(String key) {
    for (final s in sections) {
      if (s.sectionKey == key) return s.isVisible;
    }
    return true;
  }

  HomepageSection? section(String key) {
    for (final s in sections) {
      if (s.sectionKey == key) return s;
    }
    return null;
  }
}

class AdminContentVenue {
  const AdminContentVenue({
    required this.id,
    required this.name,
    this.city = '',
    this.state = '',
    this.description = '',
    this.phone = '',
    this.website = '',
    this.addressLine1 = '',
    this.pricingBaseAmount = 0,
    this.taxRate = 18,
    this.capacity = 0,
    this.latitude = 0,
    this.longitude = 0,
    this.isFeatured = false,
    this.isActive = true,
    this.ownerVerified = false,
    this.offerText = '',
    this.offerPercent,
    this.foodOptions = '',
    this.rules = '',
  });

  final String id;
  final String name;
  final String city;
  final String state;
  final String description;
  final String phone;
  final String website;
  final String addressLine1;
  final double pricingBaseAmount;
  final double taxRate;
  final int capacity;
  final double latitude;
  final double longitude;
  final bool isFeatured;
  final bool isActive;
  final bool ownerVerified;
  final String offerText;
  final double? offerPercent;
  final String foodOptions;
  final String rules;

  factory AdminContentVenue.fromJson(Map<String, dynamic> json) =>
      AdminContentVenue(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        description: json['description'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        website: json['website'] as String? ?? '',
        addressLine1: json['address_line1'] as String? ?? '',
        pricingBaseAmount:
            (json['pricing_base_amount'] as num?)?.toDouble() ?? 0,
        taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 18,
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        isFeatured: json['is_featured'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        ownerVerified: json['owner_verified'] as bool? ?? false,
        offerText: json['offer_text'] as String? ?? '',
        offerPercent: (json['offer_percent'] as num?)?.toDouble(),
        foodOptions: json['food_options'] as String? ?? '',
        rules: json['rules'] as String? ?? '',
      );
}
