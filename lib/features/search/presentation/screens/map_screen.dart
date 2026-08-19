import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../home/presentation/customer_section_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';

/// Map view of the current search results.
///
/// Reads the same [searchResultsProvider] as the search screen, so the map
/// always shows only the selected section's venues with the active
/// category/filters/location applied.
class SearchMapScreen extends ConsumerStatefulWidget {
  const SearchMapScreen({super.key});

  @override
  ConsumerState<SearchMapScreen> createState() => _SearchMapScreenState();
}

class _SearchMapScreenState extends ConsumerState<SearchMapScreen> {
  String? _selectedId;
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _focusVenue(Venue venue) {
    setState(() => _selectedId = venue.id);
    _mapController.move(
      LatLng(venue.latitude, venue.longitude),
      _mapController.camera.zoom >= 13 ? _mapController.camera.zoom : 13,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(searchResultsProvider);
    final section = ref.watch(selectedCustomerSectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          section == null
              ? l10n.viewOnMap
              : '${section.emoji} ${section.title} · Map',
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(searchResultsProvider),
        ),
        data: (venues) {
          if (venues.isEmpty) {
            return const EmptyState(
              icon: Icons.map_outlined,
              title: 'No results on the map',
              message:
                  'Adjust your search, filters or location to see venues here.',
            );
          }
          final selected = venues
              .where((v) => v.id == _selectedId)
              .firstOrNull;
          return ResponsiveLayoutBuilder(
            builder: (context, responsive) {
              final map = FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(venues.first.latitude, venues.first.longitude),
                  initialZoom: 11,
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                  onTap: (_, _) => setState(() => _selectedId = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bookmyspace.app',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final venue in venues)
                        Marker(
                          point: LatLng(venue.latitude, venue.longitude),
                          width: 42,
                          height: 42,
                          child: GestureDetector(
                            onTap: () => _focusVenue(venue),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _selectedId == venue.id
                                    ? AppTheme.brand
                                    : Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedId == venue.id
                                      ? Colors.white
                                      : AppTheme.brand,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.place_rounded,
                                size: 24,
                                color: AppTheme.brand,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );

              if (responsive.isCompact) {
                return Stack(
                  children: [
                    Positioned.fill(child: map),
                    if (selected != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 16,
                        child: _VenueMapCard(
                          venue: selected,
                          distanceKm: selected.distanceKm,
                          onTap: () => context.push(
                            AppRoutes.venueDetails.replaceAll(':id', selected.id),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      bottom: 16,
                      child: _MapCountBadge(count: venues.length),
                    ),
                  ],
                );
              }

              // Tablet / desktop: map + side list.
              return Row(
                children: [
                  SizedBox(
                    width: 360,
                    child: _VenueListPanel(
                      venues: venues,
                      selectedId: _selectedId,
                      onSelect: _focusVenue,
                    ),
                  ),
                  Expanded(child: map),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MapCountBadge extends StatelessWidget {
  const _MapCountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        '$count ${count == 1 ? 'place' : 'places'}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _VenueMapCard extends StatelessWidget {
  const _VenueMapCard({
    required this.venue,
    required this.onTap,
    this.distanceKm,
  });

  final Venue venue;
  final VoidCallback onTap;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = CustomerSectionCatalog.sectionForVenue(venue);
    final bookable = section?.isBookable ?? true;
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: venue.coverImageUrl.isEmpty
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.location_city_rounded),
                    )
                  : AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    venue.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    venue.address,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (venue.avgRating > 0) ...[
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        Text(
                          ' ${venue.avgRating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (distanceKm != null)
                        Text(
                          '${distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      const Spacer(),
                      Text(
                        '₹${venue.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (bookable)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.brand,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VenueListPanel extends StatelessWidget {
  const _VenueListPanel({
    required this.venues,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Venue> venues;
  final String? selectedId;
  final ValueChanged<Venue> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: venues.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final venue = venues[i];
          final selected = venue.id == selectedId;
          return InkWell(
            onTap: () => onSelect(venue),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venue.city}${venue.distanceKm != null ? ' · ${venue.distanceKm!.toStringAsFixed(1)} km' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}