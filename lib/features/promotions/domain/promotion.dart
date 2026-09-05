/// Generic, display-only promotion. Financial discounts are never calculated
/// by this model; booking pricing remains server-authoritative.
class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    this.shortDescription = '',
    this.description = '',
    this.bannerMediaId,
    this.active = false,
    this.startAt,
    this.endAt,
    this.priority = 0,
    this.sortOrder = 0,
    this.ctaText = '',
    this.ctaAction = '',
    this.offerType = 'promotional_text',
    this.discountType,
    this.discountValue,
    this.categoryIds = const [],
    this.venueIds = const [],
    this.accentColor,
    this.backgroundColor,
    this.textColor,
    this.badge,
    this.icon,
  });

  final String id;
  final String title;
  final String shortDescription;
  final String description;
  final String? bannerMediaId;
  final bool active;
  final DateTime? startAt;
  final DateTime? endAt;
  final int priority;
  final int sortOrder;
  final String ctaText;
  final String ctaAction;
  final String offerType;
  final String? discountType;
  final num? discountValue;
  final List<String> categoryIds;
  final List<String> venueIds;
  final String? accentColor;
  final String? backgroundColor;
  final String? textColor;
  final String? badge;
  final String? icon;

  bool isVisibleAt(DateTime now) =>
      active &&
      (startAt == null || !now.isBefore(startAt!)) &&
      (endAt == null || now.isBefore(endAt!));

  bool targets({String? categoryId, String? venueId}) {
    if (categoryIds.isEmpty && venueIds.isEmpty) return true;
    return (categoryId != null && categoryIds.contains(categoryId)) ||
        (venueId != null && venueIds.contains(venueId));
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    List<String> ids(dynamic raw, String key) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((row) => row[key]?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    }

    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    return Promotion(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      shortDescription: json['short_description'] as String? ?? '',
      description: json['description'] as String? ?? '',
      bannerMediaId: json['banner_media_id'] as String?,
      active: json['active'] as bool? ?? false,
      startAt: date(json['start_at']),
      endAt: date(json['end_at']),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      ctaText: json['cta_text'] as String? ?? '',
      ctaAction: json['cta_action'] as String? ?? '',
      offerType: json['offer_type'] as String? ?? 'promotional_text',
      discountType: json['discount_type'] as String?,
      discountValue: json['discount_value'] as num?,
      categoryIds: ids(json['promotion_categories'], 'category_id'),
      venueIds: ids(json['promotion_venues'], 'venue_id'),
      accentColor: json['accent_color'] as String?,
      backgroundColor: json['background_color'] as String?,
      textColor: json['text_color'] as String?,
      badge: json['badge'] as String?,
      icon: json['icon'] as String?,
    );
  }
}
