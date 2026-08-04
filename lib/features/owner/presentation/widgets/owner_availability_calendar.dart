import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../infrastructure/owner_operations_repository.dart';

class OwnerAvailabilityCalendar extends StatefulWidget {
  const OwnerAvailabilityCalendar({
    super.key,
    required this.venueId,
    required this.repository,
  });

  final String venueId;
  final OwnerOperationsRepository repository;

  @override
  State<OwnerAvailabilityCalendar> createState() =>
      _OwnerAvailabilityCalendarState();
}

class _OwnerAvailabilityCalendarState extends State<OwnerAvailabilityCalendar> {
  DateTime _date = DateTime.now();
  int _revision = 0;

  void _refresh() => setState(() => _revision++);
  String get _title => DateFormat('EEE, d MMM yyyy').format(_date);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarDatePicker(
          initialDate: _date,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 730)),
          onDateChanged: (value) => setState(() => _date = value),
        ),
        const _Legend(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                _title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Copy / repeat',
              onPressed: _copyOrRepeat,
              icon: const Icon(Icons.content_copy_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Add slot',
              onPressed: () => _editSlot(),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(
            '${widget.venueId}-${_date.toIso8601String()}-$_revision',
          ),
          future: widget.repository.daySlots(widget.venueId, _date),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Message(
                text: snapshot.error.toString(),
                action: TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snapshot.data!;
            final dateBlocked =
                rows.isNotEmpty &&
                rows.every((row) => row['status'] == 'blocked');
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.repository.setDateBlocked(
                        widget.venueId,
                        _date,
                        !dateBlocked,
                      );
                      _refresh();
                    },
                    icon: Icon(
                      dateBlocked
                          ? Icons.event_available_rounded
                          : Icons.event_busy_rounded,
                    ),
                    label: Text(
                      dateBlocked ? 'Unblock this date' : 'Block this date',
                    ),
                  ),
                ),
                if (rows.isEmpty)
                  const _Message(text: 'No slots yet. Tap + to add one.')
                else
                  for (final row in rows)
                    _SlotCard(
                      row: row,
                      onToggle: (active) async {
                        await widget.repository.toggleSlot(
                          row['slot_id'] as String,
                          active,
                        );
                        _refresh();
                      },
                      onBlock: () async {
                        await widget.repository.setSlotBlocked(
                          widget.venueId,
                          row['slot_id'] as String,
                          _date,
                          row['status'] != 'blocked',
                        );
                        _refresh();
                      },
                      onEdit: () => _editSlot(row),
                      onOffline: () => _offline(row),
                      onDelete: () => _deleteSlot(row),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _editSlot([Map<String, dynamic>? row]) async {
    final label = TextEditingController(text: row?['label']?.toString());
    final start = TextEditingController(text: _shortTime(row?['start_time']));
    final end = TextEditingController(text: _shortTime(row?['end_time']));
    final price = TextEditingController(text: row?['price_amount']?.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(row == null ? 'Add slot' : 'Edit slot'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in [
                ('Label', label, TextInputType.text),
                ('Start (HH:mm)', start, TextInputType.datetime),
                ('End (HH:mm)', end, TextInputType.datetime),
                ('Price', price, TextInputType.number),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: field.$2,
                    keyboardType: field.$3,
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
    );
    if (saved == true) {
      if (row == null) {
        await widget.repository.addSlot(
          widget.venueId,
          label.text.trim(),
          start.text.trim(),
          end.text.trim(),
          double.parse(price.text),
        );
      } else {
        await widget.repository.updateSlot(
          slotId: row['slot_id'] as String,
          label: label.text.trim(),
          start: start.text.trim(),
          end: end.text.trim(),
          price: double.parse(price.text),
        );
      }
      _refresh();
    }
    label.dispose();
    start.dispose();
    end.dispose();
    price.dispose();
  }

  Future<void> _deleteSlot(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete slot?'),
        content: Text(row['label']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteSlot(row['slot_id'] as String);
      _refresh();
    }
  }

  Future<void> _offline(Map<String, dynamic> row) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Offline booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Customer name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Book'),
          ),
        ],
      ),
    );
    if (save == true) {
      await widget.repository.offline(
        venueId: widget.venueId,
        slotId: row['slot_id'] as String,
        date: _date,
        name: name.text.trim(),
        phone: phone.text.trim(),
      );
      _refresh();
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _copyOrRepeat() async {
    var target = _date.add(const Duration(days: 1));
    var weeks = 0;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Copy availability'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('First target date'),
                subtitle: Text(DateFormat.yMMMd().format(target)),
                trailing: const Icon(Icons.calendar_month_rounded),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: target,
                  );
                  if (selected != null) {
                    setDialogState(() => target = selected);
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: weeks,
                decoration: const InputDecoration(labelText: 'Repeat weekly'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('No repeat')),
                  DropdownMenuItem(value: 4, child: Text('4 weeks')),
                  DropdownMenuItem(value: 8, child: Text('8 weeks')),
                  DropdownMenuItem(value: 12, child: Text('12 weeks')),
                ],
                onChanged: (value) => setDialogState(() => weeks = value ?? 0),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      final count = weeks == 0 ? 1 : weeks;
      final targets = List.generate(
        count,
        (index) => target.add(Duration(days: index * 7)),
      );
      await widget.repository.copyDay(widget.venueId, _date, targets);
      _refresh();
    }
  }

  static String _shortTime(Object? value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.row,
    required this.onToggle,
    required this.onBlock,
    required this.onEdit,
    required this.onOffline,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final ValueChanged<bool> onToggle;
  final VoidCallback onBlock;
  final VoidCallback onEdit;
  final VoidCallback onOffline;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'available';
    final active = row['is_active'] as bool? ?? true;
    final color = switch (status) {
      'booked' => AppTheme.danger,
      'held' => Colors.orange,
      'blocked' || 'closed' || 'inactive' => Colors.grey,
      _ => AppTheme.success,
    };
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${row['label']}  ${_time(row['start_time'])}–${_time(row['end_time'])}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('₹${row['price_amount']}'),
                Switch(value: active, onChanged: onToggle),
              ],
            ),
            Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (row['booking_id'] != null) ...[
              const SizedBox(height: 5),
              Text(
                '${row['booking_ref']} • ${row['customer_name'] ?? 'Customer'}',
              ),
              if ((row['customer_phone']?.toString() ?? '').isNotEmpty)
                Text(row['customer_phone'].toString()),
            ],
            Wrap(
              spacing: 2,
              children: [
                IconButton(
                  tooltip: 'Edit / price',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: status == 'blocked' ? 'Unblock slot' : 'Block slot',
                  onPressed: status == 'booked' || status == 'held'
                      ? null
                      : onBlock,
                  icon: Icon(
                    status == 'blocked'
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Offline booking',
                  onPressed: status == 'available' ? onOffline : null,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: row['booking_id'] == null ? onDelete : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
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

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 12,
    runSpacing: 6,
    children: [
      _LegendItem('Available', AppTheme.success),
      _LegendItem('Booked', AppTheme.danger),
      _LegendItem('Held', Colors.orange),
      _LegendItem('Blocked', Colors.grey),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: Column(
      children: [
        Text(text, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
