class TenantConfiguration {
  const TenantConfiguration({
    required this.organizationId,
    this.version = 0,
    this.branding = const {},
    this.theme = const {},
    this.language = const {},
    this.features = const {},
    this.booking = const {},
    this.notifications = const {},
    this.media = const {},
    this.voice = const {},
    this.categories = const {},
    this.categoryOverrides = const {},
  });

  final String organizationId;
  final int version;
  final Map<String, dynamic> branding;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> language;
  final Map<String, dynamic> features;
  final Map<String, dynamic> booking;
  final Map<String, dynamic> notifications;
  final Map<String, dynamic> media;
  final Map<String, dynamic> voice;
  final Map<String, dynamic> categories;
  final Map<String, Map<String, dynamic>> categoryOverrides;

  bool isEnabled(String key, {String? categorySlug, bool fallback = false}) =>
      resolve(key, categorySlug: categorySlug) ?? fallback;

  String stringValue(String key, {String fallback = ''}) {
    final value = features[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  TenantConfiguration copyWith({
    Map<String, dynamic>? branding,
    Map<String, dynamic>? theme,
    Map<String, dynamic>? language,
    Map<String, dynamic>? features,
    Map<String, dynamic>? booking,
    Map<String, dynamic>? notifications,
    Map<String, dynamic>? media,
    Map<String, dynamic>? voice,
    Map<String, dynamic>? categories,
    Map<String, Map<String, dynamic>>? categoryOverrides,
  }) => TenantConfiguration(
        organizationId: organizationId,
        version: version,
        branding: branding ?? this.branding,
        theme: theme ?? this.theme,
        language: language ?? this.language,
        features: features ?? this.features,
        booking: booking ?? this.booking,
        notifications: notifications ?? this.notifications,
        media: media ?? this.media,
        voice: voice ?? this.voice,
        categories: categories ?? this.categories,
        categoryOverrides: categoryOverrides ?? this.categoryOverrides,
      );

  bool? resolve(String key, {String? categorySlug}) {
    final override = categorySlug == null ? null : categoryOverrides[categorySlug]?[key];
    final value = override ?? features[key];
    return value is bool ? value : null;
  }

  bool observabilitySetting(String setting, {String? categorySlug, bool fallback = false}) {
    final key = setting.startsWith('observability.') ? setting : 'observability.$setting';
    final categoryValue = categorySlug == null ? null : categoryOverrides[categorySlug]?[key];
    final value = categoryValue ?? features[key] ?? (setting == 'observability' ? features['observability'] : null);
    return value is bool ? value : fallback;
  }

  factory TenantConfiguration.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(String key) =>
        (json[key] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawOverrides = (json['category_overrides'] as Map?)?.cast<String, dynamic>() ?? const {};
    final overrides = <String, Map<String, dynamic>>{};
    for (final entry in rawOverrides.entries) {
      final value = entry.value;
      if (value is Map) overrides[entry.key] = value.cast<String, dynamic>();
    }
    return TenantConfiguration(
      organizationId: json['organization_id'] as String? ?? '',
      version: (json['configuration_version'] as num?)?.toInt() ?? 0,
      branding: map('branding'),
      theme: map('theme'),
      language: map('language'),
      features: _safeMap(map('features')),
      booking: map('booking'),
      notifications: map('notifications'),
      media: map('media'),
      voice: map('voice'),
      categories: map('categories'),
      categoryOverrides: overrides,
    );
  }

  static Map<String, dynamic> _safeMap(Map<String, dynamic> source) {
    const blocked = {'secret', 'password', 'token', 'api_key', 'access_token', 'credential'};
    return Map.fromEntries(source.entries.where((entry) => !blocked.contains(entry.key.toLowerCase())));
  }
}
