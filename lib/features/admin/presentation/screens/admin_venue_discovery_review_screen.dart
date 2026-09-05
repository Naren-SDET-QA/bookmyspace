import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venue_discovery/presentation/venue_discovery_providers.dart';

/// Admin review queue for `venue_discovery_staging` rows created by the
/// OSM/Overpass discovery pipeline (owner "Venue Discovery" search, or the
/// `import-venues` edge function directly).
///
/// Review is deliberately two steps, matching the two RPCs it calls:
///  1. Approve / Reject only flags the staging row (`review_discovered_venue`).
///  2. "Create draft venue" materializes an approved row into a real
///     `venues` row via `approve_discovered_venue`, which the database
///     creates with `is_verified = false, is_active = false` — never live,
///     never auto-published. A human still has to publish it separately
///     through the existing listing-moderation screen.
class AdminVenueDiscoveryReviewScreen extends ConsumerStatefulWidget {
  const AdminVenueDiscoveryReviewScreen({super.key});

  @override
  ConsumerState<AdminVenueDiscoveryReviewScreen> createState() =>
      _AdminVenueDiscoveryReviewScreenState();
}

class _AdminVenueDiscoveryReviewScreenState
    extends ConsumerState<AdminVenueDiscoveryReviewScreen> {
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingDiscoveryStagingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Venue discovery review')),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(pendingDiscoveryStagingProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.travel_explore_outlined,
              title: 'Nothing to review',
              message: 'No discovered venues are waiting for review.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(pendingDiscoveryStagingProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _StagingCard(
                row: items[i],
                busy: _busy.contains(items[i]['id'] as String? ?? ''),
                onReview: _review,
                onMaterialize: _materialize,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _review(String stagingId, {required bool approve}) async {
    setState(() => _busy.add(stagingId));
    try {
      await ref
          .read(discoveryRepositoryProvider)
          .reviewStaging(stagingId, approve: approve);
      ref.invalidate(pendingDiscoveryStagingProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy.remove(stagingId));
    }
  }

  Future<void> _materialize(String stagingId) async {
    setState(() => _busy.add(stagingId));
    try {
      await ref.read(discoveryRepositoryProvider).materialize(stagingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft venue created (unverified, unpublished).'),
          ),
        );
      }
      ref.invalidate(pendingDiscoveryStagingProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy.remove(stagingId));
    }
  }
}

class _StagingCard extends StatelessWidget {
  const _StagingCard({
    required this.row,
    required this.busy,
    required this.onReview,
    required this.onMaterialize,
  });

  final Map<String, dynamic> row;
  final bool busy;
  final void Function(String id, {required bool approve}) onReview;
  final void Function(String id) onMaterialize;

  @override
  Widget build(BuildContext context) {
    final id = row['id'] as String? ?? '';
    final status = row['status'] as String? ?? 'PENDING_REVIEW';
    final name = row['name'] as String? ?? 'Unnamed venue';
    final subtitle = [
      row['category'] as String?,
      row['city'] as String?,
      row['state'] as String?,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final source =
        '${row['source'] ?? ''} · ${row['source_place_id'] ?? ''}';
    final hasVenue = row['venue_id'] != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(status),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: status == 'APPROVED'
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : null,
                ),
              ],
            ),
            if (subtitle.isNotEmpty) Text(subtitle),
            Text(
              source,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (status == 'PENDING_REVIEW') ...[
                  FilledButton(
                    onPressed: busy ? null : () => onReview(id, approve: true),
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onReview(id, approve: false),
                    child: const Text('Reject'),
                  ),
                ],
                if (status == 'APPROVED' && !hasVenue)
                  FilledButton.tonal(
                    onPressed: busy ? null : () => onMaterialize(id),
                    child: const Text('Create draft venue'),
                  ),
                if (status == 'APPROVED' && hasVenue)
                  const Text('Draft venue created'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
