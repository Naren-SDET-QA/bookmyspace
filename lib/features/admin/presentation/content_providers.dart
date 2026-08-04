import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/prototype_visuals.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/admin_content_repository.dart';
import '../domain/content_models.dart';
import '../infrastructure/supabase_admin_content_repository.dart';

final adminContentRepositoryProvider = Provider<AdminContentRepository>((ref) {
  return SupabaseAdminContentRepository(ref.watch(supabaseProvider));
});

/// Customer-facing homepage remote config (sections, tiles, banner, offers).
final homepageContentConfigProvider =
    FutureProvider<HomepageContentConfig>((ref) async {
      if (!AppConfig.hasSupabaseConfiguration) {
        return _demoHomepageContentConfig();
      }
      try {
        final remote =
            await ref.watch(adminContentRepositoryProvider).homepageConfig();
        if (remote.categoryTiles.isEmpty) {
          // RPC succeeded but tiles missing/blank — keep prototype CATS visible.
          return HomepageContentConfig(
            sections: remote.sections.isNotEmpty
                ? remote.sections
                : _demoHomepageContentConfig().sections,
            categoryTiles: _demoHomepageContentConfig().categoryTiles,
            venueCategories: remote.venueCategories,
            homeBanner: remote.homeBanner,
            featuredOffer: remote.featuredOffer,
            defaultCommissionRate: remote.defaultCommissionRate,
          );
        }
        return remote;
      } catch (_) {
        // Fall back so customer home still renders if RPC not migrated yet.
        return _demoHomepageContentConfig();
      }
    });

HomepageContentConfig _demoHomepageContentConfig() => HomepageContentConfig(
      categoryTiles: [
        for (final c in PrototypeVisuals.homeCategories)
          HomeCategoryTile(
            id: c.key,
            tileKey: c.key,
            label: c.label,
            emoji: c.emoji,
            routeTarget: c.key,
          ),
      ],
      sections: const [
        HomepageSection(
          id: 'categories',
          sectionKey: 'categories',
          title: 'Browse categories',
          emoji: '🗂️',
          sortOrder: 10,
        ),
        HomepageSection(
          id: 'events',
          sectionKey: 'events',
          title: 'Happening near you',
          emoji: '⚡',
          sortOrder: 20,
        ),
        HomepageSection(
          id: 'courses',
          sectionKey: 'courses',
          title: 'Popular institutes',
          emoji: '🎓',
          sortOrder: 30,
        ),
        HomepageSection(
          id: 'popular',
          sectionKey: 'popular',
          title: 'Popular venues',
          emoji: '🏛️',
          sortOrder: 50,
        ),
        HomepageSection(
          id: 'nearby',
          sectionKey: 'nearby',
          title: 'Nearby venues',
          emoji: '📍',
          sortOrder: 60,
        ),
      ],
    );

final adminHomepageSectionsProvider =
    FutureProvider.autoDispose<List<HomepageSection>>((ref) {
      return ref
          .watch(adminContentRepositoryProvider)
          .listHomepageSections(includeHidden: true);
    });

final adminCategoryTilesProvider =
    FutureProvider.autoDispose<List<HomeCategoryTile>>((ref) {
      return ref
          .watch(adminContentRepositoryProvider)
          .listCategoryTiles(includeHidden: true);
    });

final adminContentVenueQueryProvider = StateProvider<String>((ref) => '');

final adminContentVenuesProvider =
    FutureProvider.autoDispose<List<AdminContentVenue>>((ref) {
      final query = ref.watch(adminContentVenueQueryProvider);
      return ref
          .watch(adminContentRepositoryProvider)
          .listVenues(query: query.isEmpty ? null : query);
    });

final adminContentPreviewModeProvider = StateProvider<bool>((ref) => false);
