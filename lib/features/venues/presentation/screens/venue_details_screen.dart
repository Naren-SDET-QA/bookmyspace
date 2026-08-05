import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/maps/domain/geo_point.dart';
import '../../../../core/maps/presentation/map_view.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../venue_import/presentation/claim_venue_sheet.dart';
import '../../domain/venue.dart';
import '../venue_providers.dart';
import '../widgets/venue_badges.dart';

/// Full venue details: hero gallery, stats, amenities, availability calendar,
/// map, similar spaces and a sticky booking bar.
class VenueDetailsScreen extends ConsumerStatefulWidget {
  const VenueDetailsScreen({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends ConsumerState<VenueDetailsScreen> {
  DateTime? _selectedDate;
  SlotAvailability? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueDetailsProvider(widget.venueId));
    // Record the venue in the Home "Recently viewed" strip (session-only).
    ref.listen(venueDetailsProvider(widget.venueId), (previous, next) {
      final venue = next.valueOrNull;
      if (venue != null) {
        ref.read(recentlyViewedIdsProvider.notifier).record(venue.id);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: venueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(venueDetailsProvider(widget.venueId)),
        ),
        data: (venue) => _VenueDetailsBody(
          venue: venue,
          selectedDate: _selectedDate,
          selectedSlot: _selectedSlot,
          onDateSelected: (d) {
            setState(() {
              _selectedDate = d;
              _selectedSlot = null;
            });
          },
          onSlotSelected: (slot) => setState(() => _selectedSlot = slot),
        ),
      ),
      bottomNavigationBar: venueAsync.maybeWhen(
        data: (venue) => venue.isActive
            ? _BookingBar(
                venue: venue,
                selectedDate: _selectedDate,
                selectedSlot: _selectedSlot,
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

class _VenueDetailsBody extends ConsumerWidget {
  const _VenueDetailsBody({
    required this.venue,
    required this.selectedDate,
    required this.selectedSlot,
    required this.onDateSelected,
    required this.onSlotSelected,
  });

  final Venue venue;
  final DateTime? selectedDate;
  final SlotAvailability? selectedSlot;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<SlotAvailability> onSlotSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    final emoji = PrototypeVisuals.emojiForCategorySlug(
      venue.category?.slug,
      icon: venue.category?.icon,
    );

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 232,
          backgroundColor: AppTheme.surfaceLight,
          leading: _HeroIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
          actions: [
            _HeroIconButton(
              icon: Icons.ios_share_rounded,
              onPressed: () => _shareVenue(context),
              tooltip: 'Share',
            ),
            const SizedBox(width: 6),
            _HeroFavButton(
              favorite: favorite,
              onPressed: () =>
                  ref.read(toggleFavoriteProvider(venue.id).future),
            ),
            const SizedBox(width: 14),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gallery carousel (or gradient placeholder with emoji).
                if (venue.images.isNotEmpty)
                  PageView.builder(
                    itemCount: venue.images.length,
                    itemBuilder: (context, i) => AppNetworkImage(
                      url: venue.images[i].url,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: PrototypeVisuals.thumbGradientFor(venue.id),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: PrototypeVisuals.emojiStyle(fontSize: 76),
                      ),
                    ),
                  ),
                // Bottom fade for legibility.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 60,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.25),
                        ],
                      ),
                    ),
                  ),
                ),
                // Hero pills (prototype `.heroPills`).
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (venue.isFeatured)
                        const PrototypePill(
                          label: '⭐ Featured listing',
                        )
                      else
                        PrototypePill(label: emoji.isNotEmpty ? '🏛️ Venue' : ''),
                      PrototypePill(
                        label:
                            '${venue.avgRating > 0 ? venue.avgRating.toStringAsFixed(1) : 'New'}'
                            '${venue.ratingCount > 0 ? ' (${venue.ratingCount})' : ''}',
                        icon: Icons.star_rounded,
                      ),
                    ],
                  ),
                ),
                if (venue.images.length > 1)
                  Positioned(
                    bottom: 16,
                    right: 16,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Name + rating ----
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                            letterSpacing: -0.5,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      if (venue.isVerified) const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _openMap(context),
                        child: const Text(
                          'View on map',
                          style: TextStyle(
                            color: AppTheme.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ---- Stats row (prototype `.statRow`) ----
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrototypeStatBox(
                          value: venue.capacity > 0 ? '${venue.capacity}' : '—',
                          label: l10n.capacity,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: PrototypeStatBox(
                          value: formatInr(venue.price),
                          label: 'Per day',
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: PrototypeStatBox(
                          value: venue.avgRating > 0
                              ? '${venue.avgRating.toStringAsFixed(1)}★'
                              : 'New',
                          label: 'Rating',
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: PrototypeStatBox(
                          value: '20%',
                          label: 'Advance',
                        ),
                      ),
                    ],
                  ),
                  // ---- Facilities ----
                  if (venue.facilities.isNotEmpty) ...[
                    const PrototypeSectionHeader(
                      title: 'Facilities',
                      padding: EdgeInsets.only(top: 20),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: venue.facilities
                          .map(
                            (f) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: PrototypeVisuals.cardDecoration(),
                              child: Text(
                                f.facility,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  // ---- About ----
                  if (venue.description.isNotEmpty) ...[
                    const PrototypeSectionHeader(
                      title: 'About this venue',
                      padding: EdgeInsets.only(top: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      venue.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                  ],
                  // ---- Availability calendar ----
                  const PrototypeSectionHeader(
                    title: 'Availability',
                    padding: EdgeInsets.only(top: 20),
                  ),
                  const SizedBox(height: 10),
                  _AvailabilityCalendar(
                    venue: venue,
                    selectedDate: selectedDate,
                    selectedSlot: selectedSlot,
                    onDateSelected: onDateSelected,
                    onSlotSelected: onSlotSelected,
                  ),
                  // ---- Details ----
                  if (venue.operatingHours.isNotEmpty ||
                      venue.foodOptions.isNotEmpty ||
                      venue.parkingCapacity > 0) ...[
                    const PrototypeSectionHeader(
                      title: 'Details',
                      padding: EdgeInsets.only(top: 20),
                    ),
                    const SizedBox(height: 4),
                    if (venue.operatingHours.isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.schedule_rounded,
                        label: l10n.operatingHours,
                        value: _hoursSummary(venue.operatingHours),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _DetailRow(
                      icon: Icons.restaurant_rounded,
                      label: l10n.foodOptions,
                      value: venue.foodOptions.isEmpty
                          ? '—'
                          : venue.foodOptions,
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.local_parking_rounded,
                      label: l10n.parking,
                      value: venue.parkingCapacity > 0
                          ? '${venue.parkingCapacity} vehicles'
                          : '—',
                    ),
                  ],
                  // ---- Claim (when unclaimed) ----
                  if (venue.isClaimable && !venue.ownerVerified) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showClaimVenueSheet(
                          context,
                          ref,
                          venueId: venue.id,
                          venueName: venue.name,
                          isClaimable: venue.isClaimable,
                          ownerVerified: venue.ownerVerified,
                        ),
                        icon: const Text(
                          '🏠',
                          style: TextStyle(fontSize: 16),
                        ),
                        label: const Text('Claim This Venue'),
                      ),
                    ),
                  ],
                  // ---- Map ----
                  PrototypeSectionHeader(
                    title: l10n.address,
                    padding: const EdgeInsets.only(top: 20),
                  ),
                  const SizedBox(height: 10),
                  _VenueMap(
                    latitude: venue.latitude,
                    longitude: venue.longitude,
                    name: venue.name,
                  ),
                  // ---- Similar spaces ----
                  const SizedBox(height: 20),
                  _SimilarSpaces(currentVenueId: venue.id),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _hoursSummary(List<VenueOperatingHours> hours) {
    if (hours.isEmpty) return '—';
    final open = hours.where((h) => !h.isClosed).toList();
    if (open.isEmpty) return 'Closed today';
    final first = open.first;
    return '${first.opensAt} – ${first.closesAt}';
  }

  Future<void> _shareVenue(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: '${venue.name} on BookMySpace — book it now!'),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Link copied — share BookMySpace 🔗')),
    );
  }

  void _openMap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Google Maps… 🗺️')),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 19, color: AppTheme.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFavButton extends StatelessWidget {
  const _HeroFavButton({required this.favorite, required this.onPressed});

  final AsyncValue<bool?> favorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: favorite.when(
        data: (isFav) => Material(
          color: Colors.white.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                isFav ?? false
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                size: 19,
                color: isFav ?? false ? AppTheme.danger : AppTheme.ink,
              ),
            ),
          ),
        ),
        loading: () => _HeroIconButton(
          icon: Icons.favorite_outline_rounded,
          onPressed: () {},
          tooltip: 'Save',
        ),
        error: (_, _) => _HeroIconButton(
          icon: Icons.favorite_outline_rounded,
          onPressed: () {},
          tooltip: 'Save',
        ),
      ),
    );
  }
}

/// Inline availability calendar (prototype `.calCard` + `.slotWrap`).
///
/// Shows the current/next months, marks past days as closed and lets the user
/// pick a date to load live time slots from the booking backend. Slot
/// selection enables the sticky "Request Booking" CTA.
class _AvailabilityCalendar extends ConsumerStatefulWidget {
  const _AvailabilityCalendar({
    required this.venue,
    required this.selectedDate,
    required this.selectedSlot,
    required this.onDateSelected,
    required this.onSlotSelected,
  });

  final Venue venue;
  final DateTime? selectedDate;
  final SlotAvailability? selectedSlot;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<SlotAvailability> onSlotSelected;

  @override
  ConsumerState<_AvailabilityCalendar> createState() =>
      _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends ConsumerState<_AvailabilityCalendar> {
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  int _monthOffset = 0;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _shiftMonth(int delta) {
    setState(() {
      _monthOffset = (_monthOffset + delta).clamp(0, 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final now = DateTime.now();
    final month = DateTime(now.year, now.month + _monthOffset);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dart: Monday = 1 … Sunday = 7; grid starts on Sunday.
    final firstWeekday =
        (DateTime(month.year, month.month, 1).weekday) % 7;

    final selected = widget.selectedDate;

    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                Row(
                  children: [
                    _CalNavButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _monthOffset > 0,
                      onTap: () => _shiftMonth(-1),
                    ),
                    const SizedBox(width: 6),
                    _CalNavButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _monthOffset < 2,
                      onTap: () => _shiftMonth(1),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Weekday header (prototype `.wkRow`).
            Row(
              children: [
                for (final label in _weekdayLabels)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB0ABD0),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Day grid (prototype `.calGrid`).
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _buildDayCell(
                    DateTime(month.year, month.month, day),
                    now,
                    selected,
                  ),
              ],
            ),
            // Legend (prototype `.legend`).
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.line,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _LegendItem(color: Color(0xFF86EFAC), label: 'Available'),
                      _LegendItem(color: Color(0xFFFDA4AF), label: 'Booked'),
                      _LegendItem(color: Color(0xFFFCD34D), label: 'Partially available'),
                      _LegendItem(color: Color(0xFFD4D0E6), label: 'Past / Closed'),
                    ],
                  ),
                ),
              ),
            ),
            // Slots for the selected date (prototype `.slotWrap`).
            if (selected != null) ...[
              const SizedBox(height: 16),
              _CalendarSlots(
                venueId: venue.id,
                date: selected,
                selectedSlot: widget.selectedSlot,
                onSlotSelected: widget.onSlotSelected,
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '👆 Pick a date to see time slots & prices',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime now, DateTime? selected) {
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
    final isSelected = selected != null && _sameDay(date, selected);

    return GestureDetector(
      onTap: isPast ? null : () => widget.onDateSelected(date),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.brand
              : (isPast
                    ? const Color(0xFFF1F0F7)
                    : const Color(0xFFE9FBEF)),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected
                ? AppTheme.brand
                : (isPast ? Colors.transparent : const Color(0xFF86EFAC)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isPast
                      ? const Color(0xFFA5A0C4)
                      : const Color(0xFF15803D)),
          ),
        ),
      ),
    );
  }
}

class _CalNavButton extends StatelessWidget {
  const _CalNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppTheme.card : const Color(0xFFF6F5FB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 17,
            color: enabled ? AppTheme.ink : const Color(0xFFCFCCDF),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }
}

/// Slot picker for the selected calendar date (prototype `.slotCard` list).
class _CalendarSlots extends ConsumerWidget {
  const _CalendarSlots({
    required this.venueId,
    required this.date,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  final String venueId;
  final DateTime date;
  final SlotAvailability? selectedSlot;
  final ValueChanged<SlotAvailability> onSlotSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final availability = ref.watch(
      slotAvailabilityProvider(
        SlotAvailabilityQuery(venueId: venueId, date: date),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Slots for ${DateFormat('EEE, d MMM').format(date)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 10),
        availability.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
          error: (e, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Could not load slots — pull back and retry.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ),
          data: (slots) {
            if (slots.isEmpty) {
              return Text(
                l10n.noSlotsForDate,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                ),
              );
            }
            return Column(
              children: [
                for (final slot in slots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _CalendarSlotTile(
                      slot: slot,
                      isSelected: selectedSlot?.slotId == slot.slotId,
                      onTap: slot.isAvailable
                          ? () => onSlotSelected(slot)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CalendarSlotTile extends StatelessWidget {
  const _CalendarSlotTile({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final SlotAvailability slot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = slot.isAvailable;
    return Material(
      color: isSelected ? const Color(0xFFFAF8FF) : AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppTheme.brand : AppTheme.line,
          width: isSelected ? 1.5 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PrototypeVisuals.softIconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    _slotEmoji(slot.label),
                    style: PrototypeVisuals.emojiStyle(fontSize: 19),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${slot.displayStart} – ${slot.displayEnd}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!enabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8EE),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    _reasonLabel(slot.reason),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.danger,
                    ),
                  ),
                )
              else
                Text(
                  formatInr(slot.priceAmount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brand,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _slotEmoji(String label) => switch (label.toLowerCase()) {
    'morning' => '🌅',
    'evening' => '🌆',
    'full day' || 'fullday' => '☀️',
    'community hour' => '🤝',
    _ => '⏰',
  };

  String _reasonLabel(String reason) {
    return switch (reason) {
      'booked' => 'Booked',
      'held' => 'Unavailable',
      'blocked' => 'Blocked',
      'closed' => 'Closed',
      'inactive' => 'Closed',
      _ => 'Unavailable',
    };
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
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: PrototypeVisuals.softIconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
      ],
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
    final point = GeoPoint(latitude, longitude);
    return MapView(
      initialCenter: point,
      height: 160,
      markers: [MapMarkerData(point: point, label: name)],
    );
  }
}

class _SimilarSpaces extends ConsumerWidget {
  const _SimilarSpaces({required this.currentVenueId});

  final String currentVenueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularVenuesProvider);
    final venues =
        (popular.valueOrNull ?? const <Venue>[])
            .where((v) => v.id != currentVenueId && v.isActive)
            .take(6)
            .toList();
    if (venues.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PrototypeSectionHeader(
          title: 'Similar spaces',
          padding: EdgeInsets.only(top: 8),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: venues.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 250,
              child: AnimatedEntrance(
                child: SimilarVenueCard(venue: venues[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact, non-favourite card used only in "Similar spaces".
class SimilarVenueCard extends StatelessWidget {
  const SimilarVenueCard({super.key, required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final emoji = PrototypeVisuals.emojiForCategorySlug(
      venue.category?.slug,
      icon: venue.category?.icon,
    );
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.venueDetails.replaceAll(':id', venue.id),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 88,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: PrototypeVisuals.thumbGradientFor(venue.id),
                    ),
                  ),
                  if (venue.coverImageUrl.isNotEmpty)
                    AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover)
                  else
                    Center(
                      child: Text(
                        emoji,
                        style: PrototypeVisuals.emojiStyle(fontSize: 34),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          venue.city.isNotEmpty ? venue.city : venue.addressLine1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                      if (venue.avgRating > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: PrototypeVisuals.star,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          venue.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: PrototypeVisuals.starText,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatInr(venue.price),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brand,
                          ),
                        ),
                        const TextSpan(
                          text: ' /day',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky prototype `.ctaBar` with price + Book / Request Booking button.
class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.venue,
    this.selectedDate,
    this.selectedSlot,
  });

  final Venue venue;
  final DateTime? selectedDate;
  final SlotAvailability? selectedSlot;

  void _openBooking(BuildContext context) {
    final dateParam = selectedDate == null
        ? ''
        : '?date=${DateFormat('yyyy-MM-dd').format(selectedDate!)}';
    context.push(
      AppRoutes.bookingFlow.replaceAll(':id', venue.id) + dateParam,
      extra: venue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSlot = selectedSlot != null;
    final label = hasSlot ? 'Request Booking' : '${l10n.bookNow} · ${formatInr(venue.price)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSlot
                          ? '${selectedSlot!.label} · ${DateFormat('EEE, d MMM').format(selectedDate!)}'
                          : 'Full day from',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.muted,
                      ),
                    ),
                    Text(
                      hasSlot
                          ? formatInr(selectedSlot!.priceAmount)
                          : formatInr(venue.price),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PrototypeButton(
                  label: label,
                  onPressed: () => _openBooking(context),
                  icon: Icons.event_available_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
