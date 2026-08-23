import '../../venues/domain/venue.dart';

class ModeratedListing {
  const ModeratedListing({
    required this.venue,
    this.status = 'draft',
    this.rejectionReason = '',
  });

  final Venue venue;
  final String status;
  final String rejectionReason;

  factory ModeratedListing.fromJson(Map<String, dynamic> json) {
    return ModeratedListing(
      venue: Venue.fromJson(json),
      status: (json['listing_status'] as String?) ?? _inferredStatus(json),
      rejectionReason: json['listing_rejection_reason'] as String? ?? '',
    );
  }

  static String _inferredStatus(Map<String, dynamic> json) {
    final active = json['is_active'] as bool? ?? false;
    final verified = json['is_verified'] as bool? ?? false;
    if (active && verified) return 'published';
    if (active) return 'pending_approval';
    return 'draft';
  }
}

class OversightRow {
  const OversightRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    this.amount,
    this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final double? amount;
  final DateTime? createdAt;
}
