import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FeatureRegistry.reset);
  tearDown(FeatureRegistry.reset);

  test('configuration is centralized with safe defaults enabled', () {
    final registry = FeatureRegistry.defaults();
    expect(registry.configOf(FeatureId.maps).enabled, isTrue);
    expect(registry.configOf(FeatureId.pg).enabled, isTrue);
    expect(registry.configOf(FeatureId.razorpay).provider, 'razorpay');
    FeatureRegistry.configure(
      FeatureId.maps,
      enabled: false,
      provider: 'flutter_map',
      config: const {'tile': 'osm'},
    );
    expect(FeatureRegistry.instance.isEnabled(FeatureId.maps), isFalse);
    expect(FeatureRegistry.instance.configOf(FeatureId.maps).config['tile'], 'osm');
    expect(FeatureRegistry.instance.isEnabled(FeatureId.pg), isTrue);
  });

  test('enabled feature is exposed and disabled feature is hidden', () {
    final registry = FeatureRegistry.defaults();
    expect(registry.isExposed(FeatureId.events), isTrue);
    expect(registry.isExposed(FeatureId.courses), isTrue);

    registry.apply(FeatureId.events, enabled: false);
    expect(registry.isEnabled(FeatureId.events), isFalse);
    expect(registry.isExposed(FeatureId.events), isFalse);
    expect(registry.isExposed(FeatureId.courses), isTrue);
  });

  test('dependency failure is handled safely without crashing', () {
    final registry = FeatureRegistry.defaults()
      ..apply(FeatureId.location, enabled: false);

    final booking = registry.availability(FeatureId.booking);
    expect(booking.enabled, isTrue);
    expect(booking.available, isFalse);
    expect(booking.missingDependencies, contains(FeatureId.location));
    expect(booking.reason, isNotEmpty);
    expect(registry.isExposed(FeatureId.booking), isFalse);
    expect(registry.isExposed(FeatureId.maps), isFalse);
  });

  test('optional payment dependency does not hide booking', () {
    final registry = FeatureRegistry.defaults()
      ..apply(FeatureId.payments, enabled: false);

    expect(registry.isExposed(FeatureId.booking), isTrue);
    expect(registry.isExposed(FeatureId.payments), isFalse);
    expect(registry.isExposed(FeatureId.razorpay), isFalse);
  });

  test('disabled feature routes redirect home after auth gating', () {
    FeatureRegistry.configure(FeatureId.events, enabled: false);
    final redirect = resolveAppRedirect(
      location: AppRoutes.eventsList,
      currentUser: null,
      authReady: true,
      allowUnauthenticatedTestAccess: true,
      features: FeatureRegistry.instance,
    );
    expect(redirect, AppRoutes.home);
  });

  test('enabled feature routes stay available', () {
    final redirect = resolveAppRedirect(
      location: AppRoutes.eventsList,
      currentUser: null,
      authReady: true,
      allowUnauthenticatedTestAccess: true,
      features: FeatureRegistry.defaults(),
    );
    expect(redirect, isNull);
  });

  test('home sections follow the registry without deleting modules', () {
    final allOn = FeatureRegistry.defaults().visibleHomeSections();
    expect(allOn, hasLength(4));
    expect(
      allOn,
      ['function_halls', 'lodge_rooms', 'pg_hostels', 'institutes_classes'],
    );

    final noPg = FeatureRegistry.defaults()..apply(FeatureId.pg, enabled: false);
    expect(noPg.visibleHomeSections(), hasLength(3));
    expect(
      noPg.visibleHomeSections().any((id) => id == 'pg_hostels'),
      isFalse,
    );
  });

  test('search visibility follows FeatureConfig without deleting modules', () {
    final registry = FeatureRegistry.defaults()
      ..apply(
        FeatureId.functionHall,
        config: const {'search_visible': false},
      );
    expect(registry.visibleSearchSections(), isNot(contains('function_halls')));
    expect(registry.visibleSearchSections(), contains('lodge_rooms'));
    expect(registry.isBookingEnabled(FeatureId.functionHall), isTrue);
  });

  test('disabled maps route redirects home after auth gating', () {
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    final redirect = resolveAppRedirect(
      location: AppRoutes.map,
      currentUser: null,
      authReady: true,
      allowUnauthenticatedTestAccess: true,
      features: FeatureRegistry.instance,
    );
    expect(redirect, AppRoutes.home);
  });

  test('unauthenticated /register stays public when registration is enabled', () {
    final redirect = resolveAppRedirect(
      location: AppRoutes.unifiedRegistration,
      currentUser: null,
      authReady: true,
      features: FeatureRegistry.defaults(),
    );
    expect(redirect, isNull);
  });

  test('unauthenticated /register still runs feature redirect when disabled', () {
    final registry = FeatureRegistry.defaults()
      ..apply(FeatureId.registration, enabled: false);
    final redirect = resolveAppRedirect(
      location: AppRoutes.unifiedRegistration,
      currentUser: null,
      authReady: true,
      features: registry,
    );
    expect(redirect, AppRoutes.home);
  });

  test('pay route requires both payments and razorpay', () {
    final noRazorpay = FeatureRegistry.defaults()
      ..apply(FeatureId.razorpay, enabled: false);
    expect(
      resolveAppRedirect(
        location: '/bookings/b1/pay',
        currentUser: null,
        authReady: true,
        allowUnauthenticatedTestAccess: true,
        features: noRazorpay,
      ),
      AppRoutes.home,
    );
    expect(
      resolveAppRedirect(
        location: AppRoutes.paymentHistory,
        currentUser: null,
        authReady: true,
        allowUnauthenticatedTestAccess: true,
        features: noRazorpay,
      ),
      isNull,
    );

    final noPayments = FeatureRegistry.defaults()
      ..apply(FeatureId.payments, enabled: false);
    expect(
      resolveAppRedirect(
        location: '/bookings/b1/pay',
        currentUser: null,
        authReady: true,
        allowUnauthenticatedTestAccess: true,
        features: noPayments,
      ),
      AppRoutes.home,
    );
  });
}
