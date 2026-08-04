enum NotificationType {
  requestSubmitted,
  bookingApproved,
  bookingRejected,
  bookingConfirmed,
  bookingCancelled,
  bookingReminder,
  paymentRequired,
  paymentSuccess,
  paymentFailed,
  ownerBooking,
  paymentReceived,
  refundProcessed,
  system,
  supportReply,
  admin;

  static NotificationType fromDb(String value) => switch (value) {
    'request_submitted' => NotificationType.requestSubmitted,
    'booking_approved' => NotificationType.bookingApproved,
    'booking_rejected' => NotificationType.bookingRejected,
    'booking_confirmed' => NotificationType.bookingConfirmed,
    'booking_cancelled' => NotificationType.bookingCancelled,
    'booking_reminder' => NotificationType.bookingReminder,
    'payment_required' => NotificationType.paymentRequired,
    'payment_success' => NotificationType.paymentSuccess,
    'payment_failed' => NotificationType.paymentFailed,
    'owner_new_request' ||
    'owner_booking_confirmed' ||
    'owner_booking_cancelled' ||
    'owner_booking_reminder' ||
    'owner_payment_received' ||
    'owner_payment_failed' => NotificationType.ownerBooking,
    'payment_received' => NotificationType.paymentReceived,
    'refund_processed' => NotificationType.refundProcessed,
    'system' => NotificationType.system,
    'support_reply' => NotificationType.supportReply,
    'admin' => NotificationType.admin,
    _ => NotificationType.system,
  };

  String get dbValue => name;
}

class Notification {
  const Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    this.read = false,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? readAt;
  final DateTime? createdAt;

  String? get targetRoute => data['target_route'] as String?;
  String? get bookingId => data['booking_id']?.toString();

  factory Notification.fromJson(Map<String, dynamic> json) => Notification(
    id: json['id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    type: NotificationType.fromDb(json['type'] as String? ?? ''),
    data: json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : const {},
    read: json['read'] as bool? ?? false,
    readAt: json['read_at'] != null
        ? DateTime.tryParse(json['read_at'] as String? ?? '')
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String? ?? '')
        : null,
  );
}

class NotificationPreferences {
  const NotificationPreferences({
    this.bookingUpdates = true,
    this.paymentUpdates = true,
    this.reminders = true,
    this.inApp = true,
  });

  final bool bookingUpdates;
  final bool paymentUpdates;
  final bool reminders;
  final bool inApp;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        bookingUpdates: json['booking_updates'] as bool? ?? true,
        paymentUpdates: json['payment_updates'] as bool? ?? true,
        reminders: json['reminders'] as bool? ?? true,
        inApp: json['in_app'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'booking_updates': bookingUpdates,
    'payment_updates': paymentUpdates,
    'reminders': reminders,
    'in_app': inApp,
  };

  NotificationPreferences copyWith({
    bool? bookingUpdates,
    bool? paymentUpdates,
    bool? reminders,
    bool? inApp,
  }) => NotificationPreferences(
    bookingUpdates: bookingUpdates ?? this.bookingUpdates,
    paymentUpdates: paymentUpdates ?? this.paymentUpdates,
    reminders: reminders ?? this.reminders,
    inApp: inApp ?? this.inApp,
  );
}
