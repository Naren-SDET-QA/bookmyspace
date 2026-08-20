import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../customer_analytics_providers.dart';

class CustomerAnalyticsScreen extends ConsumerStatefulWidget {
  const CustomerAnalyticsScreen({super.key});
  @override
  ConsumerState<CustomerAnalyticsScreen> createState() =>
      _CustomerAnalyticsScreenState();
}

class _CustomerAnalyticsScreenState
    extends ConsumerState<CustomerAnalyticsScreen> {
  DateTime? _start;
  DateTime? _end;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      customerAnalyticsProvider((start: _start, end: _end)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('My spending & usage')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load analytics: $e')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: _chooseRange,
              icon: const Icon(Icons.date_range),
              label: Text(_rangeLabel),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metric('Spent', '₹${data.spent.toStringAsFixed(2)}'),
                _metric('Bookings', '${data.bookings}'),
              ],
            ),
            Row(
              children: [
                _metric('Completed', '${data.completed}'),
                _metric('Cancelled', '${data.cancelled}'),
              ],
            ),
            Row(
              children: [
                _metric('Refunded', '${data.refunded}'),
                _metric('Transactions', '${data.recent.length}'),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Spending by month',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (data.monthly.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No spending in this period.'),
              ),
            ...data.monthly.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                trailing: Text('₹${e.value.toStringAsFixed(2)}'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Recent transactions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...data.recent.map(
              (p) => ListTile(
                title: Text(p.status.dbValue),
                subtitle: Text(p.bookingId),
                trailing: Text('₹${p.amount.toStringAsFixed(2)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, String value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ),
  );
  String get _rangeLabel => _start == null
      ? 'All dates'
      : '${_start!.year}-${_start!.month}-${_start!.day} to ${_end!.year}-${_end!.month}-${_end!.day}';
  Future<void> _chooseRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range != null)
      setState(() {
        _start = range.start;
        _end = range.end;
      });
  }
}
