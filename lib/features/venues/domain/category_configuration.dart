import 'package:flutter/material.dart';

import 'venue.dart';

/// Database-backed category configuration.
///
/// New venue categories are added through `venue_categories` + metadata.
/// Clients must not switch on individual category slugs for behaviour.
class CategoryConfiguration {
  const CategoryConfiguration({
    required this.id,
    required this.slug,
    required this.name,
    this.icon = '',
    this.imageUrl = '',
    this.sectionId = '',
    this.visible = true,
    this.bookable = true,
    this.bookingMode = 'instant',
    this.pricingMode = 'slot',
    this.availabilityMode = 'slots',
    this.customerAction = 'Book Now',
    this.mediaConfiguration = 'images',
    this.sortOrder = 0,
    this.localizedNames = const {},
    this.aliases = const [],
    this.searchAliases = const [],
    this.aiAliases = const [],
    this.requiredFields = const [],
    this.optionalFields = const [],
    this.filters = const [],
    this.amenities = const [],
    this.ownerFields = const [],
    this.searchable = true,
    this.offerVisible = true,
    this.homeVisible = true,
    this.themeColor = '',
    this.bookingRequiredFields = const [],
    this.bookingOptionalFields = const [],
    this.registrationRequired = false,
    this.kycRequired = false,
    this.registrationRequiredFields = const [],
    this.registrationOptionalFields = const [],
    this.invoiceVisible = true,
    this.notificationVisible = true,
    this.qrVisible = true,
  });

  final String id;
  final String slug;
  final String name;
  final String icon;
  final String imageUrl;
  final String sectionId;
  final bool visible;
  final bool bookable;
  final String bookingMode;
  final String pricingMode;
  final String availabilityMode;
  final String customerAction;
  final String mediaConfiguration;
  final int sortOrder;
  final Map<String, String> localizedNames;
  final List<String> aliases;
  final List<String> searchAliases;
  final List<String> aiAliases;
  final List<String> requiredFields;
  final List<String> optionalFields;
  final List<String> filters;
  final List<String> amenities;
  final List<String> ownerFields;
  final bool searchable;
  final bool offerVisible;
  final bool homeVisible;
  final String themeColor;
  final List<String> bookingRequiredFields;
  final List<String> bookingOptionalFields;
  final bool registrationRequired;
  final bool kycRequired;
  final List<String> registrationRequiredFields;
  final List<String> registrationOptionalFields;
  final bool invoiceVisible;
  final bool notificationVisible;
  final bool qrVisible;

  bool get isListingOnly => !bookable || bookingMode == 'listing_only';

  Color? get accentColor {
    final hex = themeColor.trim().replaceFirst('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  /// Localized name with English fallback, then [name].
  String localizedName(String languageCode) =>
      localizedNames[languageCode] ?? localizedNames['en'] ?? name;

  List<String> get allAliases {
    final values = <String>{
      slug,
      name,
      ...aliases,
      ...searchAliases,
      ...aiAliases,
      ...localizedNames.values,
    };
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList(growable: false);
  }

  CategoryConfiguration copyWith({
    List<String>? requiredFields,
    List<String>? optionalFields,
    List<String>? ownerFields,
    List<String>? filters,
    List<String>? amenities,
    bool? searchable,
    bool? offerVisible,
    bool? homeVisible,
    String? themeColor,
    List<String>? bookingRequiredFields,
    List<String>? bookingOptionalFields,
    bool? registrationRequired,
    bool? kycRequired,
    List<String>? registrationRequiredFields,
    List<String>? registrationOptionalFields,
    bool? invoiceVisible,
    bool? notificationVisible,
    bool? qrVisible,
  }) {
    return CategoryConfiguration(
      id: id,
      slug: slug,
      name: name,
      icon: icon,
      imageUrl: imageUrl,
      sectionId: sectionId,
      visible: visible,
      bookable: bookable,
      bookingMode: bookingMode,
      pricingMode: pricingMode,
      availabilityMode: availabilityMode,
      customerAction: customerAction,
      mediaConfiguration: mediaConfiguration,
      sortOrder: sortOrder,
      localizedNames: localizedNames,
      aliases: aliases,
      searchAliases: searchAliases,
      aiAliases: aiAliases,
      requiredFields: requiredFields ?? this.requiredFields,
      optionalFields: optionalFields ?? this.optionalFields,
      filters: filters ?? this.filters,
      amenities: amenities ?? this.amenities,
      ownerFields: ownerFields ?? this.ownerFields,
      searchable: searchable ?? this.searchable,
      offerVisible: offerVisible ?? this.offerVisible,
      homeVisible: homeVisible ?? this.homeVisible,
      themeColor: themeColor ?? this.themeColor,
      bookingRequiredFields:
          bookingRequiredFields ?? this.bookingRequiredFields,
      bookingOptionalFields:
          bookingOptionalFields ?? this.bookingOptionalFields,
      registrationRequired: registrationRequired ?? this.registrationRequired,
      kycRequired: kycRequired ?? this.kycRequired,
      registrationRequiredFields:
          registrationRequiredFields ?? this.registrationRequiredFields,
      registrationOptionalFields:
          registrationOptionalFields ?? this.registrationOptionalFields,
      invoiceVisible: invoiceVisible ?? this.invoiceVisible,
      notificationVisible: notificationVisible ?? this.notificationVisible,
      qrVisible: qrVisible ?? this.qrVisible,
    );
  }

  Map<String, dynamic> toMetadata() => {
    'section': sectionId,
    'active': visible,
    'bookable': bookable,
    'booking_mode': bookingMode,
    'customer_action_label': customerAction,
    'pricing_mode': pricingMode,
    'availability_mode': availabilityMode,
    'media_configuration': mediaConfiguration,
    'aliases': aliases,
    'search_aliases': searchAliases,
    'ai_aliases': aiAliases,
    'localized_names': localizedNames,
    'required_fields': requiredFields,
    'optional_fields': optionalFields,
    'filters': filters,
    'amenities': amenities,
    'owner_fields': ownerFields,
    'sort_order': sortOrder,
    'searchable': searchable,
    'offer_visible': offerVisible,
    'home_visible': homeVisible,
    'booking_required_fields': bookingRequiredFields,
    'booking_optional_fields': bookingOptionalFields,
    'registration_required': registrationRequired,
    'kyc_required': kycRequired,
    'registration_required_fields': registrationRequiredFields,
    'registration_optional_fields': registrationOptionalFields,
    'invoice_visible': invoiceVisible,
    'notification_visible': notificationVisible,
    'qr_visible': qrVisible,
    if (imageUrl.isNotEmpty) 'image': imageUrl,
    if (themeColor.isNotEmpty) 'theme_color': themeColor,
  };

  factory CategoryConfiguration.fromCategory(VenueCategory category) {
    final meta = category.metadata;
    List<String> stringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    Map<String, String> stringMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return const {};
    }

    bool flag(String key, bool fallback) {
      final value = meta[key];
      if (value is bool) return value;
      return fallback;
    }

    final normalizedSlug = category.slug.toLowerCase();
    final pgFamily = {
      'pg_coliving',
      'pg_hostel',
      'hostel',
      'co_living',
      'gents_pg',
      'ladies_pg',
      'student_hostel',
    }.contains(normalizedSlug);
    final instituteFamily = {
      'institute',
      'coaching',
      'computer_it',
      'dance_academy',
      'music_class',
      'sports_academy',
      'sports_ground',
    }.contains(normalizedSlug);

    return CategoryConfiguration(
      id: category.id,
      slug: category.slug,
      name: category.name,
      icon: category.icon,
      imageUrl: (meta['image'] ?? meta['image_url'] ?? '').toString(),
      sectionId: (meta['section'] ?? '').toString(),
      visible: flag('active', true) && flag('visible', true),
      bookable: flag('bookable', true),
      bookingMode: (meta['booking_mode'] ?? 'instant').toString(),
      pricingMode: (meta['pricing_mode'] ?? 'slot').toString(),
      availabilityMode: (meta['availability_mode'] ?? 'slots').toString(),
      customerAction: (meta['customer_action_label'] ?? 'Book Now').toString(),
      mediaConfiguration: (meta['media_configuration'] ?? 'images').toString(),
      sortOrder: (meta['sort_order'] as num?)?.toInt() ?? 0,
      localizedNames: stringMap(meta['localized_names']),
      aliases: stringList(meta['aliases']),
      searchAliases: stringList(meta['search_aliases']),
      aiAliases: stringList(meta['ai_aliases']),
      requiredFields: stringList(meta['required_fields']),
      optionalFields: stringList(meta['optional_fields']),
      filters: stringList(meta['filter_configuration'] ?? meta['filters']),
      amenities: stringList(meta['amenity_configuration'] ?? meta['amenities']),
      ownerFields: stringList(meta['owner_fields']),
      searchable: flag('searchable', true),
      offerVisible: flag('offer_visible', true),
      homeVisible: flag('home_visible', true),
      themeColor: (meta['theme_color'] ?? meta['color'] ?? '').toString(),
      bookingRequiredFields: stringList(meta['booking_required_fields']),
      bookingOptionalFields: stringList(meta['booking_optional_fields']),
      registrationRequired: flag('registration_required', pgFamily || instituteFamily),
      kycRequired: flag('kyc_required', pgFamily),
      registrationRequiredFields: stringList(
        meta['registration_required_fields'],
      ),
      registrationOptionalFields: stringList(
        meta['registration_optional_fields'],
      ),
      invoiceVisible: flag('invoice_visible', true),
      notificationVisible: flag('notification_visible', true),
      qrVisible: flag('qr_visible', true),
    );
  }
}

class AppSectionConfig {
  const AppSectionConfig({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.emoji = '',
    this.imageUrl = '',
    this.sortOrder = 0,
    this.visible = true,
    this.bookable = true,
    this.localizedTitles = const {},
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final String imageUrl;
  final int sortOrder;
  final bool visible;
  final bool bookable;
  final Map<String, String> localizedTitles;

  String localizedTitle(String languageCode) =>
      localizedTitles[languageCode] ?? localizedTitles['en'] ?? title;

  factory AppSectionConfig.fromJson(Map<String, dynamic> json) {
    final localized = json['localized_titles'];
    return AppSectionConfig(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      visible: json['is_visible'] as bool? ?? true,
      bookable: json['is_bookable'] as bool? ?? true,
      localizedTitles: localized is Map
          ? localized.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }
}

/// Resolves natural-language tokens to a category without per-slug switches.
class CategoryAliasIndex {
  CategoryAliasIndex(this.configurations);

  final List<CategoryConfiguration> configurations;

  CategoryConfiguration? match(String utterance) {
    final text = utterance.toLowerCase();
    CategoryConfiguration? best;
    var bestScore = 0;
    for (final config in configurations) {
      if (!config.visible || !config.searchable) continue;
      for (final alias in config.allAliases) {
        final needle = alias.toLowerCase();
        if (needle.length < 3) continue;
        if (!text.contains(needle)) continue;
        if (needle.length > bestScore) {
          best = config;
          bestScore = needle.length;
        }
      }
    }
    return best;
  }
}
