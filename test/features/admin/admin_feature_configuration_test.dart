import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/features/admin/domain/admin_feature_configuration.dart';
import 'package:bookmyspace/features/analytics/domain/analytics_display_config.dart';
import 'package:bookmyspace/features/booking/domain/invoice_display_config.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin can see registered features with safe defaults', () {
    final items = AdminFeatureConfiguration.fromRegistry(
      FeatureRegistry.defaults(),
    );

    expect(items, isNotEmpty);
    expect(items.any((item) => item.id == FeatureId.maps), isTrue);
    expect(items.first.order, lessThanOrEqualTo(items.last.order));
    final maps = items.firstWhere((item) => item.id == FeatureId.maps);
    expect(maps.homeVisible, isFalse);
    expect(maps.navigationVisible, isTrue);
  });

  test('enable and visibility overrides update the existing registry', () {
    final registry = FeatureRegistry.defaults();
    final maps = AdminFeatureConfiguration.fromRegistry(
      registry,
    ).firstWhere((item) => item.id == FeatureId.pg);

    maps.update(
      registry,
      enabled: false,
      homeVisible: false,
      navigationVisible: false,
      order: 99,
    );

    final updated = AdminFeatureConfiguration.fromRegistry(
      registry,
    ).firstWhere((item) => item.id == FeatureId.pg);
    expect(registry.isEnabled(FeatureId.pg), isFalse);
    expect(updated.homeVisible, isFalse);
    expect(updated.navigationVisible, isFalse);
    expect(updated.order, 99);
    expect(registry.visibleHomeSections(), isNot(contains('pg_hostels')));
  });

  test(
    'ordering is respected and defaults remain unchanged without overrides',
    () {
      final registry = FeatureRegistry.defaults();
      final defaults = AdminFeatureConfiguration.fromRegistry(registry);
      final overridden = defaults.firstWhere((item) => item.id == FeatureId.ai);
      overridden.update(registry, order: -1);

      final ordered = AdminFeatureConfiguration.fromRegistry(registry);
      expect(ordered.first.id, FeatureId.ai);
      expect(
        AdminFeatureConfiguration.fromRegistry(
          FeatureRegistry.defaults(),
        ).firstWhere((item) => item.id == FeatureId.ai).enabled,
        isTrue,
      );
    },
  );

  test('admin access follows the existing administrator protection', () {
    expect(AdminFeatureConfiguration.canAccess(null), isFalse);
    expect(AdminFeatureConfiguration.canAccess('customer'), isFalse);
    expect(AdminFeatureConfiguration.canAccess('admin'), isTrue);
    expect(AdminFeatureConfiguration.canAccess('administrator'), isTrue);
    expect(AdminFeatureConfiguration.canAccess('super_administrator'), isTrue);
  });

  test('admin groups cover the plug-and-configure catalog', () {
    expect(AdminConfigGroup.values.map((group) => group.label).toList(), [
      'Features',
      'Categories',
      'Booking',
      'Offers',
      'AI & Voice',
      'Map',
      'Payments',
      'Invoice',
      'Notifications',
      'QR/Barcode',
      'Analytics',
      'Theme',
    ]);
  });

  test('every registered feature belongs to exactly one admin group', () {
    final grouped = AdminFeatureConfiguration.grouped(
      FeatureRegistry.defaults(),
    );
    expect(grouped.keys, AdminConfigGroup.values);
    final ids = grouped.values
        .expand((items) => items.map((item) => item.id))
        .whereType<FeatureId>()
        .toSet();
    expect(ids, FeatureId.values.toSet());
    for (final group in AdminConfigGroup.values) {
      expect(grouped[group], isNotEmpty, reason: '${group.label} is empty');
    }
  });

  test(
    'search, booking, offer and identity knobs persist on FeatureConfig',
    () {
      final registry = FeatureRegistry.defaults();
      final halls = AdminFeatureConfiguration.fromRegistry(
        registry,
      ).firstWhere((item) => item.id == FeatureId.functionHall);

      halls.update(
        registry,
        searchVisible: false,
        bookingEnabled: false,
        offerVisible: false,
        displayName: 'Halls',
        description: 'Wedding venues',
        icon: 'hall',
        image: 'https://example.test/hall.jpg',
        accentColor: '#1565C0',
        order: 2,
        bookingRequiredFields: const ['date', 'guests'],
        bookingOptionalFields: const ['notes'],
      );

      final updated = AdminFeatureConfiguration.fromRegistry(
        registry,
      ).firstWhere((item) => item.id == FeatureId.functionHall);
      expect(updated.searchVisible, isFalse);
      expect(updated.bookingEnabled, isFalse);
      expect(updated.offerVisible, isFalse);
      expect(updated.displayName, 'Halls');
      expect(updated.description, 'Wedding venues');
      expect(updated.icon, 'hall');
      expect(updated.image, 'https://example.test/hall.jpg');
      expect(updated.accentColor, '#1565C0');
      expect(updated.bookingRequiredFields, ['date', 'guests']);
      expect(updated.bookingOptionalFields, ['notes']);
      expect(
        registry.visibleSearchSections(),
        isNot(contains('function_halls')),
      );
      expect(registry.isBookingEnabled(FeatureId.functionHall), isFalse);
      expect(registry.isOfferVisible(FeatureId.functionHall), isFalse);
    },
  );

  test('unknown supabase category is configurable without a FeatureId', () {
    const floating = CategoryConfiguration(
      id: 'new',
      slug: 'floating_pavilion',
      name: 'Floating Pavilion',
      bookable: true,
      bookingRequiredFields: ['date', 'time'],
      bookingOptionalFields: ['notes'],
      themeColor: '#1565C0',
    );
    expect(
      FeatureId.values.map((id) => id.name),
      isNot(contains('floatingPavilion')),
    );

    final grouped = AdminFeatureConfiguration.grouped(
      FeatureRegistry.defaults(),
      categories: const [floating],
    );
    final extra = grouped[AdminConfigGroup.categories]!.firstWhere(
      (item) => item.categorySlug == 'floating_pavilion',
    );
    expect(extra.id, isNull);
    expect(extra.displayName, 'Floating Pavilion');
    expect(extra.bookingEnabled, isTrue);
    expect(extra.bookingRequiredFields, ['date', 'time']);

    final metadata = extra.metadataForUpdate(
      searchVisible: false,
      offerVisible: false,
      bookingRequiredFields: const ['date', 'guests'],
      accentColor: '#004D40',
    );
    expect(metadata['searchable'], isFalse);
    expect(metadata['offer_visible'], isFalse);
    expect(metadata['booking_required_fields'], ['date', 'guests']);
    expect(metadata['theme_color'], '#004D40');
  });

  test('analytics knobs persist on the existing analytics feature', () {
    final registry = FeatureRegistry.defaults();
    final analytics = AdminFeatureConfiguration.fromRegistry(
      registry,
    ).firstWhere((item) => item.id == FeatureId.analytics);

    analytics.update(
      registry,
      analyticsShowKpis: true,
      analyticsShowCharts: false,
      analyticsShowDaily: false,
      analyticsShowWeekly: true,
      analyticsShowMonthly: true,
      analyticsShowCategoryBreakdown: false,
      analyticsShowListingBreakdown: true,
      analyticsKpiOrder: const ['net_revenue', 'refund_amount'],
      analyticsDateRanges: const ['today', 'this_month'],
    );

    final config = AnalyticsDisplayConfig.fromFeature(
      registry.configOf(FeatureId.analytics),
    );
    expect(config.showKpis, isTrue);
    expect(config.showCharts, isFalse);
    expect(config.showDaily, isFalse);
    expect(config.showWeekly, isTrue);
    expect(config.showMonthly, isTrue);
    expect(config.showCategoryBreakdown, isFalse);
    expect(config.showListingBreakdown, isTrue);
    expect(config.kpiOrder, ['net_revenue', 'refund_amount']);
    expect(config.dateRanges, ['today', 'this_month']);
  });

  test('category registration knobs persist on existing category metadata', () {
    const floating = CategoryConfiguration(
      id: 'new',
      slug: 'floating_pavilion',
      name: 'Floating Pavilion',
      bookable: true,
    );
    final extra = AdminFeatureConfiguration.fromCategory(
      floating,
      FeatureRegistry.defaults(),
    );
    final metadata = extra.metadataForUpdate(
      registrationRequired: true,
      kycRequired: true,
      registrationRequiredFields: const ['student_name'],
      registrationOptionalFields: const ['notes'],
    );
    expect(metadata['registration_required'], isTrue);
    expect(metadata['kyc_required'], isTrue);
    expect(metadata['registration_required_fields'], ['student_name']);
    expect(metadata['registration_optional_fields'], ['notes']);
  });

  test(
    'category admin knobs persist invoice, notification and QR visibility',
    () {
      const floating = CategoryConfiguration(
        id: 'new',
        slug: 'floating_pavilion',
        name: 'Floating Pavilion',
      );
      final extra = AdminFeatureConfiguration.fromCategory(
        floating,
        FeatureRegistry.defaults(),
      );
      expect(extra.invoiceVisible, isTrue);
      expect(extra.notificationVisible, isTrue);
      expect(extra.qrVisible, isTrue);
      final metadata = extra.metadataForUpdate(
        invoiceVisible: false,
        notificationVisible: false,
        qrVisible: true,
      );
      expect(metadata['invoice_visible'], isFalse);
      expect(metadata['notification_visible'], isFalse);
      expect(metadata['qr_visible'], isTrue);
    },
  );

  test('invoice visibility knobs persist without a second invoice system', () {
    final registry = FeatureRegistry.defaults();
    final invoice = AdminFeatureConfiguration.fromRegistry(
      registry,
    ).firstWhere((item) => item.id == FeatureId.invoice);

    invoice.update(
      registry,
      invoiceVisible: true,
      emailVisible: false,
      notificationVisible: false,
      qrVisible: false,
      showPdf: false,
      showPrint: true,
      showShare: false,
    );

    final display = InvoiceDisplayConfig.fromFeature(
      registry.configOf(FeatureId.invoice),
    );
    expect(display.showPdf, isFalse);
    expect(display.showPrint, isTrue);
    expect(display.showShare, isFalse);
    expect(display.showEmailStatus, isFalse);
    expect(display.showNotificationStatus, isFalse);
    expect(display.showQr, isFalse);
  });
}
