import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_providers.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/modular/plugin_kind.dart';
import 'package:bookmyspace/core/modular/plugins/flutter_map_plugin.dart';
import 'package:bookmyspace/core/modular/plugins/map_provider.dart';
import 'package:bookmyspace/core/modular/provider_registry.dart';
import 'package:bookmyspace/core/modular/register_default_plugins.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/home/presentation/customer_section_providers.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_screen.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/search/presentation/screens/map_screen.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/mock_auth_repository.dart';
import '../../features/courses/mock_course_repository.dart';
import '../../features/events/mock_event_repository.dart';
import '../../features/notifications/mock_notification_repository.dart';
import '../../features/venues/mock_venue_repository.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

class _RecordingMapProvider implements MapProvider {
  @override
  String get id => 'fake_map';
  int controllersCreated = 0;
  bool _ready = false;

  @override
  bool get initialized => _ready;

  @override
  String get tileUrlTemplate => FlutterMapPlugin.defaultTileUrl;

  @override
  String get userAgentPackageName => FlutterMapPlugin.defaultUserAgent;

  @override
  MapController createController() {
    controllersCreated++;
    return MapController();
  }

  @override
  Future<void> ensureInitialized() async => _ready = true;

  @override
  Future<void> dispose() async => _ready = false;
}

List<Override> _overrides({
  required ProviderRegistry plugins,
  MockVenueRepository? venues,
}) {
  return [
    providerRegistryProvider.overrideWithValue(plugins),
    venueRepositoryProvider.overrideWithValue(venues ?? MockVenueRepository()),
    authRepositoryProvider.overrideWithValue(
      MockAuthRepository(initialUser: _user),
    ),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
    notificationRepositoryProvider.overrideWithValue(
      MockNotificationRepository(),
    ),
  ];
}

Widget _app(List<Override> overrides, {required Widget home}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: home,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  setUp(FeatureRegistry.reset);
  tearDown(FeatureRegistry.reset);

  test('map plugin is cached and SDK controller is lazy', () {
    var pluginBuilt = 0;
    var controllers = 0;
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(
      plugins,
      mapFactory: () {
        pluginBuilt++;
        return FlutterMapPlugin(
          controllerFactory: () {
            controllers++;
            return MapController();
          },
        );
      },
    );

    expect(pluginBuilt, 0);
    expect(plugins.isInitialized(PluginKind.map), isFalse);

    final first = plugins.resolve(PluginKind.map);
    expect(pluginBuilt, 1);
    expect(plugins.resolve(PluginKind.map), same(first));
    expect(pluginBuilt, 1);
    expect(first, isA<MapProvider>());
    expect(plugins.isInitialized(PluginKind.map), isFalse);
    expect(controllers, 0);

    final controller = (first as MapProvider).createController();
    expect(controllers, 1);
    expect(controller, isA<MapController>());
    first.createController();
    expect(controllers, 2);
  });

  test('disabled maps never constructs the plugin or MapController', () {
    var pluginBuilt = 0;
    var controllers = 0;
    final features = FeatureRegistry.defaults()
      ..apply(FeatureId.maps, enabled: false);
    final plugins = ProviderRegistry(features: features);
    registerDefaultPlugins(
      plugins,
      mapFactory: () {
        pluginBuilt++;
        return FlutterMapPlugin(
          controllerFactory: () {
            controllers++;
            return MapController();
          },
        );
      },
    );

    expect(plugins.tryResolve(PluginKind.map), isNull);
    expect(pluginBuilt, 0);
    expect(controllers, 0);
  });

  test('map provider can be replaced', () async {
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(plugins, mapFactory: FlutterMapPlugin.new);
    final first = plugins.resolve(PluginKind.map);
    expect(first.id, 'flutter_map');

    await plugins.replace(PluginKind.map, () => _RecordingMapProvider());
    final second = plugins.resolve(PluginKind.map);
    expect(second, isA<_RecordingMapProvider>());
    expect(second.id, 'fake_map');
    expect(identical(first, second), isFalse);
  });

  test('disabled maps route redirects home', () {
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    expect(
      resolveAppRedirect(
        location: AppRoutes.map,
        currentUser: null,
        authReady: true,
        allowUnauthenticatedTestAccess: true,
        features: FeatureRegistry.instance,
      ),
      AppRoutes.home,
    );
  });

  testWidgets('maps enabled shows existing flutter_map markers and search', (
    tester,
  ) async {
    var controllers = 0;
    final venues = MockVenueRepository();
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(
      plugins,
      mapFactory: () => FlutterMapPlugin(
        controllerFactory: () {
          controllers++;
          return MapController();
        },
      ),
    );

    await tester.pumpWidget(
      _app(
        [
          ..._overrides(plugins: plugins, venues: venues),
          selectedCustomerSectionProvider.overrideWith(
            (ref) => CustomerSection.functionHalls,
          ),
        ],
        home: const SearchMapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byIcon(Icons.place_rounded), findsWidgets);
    expect(controllers, 1);
    expect(venues.lastSearchQuery, isNotNull);
    expect(venues.lastSearchQuery?.sectionId, 'function_halls');
    expect(find.widgetWithText(ChoiceChip, '🏛️ Function Halls'), findsOneWidget);
  });

  testWidgets('maps disabled never constructs SDK or fetches map search', (
    tester,
  ) async {
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    var pluginBuilt = 0;
    var controllers = 0;
    final venues = MockVenueRepository();
    final plugins = ProviderRegistry(features: FeatureRegistry.instance);
    registerDefaultPlugins(
      plugins,
      mapFactory: () {
        pluginBuilt++;
        return FlutterMapPlugin(
          controllerFactory: () {
            controllers++;
            return MapController();
          },
        );
      },
    );

    await tester.pumpWidget(
      _app(
        _overrides(plugins: plugins, venues: venues),
        home: const SearchMapScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsNothing);
    expect(pluginBuilt, 0);
    expect(controllers, 0);
    expect(venues.lastSearchQuery, isNull);
  });

  testWidgets('maps disabled hides home and search map entries', (tester) async {
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    final plugins = ProviderRegistry(features: FeatureRegistry.instance);
    registerDefaultPlugins(plugins);

    await tester.pumpWidget(
      _app(_overrides(plugins: plugins), home: const HomeScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('View on map'), findsNothing);

    await tester.pumpWidget(
      _app(
        _overrides(plugins: plugins),
        home: const SearchScreen(initialSection: 'function_halls'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('View on map'), findsNothing);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
  });
}
