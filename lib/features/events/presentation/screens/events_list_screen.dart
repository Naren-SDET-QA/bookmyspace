import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../event_providers.dart';
import '../widgets/event_card.dart';

/// All upcoming events, soonest first.
class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(upcomingEventsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.upcomingEvents)),
      body: events.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, i) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 220, radius: 16),
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(upcomingEventsProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.event_available_rounded,
                title: l10n.noUpcomingEvents,
                message: l10n.noUpcomingEventsMessage,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EventCard(event: items[i]),
                ),
              ),
      ),
    );
  }
}
