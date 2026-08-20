class ModuleSubmission {
  const ModuleSubmission({
    required this.id,
    required this.moduleKey,
    required this.status,
    this.venueId,
    this.bookingId,
    this.rejectionReason,
    this.createdAt,
  });
  final String id;
  final String moduleKey;
  final String status;
  final String? venueId;
  final String? bookingId;
  final String? rejectionReason;
  final DateTime? createdAt;

  factory ModuleSubmission.fromJson(Map<String, dynamic> json) =>
      ModuleSubmission(
        id: json['id'] as String? ?? '',
        moduleKey: json['module_key'] as String? ?? '',
        status: json['status'] as String? ?? 'submitted',
        venueId: json['venue_id'] as String?,
        bookingId: json['booking_id'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}
