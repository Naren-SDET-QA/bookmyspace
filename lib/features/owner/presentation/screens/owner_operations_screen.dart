import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../owner_venues/presentation/providers/owner_venue_providers.dart';
import '../../infrastructure/owner_operations_repository.dart';
import '../owner_providers.dart';
import '../widgets/owner_availability_calendar.dart';
import '../widgets/owner_booking_requests.dart';

enum OwnerOperation { availability, bookings, offlineBooking, payments }

class OwnerOperationsScreen extends ConsumerStatefulWidget {
  const OwnerOperationsScreen({super.key, required this.operation});
  final OwnerOperation operation;
  @override
  ConsumerState<OwnerOperationsScreen> createState() =>
      _OwnerOperationsScreenState();
}

class _OwnerOperationsScreenState extends ConsumerState<OwnerOperationsScreen> {
  bool get _legacyAvailabilityUi => false;
  bool get _legacyBookingsUi => false;
  final _offlineFormKey = GlobalKey<FormState>();
  String? _venueId;
  String? _slotId;
  final DateTime _date = DateTime.now().add(const Duration(days: 1));
  final _a = TextEditingController(),
      _b = TextEditingController(),
      _c = TextEditingController(),
      _d = TextEditingController();
  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    _d.dispose();
    super.dispose();
  }

  OwnerOperationsRepository get repo =>
      ref.read(ownerOperationsRepositoryProvider);
  String get title => switch (widget.operation) {
    OwnerOperation.availability => 'Availability',
    OwnerOperation.bookings => 'Booking Requests',
    OwnerOperation.offlineBooking => 'Offline Booking',
    OwnerOperation.payments => 'Payments & Receipts',
  };
  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(myVenuesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Add a hall first.'));
          }
          _venueId ??= items.first.id;
          return ListView(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _venueId,
                items: items
                    .map(
                      (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _venueId = v),
                decoration: const InputDecoration(labelText: 'Hall'),
              ),
              const SizedBox(height: 16),
              if (widget.operation == OwnerOperation.bookings &&
                  _legacyBookingsUi)
                FutureBuilder(
                  future: repo.bookings(),
                  builder: (c, s) => _records(
                    s,
                    (row) => Card(
                      child: ListTile(
                        title: Text(row['booking_ref']?.toString() ?? ''),
                        subtitle: Text(
                          '${row['book_date']} • ${row['status']}',
                        ),
                        trailing: row['workflow_status'] == 'requested'
                            ? Wrap(
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      await repo.decide(
                                        row['id'] as String,
                                        false,
                                      );
                                      setState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppTheme.danger,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      await repo.decide(
                                        row['id'] as String,
                                        true,
                                      );
                                      setState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.check,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              if (widget.operation == OwnerOperation.bookings)
                OwnerBookingRequests(repository: repo),
              if (widget.operation == OwnerOperation.payments)
                FutureBuilder(
                  future: repo.payments(),
                  builder: (c, s) => _records(
                    s,
                    (row) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_rounded),
                        title: Text('₹${row['amount']}'),
                        subtitle: Text(
                          '${row['status']} • ${row['method'] ?? 'Online'}',
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.operation == OwnerOperation.availability) ...[
                OutlinedButton.icon(
                  onPressed: () => _editBookingPolicy(),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Booking policy'),
                ),
                const SizedBox(height: 10),
                if (_legacyAvailabilityUi) ...[
                  FutureBuilder(
                    future: repo.slots(_venueId!),
                    builder: (c, s) => _records(
                      s,
                      (r) => Card(
                        child: ListTile(
                          title: Text(r['label']?.toString() ?? ''),
                          subtitle: Text(
                            '${r['start_time']} – ${r['end_time']}',
                          ),
                          trailing: Text('₹${r['price_amount']}'),
                        ),
                      ),
                    ),
                  ),
                  for (final x in [
                    ('Slot label', _a),
                    ('Start HH:mm', _b),
                    ('End HH:mm', _c),
                    ('Price', _d),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: x.$2,
                        decoration: InputDecoration(labelText: x.$1),
                      ),
                    ),
                  FilledButton(
                    onPressed: () async {
                      await repo.addSlot(
                        _venueId!,
                        _a.text,
                        _b.text,
                        _c.text,
                        double.parse(_d.text),
                      );
                      setState(() {});
                    },
                    child: const Text('Add availability slot'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final day = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: _date,
                      );
                      if (day != null) {
                        await repo.blockDate(_venueId!, day, 'Owner blocked');
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Date blocked')),
                        );
                      }
                    },
                    child: const Text('Block a date'),
                  ),
                ],
                OwnerAvailabilityCalendar(venueId: _venueId!, repository: repo),
              ],
              if (widget.operation == OwnerOperation.offlineBooking) ...[
                FutureBuilder(
                  future: repo.slots(_venueId!),
                  builder: (c, s) {
                    final rows = s.data ?? [];
                    if (rows.isNotEmpty) {
                      _slotId ??= rows.first['id'] as String?;
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _slotId,
                      items: rows
                          .map(
                            (r) => DropdownMenuItem(
                              value: r['id'] as String,
                              child: Text(r['label']?.toString() ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _slotId = v),
                      decoration: const InputDecoration(labelText: 'Slot'),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Form(
                  key: _offlineFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _a,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                        ),
                        validator: AppValidators.name,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _b,
                        decoration: const InputDecoration(
                          labelText: 'Customer phone',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: AppValidators.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    if (!(_offlineFormKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    if (_slotId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Select a slot')),
                      );
                      return;
                    }
                    await repo.offline(
                      venueId: _venueId!,
                      slotId: _slotId!,
                      date: _date,
                      name: _a.text,
                      phone: _b.text,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Offline booking confirmed'),
                      ),
                    );
                  },
                  child: const Text('Create offline booking'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBookingPolicy() async {
    final venueId = _venueId;
    if (venueId == null) return;
    final current = await repo.hallSettings(venueId);
    if (!mounted) return;
    var mode = current['booking_mode']?.toString() ?? 'instant';
    final notice = TextEditingController(
      text: current['min_notice_minutes']?.toString() ?? '0',
    );
    final advance = TextEditingController(
      text: current['max_advance_days']?.toString() ?? '365',
    );
    final instantWindow = TextEditingController(
      text: current['instant_book_window_hours']?.toString() ?? '48',
    );
    final approvalTimeout = TextEditingController(
      text: current['approval_timeout_minutes']?.toString() ?? '1440',
    );
    final checkoutHold = TextEditingController(
      text: current['checkout_hold_minutes']?.toString() ?? '10',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Booking policy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  items: const [
                    DropdownMenuItem(value: 'instant', child: Text('Instant')),
                    DropdownMenuItem(
                      value: 'approval',
                      child: Text('Approval'),
                    ),
                    DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => mode = value ?? mode),
                  decoration: const InputDecoration(labelText: 'Booking mode'),
                ),
                for (final field in [
                  ('Minimum notice (minutes)', notice),
                  ('Maximum advance (days)', advance),
                  ('Instant window (hours)', instantWindow),
                  ('Approval timeout (minutes)', approvalTimeout),
                  ('Checkout hold (minutes)', checkoutHold),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: field.$2,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: field.$1),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      await repo.saveHallSettings({
        'venue_id': venueId,
        'booking_mode': mode,
        'min_notice_minutes': int.tryParse(notice.text) ?? 0,
        'max_advance_days': int.tryParse(advance.text) ?? 365,
        'instant_book_window_hours': int.tryParse(instantWindow.text) ?? 48,
        'approval_timeout_minutes': int.tryParse(approvalTimeout.text) ?? 1440,
        'checkout_hold_minutes': int.tryParse(checkoutHold.text) ?? 10,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Booking policy saved')));
      }
    }
    notice.dispose();
    advance.dispose();
    instantWindow.dispose();
    approvalTimeout.dispose();
    checkoutHold.dispose();
  }

  Widget _records(
    AsyncSnapshot<List<Map<String, dynamic>>> s,
    Widget Function(Map<String, dynamic>) tile,
  ) {
    if (s.hasError) return Text(s.error.toString());
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    if (s.data!.isEmpty) return const Text('No records found.');
    return Column(children: s.data!.map(tile).toList());
  }
}
