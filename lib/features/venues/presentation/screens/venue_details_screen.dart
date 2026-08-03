import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/venue.dart';
import '../venue_providers.dart';
import '../widgets/venue_badges.dart';

/// Full venue details: gallery, about, amenities, hours, pricing and map.
class VenueDetailsScreen extends ConsumerWidget {
  const VenueDetailsScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailsProvider(venueId));

    return Scaffold(
      body: venueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
        ),
        data: (venue) => _VenueDetailsBody(venue: venue),
      ),
      bottomNavigationBar: venueAsync.maybeWhen(
        data: (venue) => venue.isActive ? _BookingBar(venue: venue) : null,
        orElse: () => null,
      ),
    );
  }
}

class _VenueDetailsBody extends ConsumerWidget {
  const _VenueDetailsBody({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 240,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (venue.images.isNotEmpty)
                  PageView.builder(
                    itemCount: venue.images.length,
                    itemBuilder: (context, i) => AppNetworkImage(
                      url: venue.images[i].url,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const ColoredBox(
                    color: AppTheme.brandLight,
                    child: Center(
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (venue.images.length > 1)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${venue.images.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            favorite.when(
              data: (isFav) => IconButton(
                onPressed: () =>
                    ref.read(toggleFavoriteProvider(venue.id).future),
                icon: Icon(
                  isFav ?? false
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  color: isFav ?? false ? AppTheme.accent : null,
                ),
              ),
              loading: () => const IconButton(
                onPressed: null,
                icon: Icon(Icons.favorite_outline_rounded),
              ),
              error: (_, _) => const IconButton(
                onPressed: null,
                icon: Icon(Icons.favorite_outline_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (venue.isVerified) const VerifiedBadge(),
                  ],
                ),
                if (venue.ratingCount > 0) ...[
                  const SizedBox(height: 6),
                  RatingBadge(
                    rating: venue.avgRating,
                    count: venue.ratingCount,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppTheme.brand,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venue.address,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (venue.description.isNotEmpty) ...[
                  Text(l10n.aboutThisVenue, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    venue.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _PricingCard(venue: venue),
                const SizedBox(height: 20),
                if (venue.facilities.isNotEmpty) ...[
                  Text(l10n.amenities, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: venue.facilities
                        .map(
                          (f) => Chip(
                            avatar: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: AppTheme.brand,
                            ),
                            label: Text(f.facility),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (venue.operatingHours.isNotEmpty) ...[
                  Text(l10n.operatingHours, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _HoursList(hours: venue.operatingHours),
                  const SizedBox(height: 20),
                ],
                if (venue.foodOptions.isNotEmpty ||
                    venue.parkingCapacity > 0) ...[
                  Text(l10n.details, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.restaurant_rounded,
                    label: l10n.foodOptions,
                    value: venue.foodOptions.isEmpty ? '—' : venue.foodOptions,
                  ),
                  _DetailRow(
                    icon: Icons.local_parking_rounded,
                    label: l10n.parking,
                    value: venue.parkingCapacity > 0
                        ? '${venue.parkingCapacity} vehicles'
                        : '—',
                  ),
                  _DetailRow(
                    icon: Icons.receipt_long_rounded,
                    label: l10n.taxRate,
                    value: '${venue.taxRate.toStringAsFixed(0)}%',
                  ),
                  const SizedBox(height: 20),
                ],
                Text(l10n.address, style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                _VenueMap(
                  latitude: venue.latitude,
                  longitude: venue.longitude,
                  name: venue.name,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      color: AppTheme.brand.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.basePrice,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatInr(venue.price),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (venue.capacity > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.capacity,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${venue.capacity}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HoursList extends StatelessWidget {
  const _HoursList({required this.hours});

  final List<VenueOperatingHours> hours;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: hours.map((h) {
        final label = _dayNames[h.dayOfWeek.clamp(0, 6)];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Text(
                  h.isClosed ? 'Closed' : '${h.opensAt} – ${h.closesAt}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _VenueMap extends StatelessWidget {
  const _VenueMap({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  final double latitude;
  final double longitude;
  final String name;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags:
                  InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bookmyspace.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: AppTheme.brand,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: () =>
              context.push('/venues/${venue.id}/book', extra: venue),
          icon: const Icon(Icons.event_available_rounded),
          label: Text('${l10n.bookNow} · ${formatInr(venue.price)}'),
        ),
      ),
    );
  }
}
