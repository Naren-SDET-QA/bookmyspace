enum NotificationType {
  bookingConfirmed,
  bookingCancelled,
  paymentReceived,
  refundProcessed,
  system,
  supportReply,
  admin;

  static NotificationType fromDb(String value) => switch (value) {
    'booking_confirmed' => NotificationType.bookingConfirmed,
    'booking_cancelled' => NotificationType.bookingCancelled,
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
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? readAt;

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
  );
}