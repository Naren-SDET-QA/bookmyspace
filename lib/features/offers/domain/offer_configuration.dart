import '../../venues/domain/category_configuration.dart';

/// Generic offer/promotion. Maps onto existing `coupons` rows plus metadata.
class OfferConfiguration {
  const OfferConfiguration({
    required this.id,
    required this.title,
    this.description = '',
    this.enabled = true,
    this.discountType = 'percentage',
    this.discountValue = 0,
    this.startsAt,
    this.endsAt,
    this.categoryIds = const [],
    this.listingIds = const [],
    this.displayVisible = true,
  });

  final String id;
  final String title;
  final String description;
  final bool enabled;
  final String discountType;
  final num discountValue;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<String> categoryIds;
  final List<String> listingIds;
  final bool displayVisible;

  bool get isPercentage => discountType == 'percentage';

  bool visibleFor(CategoryConfiguration category, {DateTime? now}) {
    return enabled &&
        displayVisible &&
        category.offerVisible &&
        isValidAt(now ?? DateTime.now()) &&
        appliesTo(categoryId: category.id);
  }

  bool isValidAt(DateTime now) =>
      (startsAt == null || !now.isBefore(startsAt!)) &&
      (endsAt == null || !now.isAfter(endsAt!));

  bool appliesTo({String? categoryId, String? listingId}) {
    if (!enabled) return false;
    if (categoryIds.isEmpty && listingIds.isEmpty) return true;
    if (listingId != null && listingIds.contains(listingId)) return true;
    if (categoryId != null && categoryIds.contains(categoryId)) return true;
    return false;
  }

  factory OfferConfiguration.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};
    List<String> ids(dynamic raw) {
      if (raw is List) {
        return raw
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const [];
    }

    DateTime? time(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    return OfferConfiguration(
      id: json['id'] as String? ?? '',
      title:
          (metadata['title'] as String?) ??
          json['description'] as String? ??
          json['code'] as String? ??
          '',
      description: json['description'] as String? ?? '',
      enabled: json['is_active'] as bool? ?? true,
      discountType: json['discount_type'] as String? ?? 'percentage',
      discountValue: json['discount_value'] as num? ?? 0,
      startsAt: time(json['starts_at']),
      endsAt: time(json['ends_at']),
      categoryIds: ids(metadata['category_ids']),
      listingIds: ids(metadata['listing_ids']),
      displayVisible:
          metadata['visible'] != false && metadata['display_visible'] != false,
    );
  }
}

abstract interface class OfferRepository {
  Future<List<OfferConfiguration>> listActive({int limit = 50});
}
