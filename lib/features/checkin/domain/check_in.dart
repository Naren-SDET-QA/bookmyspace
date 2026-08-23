class CheckInResult {
  const CheckInResult({
    required this.ok,
    required this.bookingId,
    this.checkInId = '',
    this.alreadyCheckedIn = false,
    this.message = '',
  });

  final bool ok;
  final String bookingId;
  final String checkInId;
  final bool alreadyCheckedIn;
  final String message;

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
    ok: json['ok'] as bool? ?? false,
    bookingId: json['booking_id'] as String? ?? '',
    checkInId: json['check_in_id'] as String? ?? '',
    alreadyCheckedIn: json['already_checked_in'] as bool? ?? false,
  );
}

abstract interface class CheckInRepository {
  Future<CheckInResult> checkIn({
    required String code,
    String method = 'code',
  });
}
