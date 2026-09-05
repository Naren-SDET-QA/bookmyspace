import '../../../core/modular/feature_config.dart';
import '../../../core/modular/feature_id.dart';
import '../../../core/modular/feature_registry.dart';
import '../../venues/domain/category_configuration.dart';

/// Admin UI grouping over the existing FeatureRegistry. Not a second flag store.
enum AdminConfigGroup {
  features,
  categories,
  booking,
  offers,
  aiVoice,
  map,
  payments,
  invoice,
  notifications,
  qrBarcode,
  analytics,
  theme;

  String get label => switch (this) {
    AdminConfigGroup.features => 'Features',
    AdminConfigGroup.categories => 'Categories',
    AdminConfigGroup.booking => 'Booking',
    AdminConfigGroup.offers => 'Offers',
    AdminConfigGroup.aiVoice => 'AI & Voice',
    AdminConfigGroup.map => 'Map',
    AdminConfigGroup.payments => 'Payments',
    AdminConfigGroup.invoice => 'Invoice',
    AdminConfigGroup.notifications => 'Notifications',
    AdminConfigGroup.qrBarcode => 'QR/Barcode',
    AdminConfigGroup.analytics => 'Analytics',
    AdminConfigGroup.theme => 'Theme',
  };
}

/// Admin-facing projection of the existing [FeatureConfig].
/// Overrides live in FeatureConfig.config; this is not a second flag store.
class AdminFeatureConfiguration {
  AdminFeatureConfiguration({
    required this.id,
    required this.enabled,
    required this.displayName,
    required this.description,
    required this.order,
    required this.homeVisible,
    required this.navigationVisible,
    required this.registry,
    this.categoryId,
    this.categorySlug,
    this.searchVisible = true,
    this.bookingEnabled = true,
    this.offerVisible = true,
    this.availabilityEnabled = true,
    this.paymentsEnabled = true,
    this.locationEnabled = true,
    this.icon = '',
    this.image = '',
    this.accentColor = '',
    this.bookingRequiredFields = const [],
    this.bookingOptionalFields = const [],
    this.registrationRequired = false,
    this.kycRequired = false,
    this.registrationRequiredFields = const [],
    this.registrationOptionalFields = const [],
    this.invoiceVisible = true,
    this.emailVisible = true,
    this.notificationVisible = true,
    this.qrVisible = true,
    this.showPdf = true,
    this.showPrint = true,
    this.showShare = true,
    this.analyticsShowKpis = true,
    this.analyticsShowCharts = true,
    this.analyticsShowDaily = true,
    this.analyticsShowWeekly = true,
    this.analyticsShowMonthly = true,
    this.analyticsShowCategoryBreakdown = true,
    this.analyticsShowListingBreakdown = true,
    this.analyticsKpiOrder = const [],
    this.analyticsDateRanges = const [],
  });

  final FeatureId? id;
  final String? categoryId;
  final String? categorySlug;
  bool enabled;
  final String displayName;
  final String description;
  int order;
  bool homeVisible;
  bool navigationVisible;
  bool searchVisible;
  bool bookingEnabled;
  bool offerVisible;
  bool availabilityEnabled;
  bool paymentsEnabled;
  bool locationEnabled;
  final String icon;
  final String image;
  final String accentColor;
  final List<String> bookingRequiredFields;
  final List<String> bookingOptionalFields;
  final bool registrationRequired;
  final bool kycRequired;
  final List<String> registrationRequiredFields;
  final List<String> registrationOptionalFields;
  bool invoiceVisible;
  bool emailVisible;
  bool notificationVisible;
  bool qrVisible;
  bool showPdf;
  bool showPrint;
  bool showShare;
  bool analyticsShowKpis;
  bool analyticsShowCharts;
  bool analyticsShowDaily;
  bool analyticsShowWeekly;
  bool analyticsShowMonthly;
  bool analyticsShowCategoryBreakdown;
  bool analyticsShowListingBreakdown;
  final List<String> analyticsKpiOrder;
  final List<String> analyticsDateRanges;
  final FeatureRegistry registry;

  AdminConfigGroup get group {
    if (id == null) return AdminConfigGroup.categories;
    return groupOf(id!);
  }

  static AdminConfigGroup groupOf(FeatureId id) => switch (id) {
    FeatureId.search ||
    FeatureId.location ||
    FeatureId.registration => AdminConfigGroup.features,
    FeatureId.functionHall ||
    FeatureId.hotels ||
    FeatureId.pg ||
    FeatureId.institutes ||
    FeatureId.courses ||
    FeatureId.events => AdminConfigGroup.categories,
    FeatureId.booking => AdminConfigGroup.booking,
    FeatureId.offers => AdminConfigGroup.offers,
    FeatureId.ai || FeatureId.voice => AdminConfigGroup.aiVoice,
    FeatureId.maps => AdminConfigGroup.map,
    FeatureId.payments || FeatureId.razorpay => AdminConfigGroup.payments,
    FeatureId.invoice => AdminConfigGroup.invoice,
    FeatureId.notifications ||
    FeatureId.email ||
    FeatureId.whatsapp => AdminConfigGroup.notifications,
    FeatureId.barcode => AdminConfigGroup.qrBarcode,
    FeatureId.analytics => AdminConfigGroup.analytics,
    FeatureId.theme => AdminConfigGroup.theme,
  };

  static const _names = {
    FeatureId.functionHall: 'Function Halls',
    FeatureId.hotels: 'Hotels / Lodge Rooms',
    FeatureId.pg: 'PG / Co-living',
    FeatureId.institutes: 'Institutes / Classes',
    FeatureId.maps: 'Maps',
    FeatureId.ai: 'Assistant',
    FeatureId.voice: 'Voice Search',
    FeatureId.payments: 'Payments',
    FeatureId.razorpay: 'Razorpay',
    FeatureId.notifications: 'Notifications',
    FeatureId.barcode: 'Barcode / QR check-in',
    FeatureId.offers: 'Offers',
    FeatureId.invoice: 'Invoices',
    FeatureId.theme: 'Theme',
    FeatureId.courses: 'Courses',
    FeatureId.events: 'Events',
    FeatureId.search: 'Search',
    FeatureId.booking: 'Booking',
    FeatureId.analytics: 'Analytics',
    FeatureId.email: 'Email',
    FeatureId.whatsapp: 'WhatsApp',
    FeatureId.location: 'Location',
    FeatureId.registration: 'Registration',
  };

  static List<AdminFeatureConfiguration> fromRegistry(
    FeatureRegistry registry,
  ) {
    return FeatureId.values.map((id) {
      final config = registry.configOf(id);
      return _fromConfig(id: id, config: config, registry: registry);
    }).toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  static AdminFeatureConfiguration fromCategory(
    CategoryConfiguration category,
    FeatureRegistry registry,
  ) {
    return AdminFeatureConfiguration(
      id: null,
      categoryId: category.id,
      categorySlug: category.slug,
      enabled: category.visible,
      displayName: category.name,
      description: 'Database category ${category.slug}',
      order: category.sortOrder,
      homeVisible: category.homeVisible,
      navigationVisible: category.visible,
      searchVisible: category.searchable,
      bookingEnabled: category.bookable && !category.isListingOnly,
      offerVisible: category.offerVisible,
      availabilityEnabled: category.availabilityEnabled,
      paymentsEnabled: category.paymentsEnabled,
      locationEnabled: category.locationEnabled,
      icon: category.icon,
      image: category.imageUrl,
      accentColor: category.themeColor,
      bookingRequiredFields: category.bookingRequiredFields,
      bookingOptionalFields: category.bookingOptionalFields,
      registrationRequired: category.registrationRequired,
      kycRequired: category.kycRequired,
      registrationRequiredFields: category.registrationRequiredFields,
      registrationOptionalFields: category.registrationOptionalFields,
      invoiceVisible: category.invoiceVisible,
      notificationVisible: category.notificationVisible,
      qrVisible: category.qrVisible,
      registry: registry,
    );
  }

  static Map<AdminConfigGroup, List<AdminFeatureConfiguration>> grouped(
    FeatureRegistry registry, {
    List<CategoryConfiguration> categories = const [],
  }) {
    final grouped = {
      for (final group in AdminConfigGroup.values)
        group: <AdminFeatureConfiguration>[],
    };
    for (final item in fromRegistry(registry)) {
      grouped[item.group]!.add(item);
    }
    for (final category in categories) {
      grouped[AdminConfigGroup.categories]!.add(
        fromCategory(category, registry),
      );
    }
    return grouped;
  }

  static AdminFeatureConfiguration _fromConfig({
    required FeatureId id,
    required FeatureConfig config,
    required FeatureRegistry registry,
  }) {
    final metadata = config.config;
    return AdminFeatureConfiguration(
      id: id,
      enabled: config.enabled,
      displayName: _text(metadata, 'display_name', _names[id] ?? id.name),
      description: _text(
        metadata,
        'description',
        'Configure ${_names[id] ?? id.name}.',
      ),
      order: (metadata['order'] as num?)?.toInt() ?? id.index,
      homeVisible: _flag(metadata, 'home_visible', _defaultHomeVisibility(id)),
      navigationVisible: _flag(metadata, 'navigation_visible', true),
      searchVisible: _flag(metadata, 'search_visible', true),
      bookingEnabled: _flag(
        metadata,
        'booking_enabled',
        _defaultBookingEnabled(id),
      ),
      offerVisible: _flag(metadata, 'offer_visible', true),
      icon: _text(metadata, 'icon'),
      image: _text(metadata, 'image'),
      accentColor: _text(
        metadata,
        'accent_color',
        _text(metadata, 'theme_color'),
      ),
      bookingRequiredFields: _strings(metadata, 'booking_required_fields'),
      bookingOptionalFields: _strings(metadata, 'booking_optional_fields'),
      invoiceVisible: _flag(metadata, 'invoice_visible', true),
      emailVisible: _flag(metadata, 'email_visible', true),
      notificationVisible: _flag(metadata, 'notification_visible', true),
      qrVisible: _flag(metadata, 'qr_visible', true),
      showPdf: _flag(metadata, 'show_pdf', true),
      showPrint: _flag(metadata, 'show_print', true),
      showShare: _flag(metadata, 'show_share', true),
      analyticsShowKpis: _flag(metadata, 'show_kpis', true),
      analyticsShowCharts: _flag(metadata, 'show_charts', true),
      analyticsShowDaily: _flag(metadata, 'show_daily', true),
      analyticsShowWeekly: _flag(metadata, 'show_weekly', true),
      analyticsShowMonthly: _flag(metadata, 'show_monthly', true),
      analyticsShowCategoryBreakdown: _flag(
        metadata,
        'show_category_breakdown',
        true,
      ),
      analyticsShowListingBreakdown: _flag(
        metadata,
        'show_listing_breakdown',
        true,
      ),
      analyticsKpiOrder: _strings(metadata, 'kpi_order'),
      analyticsDateRanges: _strings(metadata, 'date_ranges'),
      registry: registry,
    );
  }

  static bool _defaultHomeVisibility(FeatureId id) => switch (id) {
    FeatureId.functionHall ||
    FeatureId.hotels ||
    FeatureId.pg ||
    FeatureId.institutes => true,
    _ => false,
  };

  static bool _defaultBookingEnabled(FeatureId id) => switch (id) {
    FeatureId.institutes => false,
    FeatureId.functionHall ||
    FeatureId.hotels ||
    FeatureId.pg ||
    FeatureId.courses ||
    FeatureId.events ||
    FeatureId.booking => true,
    _ => false,
  };

  static bool _flag(Map<String, Object?> metadata, String key, bool fallback) {
    final value = metadata[key];
    if (value is bool) return value;
    return fallback;
  }

  static String _text(
    Map<String, Object?> metadata,
    String key, [
    String fallback = '',
  ]) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static List<String> _strings(Map<String, Object?> metadata, String key) {
    final value = metadata[key];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  void update(
    FeatureRegistry target, {
    bool? enabled,
    bool? homeVisible,
    bool? navigationVisible,
    bool? searchVisible,
    bool? bookingEnabled,
    bool? offerVisible,
    bool? availabilityEnabled,
    bool? paymentsEnabled,
    bool? locationEnabled,
    int? order,
    String? displayName,
    String? description,
    String? icon,
    String? image,
    String? accentColor,
    List<String>? bookingRequiredFields,
    List<String>? bookingOptionalFields,
    bool? invoiceVisible,
    bool? emailVisible,
    bool? notificationVisible,
    bool? qrVisible,
    bool? showPdf,
    bool? showPrint,
    bool? showShare,
    bool? analyticsShowKpis,
    bool? analyticsShowCharts,
    bool? analyticsShowDaily,
    bool? analyticsShowWeekly,
    bool? analyticsShowMonthly,
    bool? analyticsShowCategoryBreakdown,
    bool? analyticsShowListingBreakdown,
    List<String>? analyticsKpiOrder,
    List<String>? analyticsDateRanges,
  }) {
    final featureId = id;
    if (featureId == null) return;
    final current = target.configOf(featureId);
    target.apply(
      featureId,
      enabled: enabled,
      config: {
        ...current.config,
        if (homeVisible != null) 'home_visible': homeVisible,
        if (navigationVisible != null) 'navigation_visible': navigationVisible,
        if (searchVisible != null) 'search_visible': searchVisible,
        if (bookingEnabled != null) 'booking_enabled': bookingEnabled,
        if (offerVisible != null) 'offer_visible': offerVisible,
        if (availabilityEnabled != null)
          'availability_enabled': availabilityEnabled,
        if (paymentsEnabled != null) 'payments_enabled': paymentsEnabled,
        if (locationEnabled != null) 'location_enabled': locationEnabled,
        if (order != null) 'order': order,
        if (displayName != null) 'display_name': displayName,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (image != null) 'image': image,
        if (accentColor != null) 'accent_color': accentColor,
        if (bookingRequiredFields != null)
          'booking_required_fields': bookingRequiredFields,
        if (bookingOptionalFields != null)
          'booking_optional_fields': bookingOptionalFields,
        if (invoiceVisible != null) 'invoice_visible': invoiceVisible,
        if (emailVisible != null) 'email_visible': emailVisible,
        if (notificationVisible != null)
          'notification_visible': notificationVisible,
        if (qrVisible != null) 'qr_visible': qrVisible,
        if (showPdf != null) 'show_pdf': showPdf,
        if (showPrint != null) 'show_print': showPrint,
        if (showShare != null) 'show_share': showShare,
        if (analyticsShowKpis != null) 'show_kpis': analyticsShowKpis,
        if (analyticsShowCharts != null) 'show_charts': analyticsShowCharts,
        if (analyticsShowDaily != null) 'show_daily': analyticsShowDaily,
        if (analyticsShowWeekly != null) 'show_weekly': analyticsShowWeekly,
        if (analyticsShowMonthly != null) 'show_monthly': analyticsShowMonthly,
        if (analyticsShowCategoryBreakdown != null)
          'show_category_breakdown': analyticsShowCategoryBreakdown,
        if (analyticsShowListingBreakdown != null)
          'show_listing_breakdown': analyticsShowListingBreakdown,
        if (analyticsKpiOrder != null) 'kpi_order': analyticsKpiOrder,
        if (analyticsDateRanges != null) 'date_ranges': analyticsDateRanges,
      },
    );
  }

  Map<String, dynamic> metadataForUpdate({
    bool? enabled,
    bool? homeVisible,
    bool? searchVisible,
    bool? bookingEnabled,
    bool? offerVisible,
    bool? availabilityEnabled,
    bool? paymentsEnabled,
    bool? locationEnabled,
    int? order,
    String? displayName,
    String? description,
    String? icon,
    String? image,
    String? accentColor,
    List<String>? bookingRequiredFields,
    List<String>? bookingOptionalFields,
    bool? registrationRequired,
    bool? kycRequired,
    List<String>? registrationRequiredFields,
    List<String>? registrationOptionalFields,
    bool? invoiceVisible,
    bool? notificationVisible,
    bool? qrVisible,
  }) {
    return {
      'active': enabled ?? this.enabled,
      'home_visible': homeVisible ?? this.homeVisible,
      'searchable': searchVisible ?? this.searchVisible,
      'bookable': bookingEnabled ?? this.bookingEnabled,
      'offer_visible': offerVisible ?? this.offerVisible,
      'offers_enabled': offerVisible ?? this.offerVisible,
      'availability_enabled': availabilityEnabled ?? this.availabilityEnabled,
      'payments_enabled': paymentsEnabled ?? this.paymentsEnabled,
      'location_enabled': locationEnabled ?? this.locationEnabled,
      'sort_order': order ?? this.order,
      if ((displayName ?? this.displayName).isNotEmpty)
        'display_name': displayName ?? this.displayName,
      if ((description ?? this.description).isNotEmpty)
        'description': description ?? this.description,
      if ((icon ?? this.icon).isNotEmpty) 'icon': icon ?? this.icon,
      if ((image ?? this.image).isNotEmpty) 'image': image ?? this.image,
      'theme_color': accentColor ?? this.accentColor,
      'booking_required_fields':
          bookingRequiredFields ?? this.bookingRequiredFields,
      'booking_optional_fields':
          bookingOptionalFields ?? this.bookingOptionalFields,
      'registration_required':
          registrationRequired ?? this.registrationRequired,
      'kyc_required': kycRequired ?? this.kycRequired,
      'registration_required_fields':
          registrationRequiredFields ?? this.registrationRequiredFields,
      'registration_optional_fields':
          registrationOptionalFields ?? this.registrationOptionalFields,
      'invoice_visible': invoiceVisible ?? this.invoiceVisible,
      'notification_visible': notificationVisible ?? this.notificationVisible,
      'qr_visible': qrVisible ?? this.qrVisible,
    };
  }

  static bool canAccess(String? role) => switch (role) {
    'admin' || 'administrator' || 'super_administrator' => true,
    _ => false,
  };
}
