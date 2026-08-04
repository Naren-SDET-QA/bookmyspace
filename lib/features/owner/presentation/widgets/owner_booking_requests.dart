import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../infrastructure/owner_operations_repository.dart';

class OwnerBookingRequests extends StatefulWidget {
  const OwnerBookingRequests({super.key, required this.repository});
  final OwnerOperationsRepository repository;

  @override
  State<OwnerBookingRequests> createState() => _OwnerBookingRequestsState();
}

class _OwnerBookingRequestsState extends State<OwnerBookingRequests> {
  late Future<List<Map<String, dynamic>>> _future;
  Timer? _timer;
  final Set<String> _acting = {};

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() => _future = widget.repository.bookings();

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .68,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Centered(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_message(snapshot.error!)),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                return TabBarView(
                  children: [
                    _list(
                      rows.where(
                        (r) => const {
                          'requested',
                          'expired',
                        }.contains(r['workflow_status']),
                      ),
                    ),
                    _list(
                      rows.where(
                        (r) => const {
                          'approved',
                          'payment_pending',
                          'paid',
                          'confirmed',
                        }.contains(r['workflow_status']),
                      ),
                    ),
                    _list(
                      rows.where((r) => r['workflow_status'] == 'rejected'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(Iterable<Map<String, dynamic>> values) {
    final rows = values.toList();
    if (rows.isEmpty) return const _Centered(child: Text('No requests here.'));
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: rows.length,
        itemBuilder: (context, index) => _RequestCard(
          row: rows[index],
          busy: _acting.contains(rows[index]['id']),
          onAccept: () => _decide(rows[index], true),
          onReject: () => _decide(rows[index], false),
        ),
      ),
    );
  }

  Future<void> _decide(Map<String, dynamic> row, bool accept) async {
    final id = row['id'] as String;
    if (_acting.contains(id) || row['workflow_status'] != 'requested') return;
    final deadline = DateTime.tryParse(
      row['approval_deadline']?.toString() ?? '',
    );
    if (deadline != null && !deadline.toLocal().isAfter(DateTime.now())) {
      await _refresh();
      if (mounted) _snack('This approval request has expired.');
      return;
    }
    String? reason;
    if (!accept) {
      reason = await _rejectionReason();
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Accept booking?'),
          content: const Text('The customer will be notified immediately.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _acting.add(id));
    try {
      await widget.repository.decide(id, accept, reason: reason);
      await _refresh();
      if (mounted) _snack(accept ? 'Booking accepted' : 'Booking rejected');
    } catch (error) {
      await _refresh();
      if (mounted) _snack(_message(error));
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  Future<String?> _rejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject booking?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason for customer'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) Navigator.pop(dialogContext, reason);
            },
            child: const Text('Confirm reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _message(Object error) => error is AppException
      ? error.message
      : 'Could not update this request. Refresh and try again.';
  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.row,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });
  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = row['workflow_status']?.toString() ?? '';
    final deadline = DateTime.tryParse(
      row['approval_deadline']?.toString() ?? '',
    )?.toLocal();
    final expired =
        status == 'expired' ||
        (deadline != null && !deadline.isAfter(DateTime.now()));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row['hall_name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                _Status(expired ? 'expired' : status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              row['customer_name']?.toString() ?? 'Customer',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if ((row['customer_phone']?.toString() ?? '').isNotEmpty)
              Text(row['customer_phone'].toString()),
            const SizedBox(height: 8),
            Text(
              '${DateFormat.yMMMd().format(DateTime.parse(row['book_date'].toString()))} • ${_time(row['start_time'])}–${_time(row['end_time'])}',
            ),
            Text(
              formatInr((row['total_amount'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(
                color: AppTheme.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (status == 'requested' && !expired && deadline != null) ...[
              const SizedBox(height: 8),
              Text(
                'Expires in ${approvalCountdown(deadline, DateTime.now())}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if ((row['rejection_reason']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Reason: ${row['rejection_reason']}'),
            ],
            if (status == 'requested') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy || expired ? null : onReject,
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy || expired ? null : onAccept,
                      child: Text(busy ? 'Updating…' : 'Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _time(Object? value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }
}

String approvalCountdown(DateTime deadline, DateTime now) {
  final remaining = deadline.difference(now);
  if (remaining <= Duration.zero) return 'Expired';
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  final seconds = remaining.inSeconds.remainder(60);
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${seconds}s';
}

class _Status extends StatelessWidget {
  const _Status(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'requested' => Colors.orange,
      'rejected' || 'expired' => AppTheme.danger,
      _ => AppTheme.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(child: child);
}
