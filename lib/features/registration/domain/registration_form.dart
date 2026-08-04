enum RegistrationFieldType {
  text,
  number,
  phone,
  email,
  date,
  dropdown,
  checkbox,
  address,
  photo,
  file,
  document,
  custom,
}

enum RegistrationCollectionStage { preBooking, postBooking, checkIn }

enum RegistrationParticipantScope { primary, all }

class RegistrationFieldDefinition {
  const RegistrationFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.enabled = true,
    this.required = false,
    this.order = 0,
    this.options = const [],
    this.validation = const {},
    this.participantScope = RegistrationParticipantScope.primary,
    this.collectionStage = RegistrationCollectionStage.preBooking,
  });
  final String key, label;
  final RegistrationFieldType type;
  final bool enabled, required;
  final int order;
  final List<String> options;
  final Map<String, dynamic> validation;
  final RegistrationParticipantScope participantScope;
  final RegistrationCollectionStage collectionStage;
  factory RegistrationFieldDefinition.fromJson(Map<String, dynamic> j) =>
      RegistrationFieldDefinition(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        type: RegistrationFieldType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => RegistrationFieldType.custom,
        ),
        enabled: j['enabled'] as bool? ?? true,
        required: j['required'] as bool? ?? false,
        order: (j['order'] as num?)?.toInt() ?? 0,
        options: (j['options'] as List?)?.map((e) => '$e').toList() ?? const [],
        validation: Map<String, dynamic>.from(
          j['validation'] as Map? ?? const {},
        ),
        participantScope: RegistrationParticipantScope.values.firstWhere(
          (e) => e.name == j['participant_scope'],
          orElse: () => RegistrationParticipantScope.primary,
        ),
        collectionStage: RegistrationCollectionStage.values.firstWhere(
          (e) => _stage(e) == j['collection_stage'],
          orElse: () => RegistrationCollectionStage.preBooking,
        ),
      );
  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'enabled': enabled,
    'required': required,
    'order': order,
    'options': options,
    'validation': validation,
    'participant_scope': participantScope.name,
    'collection_stage': _stage(collectionStage),
  };
  RegistrationFieldDefinition copyWith({
    String? key,
    String? label,
    RegistrationFieldType? type,
    bool? enabled,
    bool? required,
    int? order,
    List<String>? options,
    Map<String, dynamic>? validation,
    RegistrationParticipantScope? participantScope,
    RegistrationCollectionStage? collectionStage,
  }) => RegistrationFieldDefinition(
    key: key ?? this.key,
    label: label ?? this.label,
    type: type ?? this.type,
    enabled: enabled ?? this.enabled,
    required: required ?? this.required,
    order: order ?? this.order,
    options: options ?? this.options,
    validation: validation ?? this.validation,
    participantScope: participantScope ?? this.participantScope,
    collectionStage: collectionStage ?? this.collectionStage,
  );
  static String _stage(RegistrationCollectionStage s) => switch (s) {
    RegistrationCollectionStage.preBooking => 'pre_booking',
    RegistrationCollectionStage.postBooking => 'post_booking',
    RegistrationCollectionStage.checkIn => 'check_in',
  };
}

class RegistrationFormDefinition {
  const RegistrationFormDefinition({
    required this.id,
    required this.name,
    required this.moduleKey,
    required this.version,
    required this.fields,
    this.status = 'draft',
  });
  final String id, name, moduleKey, status;
  final int version;
  final List<RegistrationFieldDefinition> fields;
  factory RegistrationFormDefinition.fromJson(
    Map<String, dynamic> template,
    Map<String, dynamic> version,
  ) {
    final schema = Map<String, dynamic>.from(
      version['schema'] as Map? ?? const {},
    );
    final fields =
        (schema['fields'] as List? ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map(
              (e) => RegistrationFieldDefinition.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return RegistrationFormDefinition(
      id: template['id'] as String? ?? '',
      name: template['name'] as String? ?? '',
      moduleKey: template['module_key'] as String? ?? '',
      version: (version['version'] as num?)?.toInt() ?? 0,
      fields: fields,
      status: template['status'] as String? ?? 'draft',
    );
  }
  Map<String, dynamic> schemaJson() => {
    'fields': fields.map((e) => e.toJson()).toList(),
  };

  static String stageKey(RegistrationCollectionStage stage) => switch (stage) {
    RegistrationCollectionStage.preBooking => 'pre_booking',
    RegistrationCollectionStage.postBooking => 'post_booking',
    RegistrationCollectionStage.checkIn => 'check_in',
  };
  RegistrationFormDefinition copyWith({
    List<RegistrationFieldDefinition>? fields,
    int? version,
  }) => RegistrationFormDefinition(
    id: id,
    name: name,
    moduleKey: moduleKey,
    version: version ?? this.version,
    fields: fields ?? this.fields,
    status: status,
  );
}

abstract interface class RegistrationRepository {
  Future<List<RegistrationFormDefinition>> myForms();
  Future<RegistrationFormDefinition> form(String id);
  Future<String> create(
    String name,
    String moduleKey,
    List<RegistrationFieldDefinition> fields,
  );
  Future<int> save(RegistrationFormDefinition form);
  Future<void> publish(String id);
  Future<void> bind(
    String id,
    String moduleKey,
    String? resourceId,
    String stage,
  );
  Future<String> submit(
    String id,
    String? bookingId,
    Map<String, dynamic> payload, {
    int participantIndex = 0,
    String participantScope = 'primary',
    String stage = 'pre_booking',
  });
  Future<void> upload(
    String submissionId,
    String fieldKey,
    String name,
    String mimeType,
    List<int> bytes,
  );
}
