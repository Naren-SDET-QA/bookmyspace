enum RegistrationFieldType {
  text,
  number,
  phone,
  email,
  date,
  dropdown,
  multiselect,
  address,
  documentUpload,
  imageUpload,
  boolean,
}

class RegistrationFieldConfig {
  const RegistrationFieldConfig({
    required this.key,
    required this.label,
    required this.type,
    this.enabled = true,
    this.required = false,
    this.ownerVisible = true,
    this.customerVisible = false,
    this.adminOnly = false,
    this.sensitive = false,
    this.placeholder,
    this.helpText,
    this.options = const [],
  });
  final String key;
  final String label;
  final RegistrationFieldType type;
  final bool enabled;
  final bool required;
  final bool ownerVisible;
  final bool customerVisible;
  final bool adminOnly;
  final bool sensitive;
  final String? placeholder;
  final String? helpText;

  /// Optional choices supplied by the admin in validation_rules.options.
  final List<String> options;

  factory RegistrationFieldConfig.fromJson(Map<String, dynamic> json) =>
      RegistrationFieldConfig(
        key: json['field_key'] as String? ?? '',
        label: json['display_label'] as String? ?? '',
        type: RegistrationFieldType.values.firstWhere(
          (value) =>
              value.name == _typeName(json['field_type'] as String? ?? 'text'),
          orElse: () => RegistrationFieldType.text,
        ),
        enabled: json['enabled'] as bool? ?? true,
        required: json['required'] as bool? ?? false,
        ownerVisible: json['owner_visible'] as bool? ?? true,
        customerVisible: json['customer_visible'] as bool? ?? false,
        adminOnly: json['admin_only'] as bool? ?? false,
        sensitive: json['sensitive'] as bool? ?? false,
        placeholder: json['placeholder'] as String?,
        helpText: json['help_text'] as String?,
        options: _options(json['validation_rules']),
      );

  static List<String> _options(dynamic value) {
    if (value is! Map) return const [];
    final options = value['options'];
    if (options is! List) return const [];
    return options
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _typeName(String value) => value == 'document_upload'
      ? 'documentUpload'
      : value == 'image_upload'
      ? 'imageUpload'
      : value;
}
