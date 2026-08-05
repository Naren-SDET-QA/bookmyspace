import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';

/// Saved (favourited) venues — prototype `renderSaved` with a soft pill header.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Saved 💜',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  PrototypeIconButton(
                    icon: Icons.favorite_rounded,
                    tooltip: l10n.savedVenues,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: favorites.when(
                data: (venues) {
                  if (venues.isEmpty) {
                    return const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'No favourites yet',
                      message: 'Tap the heart on any venue to keep it here.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(favoritesProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      itemCount: venues.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          VenueCard(venue: venues[i], compact: true),
                    ),
                  );
                },
                loading: () => const ListSkeleton(),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(favoritesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
