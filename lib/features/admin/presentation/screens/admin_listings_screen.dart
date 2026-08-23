import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../admin_moderation_providers.dart';

class AdminListingsScreen extends ConsumerStatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  ConsumerState<AdminListingsScreen> createState() =>
      _AdminListingsScreenState();
}

class _AdminListingsScreenState extends ConsumerState<AdminListingsScreen> {
  String? _status = 'pending_approval';

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(adminListingsProvider(_status));
    return Scaffold(
      appBar: AppBar(title: const Text('Listing moderation')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                for (final value in [
                  'pending_approval',
                  'draft',
                  'approved',
                  'rejected',
                  'published',
                  null,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value ?? 'all'),
                      selected: _status == value,
                      onSelected: (_) => setState(() => _status = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: listings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(adminListingsProvider(_status)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No listings',
                    message: 'Nothing matches this moderation filter.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(adminListingsProvider(_status)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
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
                                      item.venue.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(item.status),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              Text(
                                [
                                  item.venue.category?.name ?? '',
                                  item.venue.city,
                                  item.venue.state,
                                ].where((s) => s.isNotEmpty).join(' · '),
                              ),
                              if (item.rejectionReason.isNotEmpty)
                                Text(
                                  item.rejectionReason,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: () =>
                                        _act(item.venue.id, 'approve'),
                                    child: const Text('Approve'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        _act(item.venue.id, 'publish'),
                                    child: const Text('Publish'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () =>
                                        _act(item.venue.id, 'unpublish'),
                                    child: const Text('Unpublish'),
                                  ),
                                  TextButton(
                                    onPressed: () => _reject(item.venue.id),
                                    child: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _act(String venueId, String action, {String? reason}) async {
    try {
      await ref
          .read(listingModerationRepositoryProvider)
          .moderate(venueId: venueId, action: action, reason: reason);
      ref.invalidate(adminListingsProvider(_status));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reject(String venueId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject listing'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (required)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _act(venueId, 'reject', reason: reason);
  }
}
