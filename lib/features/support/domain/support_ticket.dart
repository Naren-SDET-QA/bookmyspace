enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed;

  static TicketStatus fromDb(String value) => switch (value) {
    'open' => TicketStatus.open,
    'in_progress' => TicketStatus.inProgress,
    'resolved' => TicketStatus.resolved,
    'closed' => TicketStatus.closed,
    _ => TicketStatus.open,
  };

  String get dbValue => name;
}

enum TicketPriority {
  low,
  medium,
  high,
  urgent;

  static TicketPriority fromDb(String value) => switch (value) {
    'low' => TicketPriority.low,
    'medium' => TicketPriority.medium,
    'high' => TicketPriority.high,
    'urgent' => TicketPriority.urgent,
    _ => TicketPriority.medium,
  };

  String get dbValue => name;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.category,
    this.adminReply,
    this.adminName = '',
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String subject;
  final String description;
  final TicketStatus status;
  final TicketPriority priority;
  final String category;
  final String? adminReply;
  final String adminName;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isResolved =>
      status == TicketStatus.resolved || status == TicketStatus.closed;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    description: json['description'] as String? ?? '',
    status: TicketStatus.fromDb(json['status'] as String? ?? ''),
    priority: TicketPriority.fromDb(json['priority'] as String? ?? ''),
    category: json['category'] as String? ?? 'general',
    adminReply: json['admin_reply'] as String?,
    adminName: json['admin_name'] as String? ?? '',
    resolvedAt: json['resolved_at'] != null
        ? DateTime.tryParse(json['resolved_at'] as String? ?? '')
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String? ?? '')
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String? ?? '')
        : null,
  );
}
