import 'package:bookmyspace/features/admin/domain/content_models.dart';
import 'package:bookmyspace/features/admin/presentation/content_providers.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_content_screen.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomepageContentConfig', () {
    test('parses remote config payload', () {
      final cfg = HomepageContentConfig.fromJson({
        'sections': [
          {
            'id': '1',
            'section_key': 'popular',
            'title': 'Popular venues',
            'emoji': '🏛️',
            'sort_order': 50,
            'is_visible': true,
            'config': {'limit': 10},
          },
        ],
        'category_tiles': [
          {
            'id': '2',
            'tile_key': 'function_hall',
            'label': 'Function Halls',
            'emoji': '🏛️',
            'route_target': 'search:function_hall',
            'sort_order': 10,
            'is_visible': true,
          },
        ],
        'home_banner': {
          'title': 'Hello',
          'subtitle': 'World',
          'is_visible': true,
        },
        'featured_offer': {'title': 'Promo', 'body': '₹999', 'is_visible': true},
        'default_commission_rate': {'rate': 12.5},
      });

      expect(cfg.sections, hasLength(1));
      expect(cfg.sections.first.sectionKey, 'popular');
      expect(cfg.categoryTiles.single.emoji, '🏛️');
      expect(cfg.defaultCommissionRate, 12.5);
      expect(cfg.isSectionVisible('popular'), isTrue);
      expect(cfg.homeBanner['title'], 'Hello');
    });

    test('blank tile emoji coalesces to prototype CATS by slug', () {
      final tile = HomeCategoryTile.fromJson({
        'id': '2',
        'tile_key': 'function_hall',
        'label': 'Function Halls',
        'emoji': '',
        'route_target': 'search:function_hall',
        'sort_order': 10,
        'is_visible': true,
      });
      expect(tile.emoji, '🏛️');

      final classes = HomeCategoryTile.fromJson({
        'id': '3',
        'tile_key': 'classes',
        'label': 'Classes',
        'emoji': '  ',
        'route_target': 'courses',
      });
      expect(classes.emoji, '🎓');
    });

    test('parses nested maps that are not Map<String, dynamic>', () {
      final cfg = HomepageContentConfig.fromJson({
        'category_tiles': [
          <dynamic, dynamic>{
            'id': '2',
            'tile_key': 'events',
            'label': 'Events',
            'emoji': '📅',
            'route_target': 'events',
            'sort_order': 30,
            'is_visible': true,
          },
        ],
      });
      expect(cfg.categoryTiles, hasLength(1));
      expect(cfg.categoryTiles.single.emoji, '📅');
    });

    test('AdminContentVenue maps pricing and owner_verified', () {
      final v = AdminContentVenue.fromJson({
        'id': 'v1',
        'name': 'Hall',
        'pricing_base_amount': 25000,
        'owner_verified': true,
        'is_featured': true,
        'offer_percent': 10,
      });
      expect(v.pricingBaseAmount, 25000);
      expect(v.ownerVerified, isTrue);
      expect(v.isFeatured, isTrue);
      expect(v.offerPercent, 10);
    });
  });

  testWidgets('admin dashboard includes Content & Pricing tile', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AdminDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Content & Pricing'), findsOneWidget);
  });

  testWidgets('admin content screen shows tabs and preview', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homepageContentConfigProvider.overrideWith(
            (ref) async => HomepageContentConfig(
              categoryTiles: const [
                HomeCategoryTile(
                  id: '1',
                  tileKey: 'function_hall',
                  label: 'Function Halls',
                  emoji: '🏛️',
                  routeTarget: 'search:function_hall',
                ),
              ],
              sections: const [
                HomepageSection(
                  id: '1',
                  sectionKey: 'popular',
                  title: 'Popular venues',
                  emoji: '🏛️',
                ),
              ],
              homeBanner: const {
                'title': 'Book spaces',
                'subtitle': 'Near you',
                'is_visible': true,
              },
              featuredOffer: const {
                'title': 'Featured',
                'body': 'From ₹999',
                'is_visible': true,
              },
              defaultCommissionRate: 10,
            ),
          ),
          adminHomepageSectionsProvider.overrideWith(
            (ref) async => const [
              HomepageSection(
                id: '1',
                sectionKey: 'popular',
                title: 'Popular venues',
                emoji: '🏛️',
                sortOrder: 50,
              ),
            ],
          ),
          adminCategoryTilesProvider.overrideWith(
            (ref) async => const [
              HomeCategoryTile(
                id: '1',
                tileKey: 'function_hall',
                label: 'Function Halls',
                emoji: '🏛️',
                routeTarget: 'search:function_hall',
              ),
            ],
          ),
          adminContentVenuesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: AdminContentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Content & Pricing'), findsOneWidget);
    expect(find.text('Homepage'), findsOneWidget);
    expect(find.text('Venues'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    expect(find.text('Preview'), findsWidgets);

    await tester.tap(find.text('Preview').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Customer home preview'), findsOneWidget);
    expect(find.textContaining('Function Halls'), findsWidgets);
  });
}
