class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.details = const {},
    this.ipAddress,
    this.createdAt,
  });

  final String id;
  final String actorId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> details;
  final String? ipAddress;
  final DateTime? createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: json['id'] as String? ?? '',
    actorId: json['actor_id'] as String? ?? '',
    action: json['action'] as String? ?? '',
    entityType: json['entity_type'] as String? ?? '',
    entityId: json['entity_id'] as String?,
    details: json['details'] is Map
        ? Map<String, dynamic>.from(json['details'] as Map)
        : const {},
    ipAddress: json['ip_address'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String? ?? '')
        : null,
  );
}
