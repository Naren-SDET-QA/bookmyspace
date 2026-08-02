import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';

/// Venue details screen.
///
/// Full implementation (gallery, amenities, availability, booking CTA) lands in
/// Milestone 3-4. This scaffold renders the route and extracts the id.
class VenueDetailsScreen extends StatelessWidget {
  const VenueDetailsScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.venueDetails)),
      body: EmptyState(
        icon: Icons.apartment_rounded,
        title: 'Venue #$venueId',
        message: 'Venue details load in Milestone 3.',
        action: OutlinedButton(
          onPressed: () => context.pop(),
          child: Text(l10n.back),
        ),
      ),
    );
  }
}
