enum ModuleFieldType {
  text,
  longText,
  number,
  email,
  phone,
  date,
  datetime,
  dropdown,
  multiSelect,
  radio,
  checkbox,
  image,
  file,
  address,
  idProof,
  signature,
  currency,
}

class ModuleFeatureConfig {
  const ModuleFeatureConfig({
    required this.moduleKey,
    this.venueId,
    this.registrationEnabled = false,
    this.customFieldsEnabled = false,
    this.documentUploadEnabled = false,
    this.paymentEnabled = false,
    this.invoiceEnabled = true,
    this.emailEnabled = true,
    this.notificationsEnabled = true,
    this.moduleEnabled = true,
    this.approvalRequired = false,
    this.locationRequired = false,
    this.availabilityRequired = false,
    this.documentsEnabled = false,
    this.paymentRequiredBeforeApproval = false,
    this.paymentRequiredBeforeConfirmation = false,
    this.paymentRefundable = true,
    this.mapEnabled = true,
    this.voiceEnabled = false,
    this.aiHelpEnabled = false,
    this.multilingualEnabled = true,
    this.reviewEnabled = true,
    this.currency = 'INR',
  });
  final String moduleKey;
  final String? venueId;
  final bool registrationEnabled;
  final bool customFieldsEnabled;
  final bool documentUploadEnabled;
  final bool paymentEnabled;
  final bool invoiceEnabled;
  final bool emailEnabled;
  final bool notificationsEnabled;
  final bool moduleEnabled;
  final bool approvalRequired;
  final bool locationRequired;
  final bool availabilityRequired;
  final bool documentsEnabled;
  final bool paymentRequiredBeforeApproval;
  final bool paymentRequiredBeforeConfirmation;
  final bool paymentRefundable;
  final bool mapEnabled;
  final bool voiceEnabled;
  final bool aiHelpEnabled;
  final bool multilingualEnabled;
  final bool reviewEnabled;
  final String currency;

  factory ModuleFeatureConfig.fromJson(Map<String, dynamic> json) =>
      ModuleFeatureConfig(
        moduleKey: json['module_key'] as String? ?? '',
        venueId: json['venue_id'] as String?,
        registrationEnabled: json['registration_enabled'] as bool? ?? false,
        customFieldsEnabled: json['custom_fields_enabled'] as bool? ?? false,
        documentUploadEnabled:
            json['document_upload_enabled'] as bool? ?? false,
        paymentEnabled: json['payment_enabled'] as bool? ?? false,
        invoiceEnabled: json['invoice_enabled'] as bool? ?? true,
        emailEnabled: json['email_enabled'] as bool? ?? true,
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        moduleEnabled: json['module_enabled'] as bool? ?? true,
        approvalRequired: json['approval_required'] as bool? ?? false,
        locationRequired: json['location_required'] as bool? ?? false,
        availabilityRequired: json['availability_required'] as bool? ?? false,
        documentsEnabled:
            json['documents_enabled'] as bool? ??
            (json['document_upload_enabled'] as bool? ?? false),
        paymentRequiredBeforeApproval:
            json['payment_required_before_approval'] as bool? ?? false,
        paymentRequiredBeforeConfirmation:
            json['payment_required_before_confirmation'] as bool? ?? false,
        paymentRefundable: json['payment_refundable'] as bool? ?? true,
        mapEnabled: json['map_enabled'] as bool? ?? true,
        voiceEnabled: json['voice_enabled'] as bool? ?? false,
        aiHelpEnabled: json['ai_help_enabled'] as bool? ?? false,
        multilingualEnabled: json['multilingual_enabled'] as bool? ?? true,
        reviewEnabled: json['review_enabled'] as bool? ?? true,
        currency: json['currency'] as String? ?? 'INR',
      );
}

class ModuleDocumentRequirement {
  const ModuleDocumentRequirement({
    required this.id,
    required this.documentKey,
    required this.label,
    required this.required,
    required this.allowedMimeTypes,
    required this.maxSizeBytes,
  });
  final String id;
  final String documentKey;
  final String label;
  final bool required;
  final List<String> allowedMimeTypes;
  final int? maxSizeBytes;

  factory ModuleDocumentRequirement.fromJson(Map<String, dynamic> json) =>
      ModuleDocumentRequirement(
        id: json['id'] as String? ?? '',
        documentKey: json['document_key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        required: json['required'] as bool? ?? false,
        allowedMimeTypes: (json['allowed_mime_types'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        maxSizeBytes: (json['max_size_bytes'] as num?)?.toInt(),
      );
}

class ModuleFormField {
  const ModuleFormField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.enabled = true,
    this.options = const [],
  });
  final String key;
  final String label;
  final ModuleFieldType type;
  final bool required;
  final bool enabled;
  final List<String> options;

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'required': required,
    'enabled': enabled,
    'options': options,
  };
}

class ModuleFormVersion {
  const ModuleFormVersion({
    required this.id,
    required this.moduleKey,
    required this.version,
    required this.fields,
  });
  final String id;
  final String moduleKey;
  final int version;
  final List<ModuleFormField> fields;
}
