class IntegrationConfig {
  const IntegrationConfig({
    this.id,
    required this.name,
    required this.slug,
    required this.type,
    this.provider,
    this.description,
    this.icon,
    this.enabled = false,
    this.environment = 'development',
    this.baseUrl,
    this.authenticationType = 'NONE',
    this.configuration = const {},
    this.inputSchema = const {},
    this.outputSchema = const {},
    this.status = 'disabled',
    this.displayOrder = 0,
  });

  final String? id;
  final String name;
  final String slug;
  final String type;
  final String? provider;
  final String? description;
  final String? icon;
  final bool enabled;
  final String environment;
  final String? baseUrl;
  final String authenticationType;
  final Map<String, dynamic> configuration;
  final Map<String, dynamic> inputSchema;
  final Map<String, dynamic> outputSchema;
  final String status;
  final int displayOrder;

  factory IntegrationConfig.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapValue(String key) =>
        (json[key] as Map?)?.cast<String, dynamic>() ?? const {};

    return IntegrationConfig(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      type: json['type'] as String? ?? 'UNKNOWN',
      provider: json['provider'] as String?,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      enabled: json['enabled'] as bool? ?? false,
      environment: json['environment'] as String? ?? 'development',
      baseUrl: json['base_url'] as String?,
      authenticationType:
          json['authentication_type'] as String? ?? 'NONE',
      configuration: mapValue('configuration'),
      inputSchema: mapValue('input_schema'),
      outputSchema: mapValue('output_schema'),
      status: json['status'] as String? ?? 'disabled',
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSafeJson() => {
        if (id != null) 'id': id,
        'name': name,
        'slug': slug,
        'type': type,
        if (provider != null) 'provider': provider,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        'enabled': enabled,
        'environment': environment,
        if (baseUrl != null) 'base_url': baseUrl,
        'authentication_type': authenticationType,
        'configuration': configuration,
        'input_schema': inputSchema,
        'output_schema': outputSchema,
        'status': status,
        'display_order': displayOrder,
      };
}
