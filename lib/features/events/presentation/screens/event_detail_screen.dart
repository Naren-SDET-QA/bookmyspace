import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/event.dart';
import '../event_providers.dart';

/// Event details with live capacity and a register/cancel action.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        data: (event) => _EventBody(event: event),
      ),
      bottomNavigationBar: eventAsync.maybeWhen(
        data: (event) => event.isPast ? null : _ActionBar(event: event),
        orElse: () => null,
      ),
    );
  }
}

class _EventBody extends ConsumerWidget {
  const _EventBody({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final starts = event.startsAt;
    final ends = event.endsAt;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          flexibleSpace: FlexibleSpaceBar(
            background: AppNetworkImage(
              url: event.coverImage,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.event_rounded,
                  text:
                      '${DateFormat.yMMMd().format(starts)} · '
                      '${DateFormat.jm().format(starts)} – ${DateFormat.jm().format(ends)}',
                ),
                if (event.venueName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: event.venueName,
                  ),
                ],
                const SizedBox(height: 16),
                _SeatsCard(event: event),
                const SizedBox(height: 20),
                if (event.description.isNotEmpty) ...[
                  Text(l10n.details, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    event.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.brand),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SeatsCard extends StatelessWidget {
  const _SeatsCard({required this.event});

  final Event event;

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
                    event.isFree
                        ? l10n.freeEvent
                        : formatInr(event.ticketPrice),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.seatsLeft > 0
                        ? l10n.seatsLeft.replaceAll(
                            '{count}',
                            '${event.seatsLeft}',
                          )
                        : l10n.soldOut,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: event.seatsLeft > 0
                          ? theme.colorScheme.onSurfaceVariant
                          : AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
            if (event.userRegistered)
              Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.brand,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.registered, style: theme.textTheme.labelMedium),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.event});

  final Event event;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  Event get event => widget.event;

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      await ref.read(registerForEventProvider(event.id).future);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelRegistration),
        content: Text(l10n.cancelRegistrationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(cancelEventRegistrationProvider(event.id).future);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.registrationCancelled)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: event.userRegistered
            ? OutlinedButton.icon(
                onPressed: _busy ? null : _confirmCancel,
                icon: const Icon(Icons.event_busy_rounded),
                label: Text(_busy ? l10n.loading : l10n.cancelRegistration),
              )
            : FilledButton.icon(
                onPressed: _busy || event.seatsLeft <= 0 ? null : _register,
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  event.isFree
                      ? '${l10n.registerNow} · ${l10n.freeEvent}'
                      : '${l10n.registerNow} · ${formatInr(event.ticketPrice)}',
                ),
              ),
      ),
    );
  }
}
