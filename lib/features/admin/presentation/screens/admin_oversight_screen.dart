import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/listing_moderation.dart';
import '../admin_moderation_providers.dart';

enum AdminOversightKind { bookings, payments, refunds }

class AdminOversightScreen extends ConsumerWidget {
  const AdminOversightScreen({super.key, required this.kind});

  final AdminOversightKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = switch (kind) {
      AdminOversightKind.bookings => ref.watch(adminBookingsOversightProvider),
      AdminOversightKind.payments => ref.watch(adminPaymentsOversightProvider),
      AdminOversightKind.refunds => ref.watch(adminRefundsOversightProvider),
    };
    final title = switch (kind) {
      AdminOversightKind.bookings => 'Booking oversight',
      AdminOversightKind.payments => 'Payment oversight',
      AdminOversightKind.refunds => 'Refund oversight',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(adminBookingsOversightProvider);
            ref.invalidate(adminPaymentsOversightProvider);
            ref.invalidate(adminRefundsOversightProvider);
          },
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No records',
              message:
                  'No $title rows are visible under current authorization.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _RowCard(row: rows[i]),
          );
        },
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row});

  final OversightRow row;

  @override
  Widget build(BuildContext context) {
    final amount = row.amount;
    final created = row.createdAt;
    return Card(
      child: ListTile(
        title: Text(row.title),
        subtitle: Text(
          [
            row.status,
            row.subtitle,
            if (created != null) DateFormat.yMMMd().format(created),
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
        trailing: amount == null
            ? null
            : Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
