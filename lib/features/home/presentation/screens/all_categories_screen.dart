import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../admin/domain/content_models.dart';

/// All Categories screen — presents the full canonical category catalog grouped
/// logically. Tiles use the same PrototypeVisuals category tile styling so the
/// look & feel stays consistent with the Home screen.
class AllCategoriesScreen extends StatelessWidget {
  const AllCategoriesScreen({super.key});

  static const Map<String, List<HomeCategoryTile>> _groups = {
    'Venues & Spaces': [
      HomeCategoryTile(id: 'function_hall', tileKey: 'function_hall', label: 'Function Hall', emoji: '🏛️', routeTarget: 'function_hall'),
      HomeCategoryTile(id: 'marriage_hall', tileKey: 'marriage_hall', label: 'Marriage Hall', emoji: '💍', routeTarget: 'marriage_hall'),
      HomeCategoryTile(id: 'banquet_hall', tileKey: 'banquet_hall', label: 'Banquet Hall', emoji: '🍽️', routeTarget: 'banquet_hall'),
      HomeCategoryTile(id: 'convention_center', tileKey: 'convention_center', label: 'Convention Center', emoji: '🏢', routeTarget: 'convention_center'),
      HomeCategoryTile(id: 'conference_room', tileKey: 'conference_room', label: 'Conference Room', emoji: '📊', routeTarget: 'conference_room'),
      HomeCategoryTile(id: 'community_hall', tileKey: 'community_hall', label: 'Community Hall', emoji: '👥', routeTarget: 'community_hall'),
      HomeCategoryTile(id: 'party_hall', tileKey: 'party_hall', label: 'Party Hall', emoji: '🎉', routeTarget: 'party_hall'),
      HomeCategoryTile(id: 'farm_house', tileKey: 'farm_house', label: 'Farm House', emoji: '🌳', routeTarget: 'farm_house'),
      HomeCategoryTile(id: 'auditorium', tileKey: 'auditorium', label: 'Auditorium', emoji: '🎭', routeTarget: 'auditorium'),
      HomeCategoryTile(id: 'exhibition_center', tileKey: 'exhibition_center', label: 'Exhibition Center', emoji: '🖼️', routeTarget: 'exhibition_center'),
      HomeCategoryTile(id: 'open_grounds', tileKey: 'open_grounds', label: 'Open Grounds', emoji: '🌾', routeTarget: 'open_grounds'),
    ],
    'Stays & Living': [
      HomeCategoryTile(id: 'hotel', tileKey: 'hotel', label: 'Hotels & Resorts', emoji: '🏨', routeTarget: 'stays'),
      HomeCategoryTile(id: 'pg', tileKey: 'pg', label: 'PG / Co-Living', emoji: '🏠', routeTarget: 'pg'),
    ],
    'Business': [
      HomeCategoryTile(id: 'meeting_room', tileKey: 'meeting_room', label: 'Meeting Rooms', emoji: '🤝', routeTarget: 'meeting_room'),
      HomeCategoryTile(id: 'coworking_space', tileKey: 'coworking_space', label: 'Coworking Spaces', emoji: '💻', routeTarget: 'coworking_space'),
    ],
    'Education': [
      HomeCategoryTile(id: 'training_institute', tileKey: 'training_institute', label: 'Training Institutes', emoji: '🎓', routeTarget: 'training_institute'),
      HomeCategoryTile(id: 'tuition_center', tileKey: 'tuition_center', label: 'Tuition Centers', emoji: '📚', routeTarget: 'tuition_center'),
      HomeCategoryTile(id: 'coaching_center', tileKey: 'coaching_center', label: 'Coaching Centers', emoji: '✏️', routeTarget: 'coaching_center'),
      HomeCategoryTile(id: 'classes', tileKey: 'classes', label: 'Classes', emoji: '🎓', routeTarget: 'classes'),
      HomeCategoryTile(id: 'courses', tileKey: 'courses', label: 'Courses', emoji: '📚', routeTarget: 'courses'),
    ],
    'Sports': [
      HomeCategoryTile(id: 'sports_ground', tileKey: 'sports_ground', label: 'Sports Grounds', emoji: '🏏', routeTarget: 'sports_ground'),
      HomeCategoryTile(id: 'cricket_ground', tileKey: 'cricket_ground', label: 'Cricket Grounds', emoji: '🏏', routeTarget: 'cricket_ground'),
      HomeCategoryTile(id: 'football_ground', tileKey: 'football_ground', label: 'Football Grounds', emoji: '⚽', routeTarget: 'football_ground'),
      HomeCategoryTile(id: 'indoor_stadium', tileKey: 'indoor_stadium', label: 'Indoor Stadiums', emoji: '🏟️', routeTarget: 'indoor_stadium'),
      HomeCategoryTile(id: 'club_house', tileKey: 'club_house', label: 'Club House', emoji: '🍸', routeTarget: 'club_house'),
    ],
    'Entertainment': [
      HomeCategoryTile(id: 'movie_theater', tileKey: 'movie_theater', label: 'Movie Theaters', emoji: '🎬', routeTarget: 'movie_theater'),
      HomeCategoryTile(id: 'events', tileKey: 'events', label: 'Events', emoji: '📅', routeTarget: 'events'),
    ],
    'Public / Other': [
      HomeCategoryTile(id: 'govt_hall', tileKey: 'govt_hall', label: 'Government Halls', emoji: '🏛️', routeTarget: 'govt_hall'),
      HomeCategoryTile(id: 'local_jobs', tileKey: 'local_jobs', label: 'Local Jobs', emoji: '💼', routeTarget: 'local_jobs'),
    ],
    'Devotional': [
      HomeCategoryTile(id: 'devotional', tileKey: 'devotional', label: 'Devotional Events', emoji: '🙏', routeTarget: 'devotional'),
      HomeCategoryTile(id: 'devotional_hindu', tileKey: 'devotional_hindu', label: 'Hindu', emoji: '🕉️', routeTarget: 'devotional_hindu'),
      HomeCategoryTile(id: 'devotional_muslim', tileKey: 'devotional_muslim', label: 'Muslim', emoji: '☪️', routeTarget: 'devotional_muslim'),
      HomeCategoryTile(id: 'devotional_christian', tileKey: 'devotional_christian', label: 'Christian', emoji: '✝️', routeTarget: 'devotional_christian'),
      HomeCategoryTile(id: 'devotional_buddhist', tileKey: 'devotional_buddhist', label: 'Buddhist', emoji: '☸️', routeTarget: 'devotional_buddhist'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allCategories),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in _groups.entries) _buildGroup(context, entry.key, entry.value),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String title, List<HomeCategoryTile> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
        ),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 6 : MediaQuery.of(context).size.width >= 600 ? 4 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final t in tiles) _categoryTile(context, t),
          ],
        ),
      ],
    );
  }

  Widget _categoryTile(BuildContext context, HomeCategoryTile t) {
    final emoji = PrototypeVisuals.emojiForCategorySlug(t.tileKey, icon: t.emoji);
    return GestureDetector(
      onTap: () {
        // Use existing search fallback where a dedicated module isn't present.
        switch (t.routeTarget) {
          case 'courses':
            Navigator.pushNamed(context, '/courses');
            return;
          case 'events':
            Navigator.pushNamed(context, '/events');
            return;
          case 'pg':
            Navigator.pushNamed(context, '/pg');
            return;
          case 'stays':
            Navigator.pushNamed(context, '/stays');
            return;
          case 'meeting_room':
          case 'meeting_rooms':
            Navigator.pushNamed(context, '/meeting-rooms');
            return;
          case 'sports':
          case 'sports_ground':
            Navigator.pushNamed(context, '/sports');
            return;
          default:
            Navigator.pushNamed(context, '/search', arguments: {'category': t.tileKey});
            return;
        }
      },
      child: Container(
        decoration: PrototypeVisuals.categoryTileDecoration(),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: PrototypeVisuals.emojiStyle()),
            const SizedBox(height: 8),
            Text(
              t.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
