enum DynamicFieldType {
  text, number, email, phone, date, time, datetime, dropdown, multiSelect,
  radio, checkbox, toggle, address, pin, mapLocation, currency, image, video, document,
}

class DynamicField {
  const DynamicField({required this.key, required this.label, required this.type, this.required = false, this.options = const [], this.validation = const {}});
  final String key;
  final String label;
  final DynamicFieldType type;
  final bool required;
  final List<String> options;
  final Map<String, dynamic> validation;
}

class DynamicFieldSchema {
  const DynamicFieldSchema(this.fields);
  final List<DynamicField> fields;
  List<String> get requiredKeys => fields.where((field) => field.required && !field.validation.containsKey('when')).map((field) => field.key).toList(growable: false);

  factory DynamicFieldSchema.fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata['fields'] is List ? metadata['fields'] as List : const [];
    return DynamicFieldSchema([
      for (final item in raw)
        if (item is Map && item['key'] != null)
          DynamicField(
            key: item['key'].toString(),
            label: item['label']?.toString() ?? item['key'].toString(),
            type: _type(item['type']),
            required: item['required'] == true,
            options: item['options'] is List ? (item['options'] as List).map((value) => value.toString()).toList(growable: false) : const [],
            validation: {
              if (item['validation'] is Map) ...Map<String, dynamic>.from(item['validation'] as Map),
              if (item['when'] is Map) 'when': Map<String, dynamic>.from(item['when'] as Map),
            },
          ),
    ]);
  }

  static DynamicFieldType _type(Object? value) {
    final normalized = value?.toString().toLowerCase().replaceAll('-', '').replaceAll('_', '') ?? 'text';
    return DynamicFieldType.values.firstWhere((item) => item.name.toLowerCase() == normalized, orElse: () => DynamicFieldType.text);
  }
}

class ClarificationState {
  const ClarificationState._({required this.userId, required this.sessionId, required this.categorySlug, required this.requiredFields, required this.values, required this.expiresAt});
  final String userId;
  final String sessionId;
  final String categorySlug;
  final List<String> requiredFields;
  final Map<String, dynamic> values;
  final DateTime expiresAt;

  factory ClarificationState.create({required String userId, required String sessionId, required String categorySlug, required List<String> requiredFields, DateTime? now, Duration ttl = const Duration(minutes: 10)}) => ClarificationState._(userId: userId, sessionId: sessionId, categorySlug: categorySlug, requiredFields: List.unmodifiable(requiredFields), values: const {}, expiresAt: (now ?? DateTime.now()).add(ttl));

  ClarificationState forUser(String id) {
    if (id != userId) throw StateError('Clarification state is not owned by this user');
    if (isExpired(DateTime.now())) throw StateError('Clarification state expired');
    return this;
  }

  ClarificationState answer(String key, Object? value) => ClarificationState._(userId: userId, sessionId: sessionId, categorySlug: categorySlug, requiredFields: requiredFields, values: {...values, key: value}, expiresAt: expiresAt);
  ClarificationState removeAnswer(String key) => ClarificationState._(userId: userId, sessionId: sessionId, categorySlug: categorySlug, requiredFields: requiredFields, values: {...values}..remove(key), expiresAt: expiresAt);
  ClarificationState withRequiredFields(List<String> fields) => ClarificationState._(userId: userId, sessionId: sessionId, categorySlug: categorySlug, requiredFields: List.unmodifiable(fields), values: values, expiresAt: expiresAt);
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);
  List<String> get missingFields => requiredFields.where((key) => values[key] == null || (values[key] is String && (values[key] as String).trim().isEmpty)).toList(growable: false);
}
