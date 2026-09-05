import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/owner_venue_providers.dart';
import '../../domain/owner_availability.dart';

class OwnerAvailabilityScreen extends ConsumerStatefulWidget {
  const OwnerAvailabilityScreen({super.key, required this.venueId});
  final String venueId;
  @override
  ConsumerState<OwnerAvailabilityScreen> createState() =>
      _OwnerAvailabilityScreenState();
}

class _OwnerAvailabilityScreenState
    extends ConsumerState<OwnerAvailabilityScreen> {
  late Future<(List<OwnerOperatingHours>, List<OwnerTimeSlot>)> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ref.read(ownerAvailabilityRepositoryProvider);
    _future =
        Future.wait([
          repo.hours(widget.venueId),
          repo.slots(widget.venueId),
        ]).then(
          (v) =>
              (v[0] as List<OwnerOperatingHours>, v[1] as List<OwnerTimeSlot>),
        );
  }

  Future<void> _editSlot([OwnerTimeSlot? existing]) async {
    final label = TextEditingController(text: existing?.label ?? '');
    final start = TextEditingController(
      text: existing?.startTime.substring(0, 5) ?? '09:00',
    );
    final end = TextEditingController(
      text: existing?.endTime.substring(0, 5) ?? '10:00',
    );
    final price = TextEditingController(
      text: existing?.priceAmount.toStringAsFixed(0) ?? '0',
    );
    final value = await showDialog<OwnerTimeSlot>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add time slot' : 'Edit time slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Slot name'),
            ),
            TextField(
              controller: start,
              decoration: const InputDecoration(labelText: 'Start (HH:MM)'),
            ),
            TextField(
              controller: end,
              decoration: const InputDecoration(labelText: 'End (HH:MM)'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(price.text.trim());
              if (amount == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid price.')),
                );
                return;
              }
              try {
                OwnerTimeSlot.validate(
                  label: label.text,
                  startTime: start.text,
                  endTime: end.text,
                  priceAmount: amount,
                );
                Navigator.pop(
                  context,
                  OwnerTimeSlot(
                    id: existing?.id,
                    label: label.text.trim(),
                    startTime: '${start.text.trim()}:00',
                    endTime: '${end.text.trim()}:00',
                    priceAmount: amount,
                    isActive: existing?.isActive ?? true,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    label.dispose();
    start.dispose();
    end.dispose();
    price.dispose();
    if (value == null || !mounted) return;
    await ref
        .read(ownerAvailabilityRepositoryProvider)
        .saveSlot(widget.venueId, value);
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Availability')),
    body: FutureBuilder<(List<OwnerOperatingHours>, List<OwnerTimeSlot>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Could not load availability: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final hours = {for (final h in snap.data!.$1) h.dayOfWeek: h};
        final slots = snap.data!.$2;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'OPERATING HOURS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (var d = 0; d < 7; d++)
              ListTile(
                title: Text(
                  [
                    'Sunday',
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                  ][d],
                ),
                subtitle: Text(
                  hours[d]?.isClosed == true
                      ? 'Closed'
                      : '${hours[d]?.opensAt ?? '09:00'} – ${hours[d]?.closesAt ?? '18:00'}',
                ),
                trailing: Switch(
                  value: !(hours[d]?.isClosed ?? false),
                  onChanged: (open) async {
                    final current =
                        hours[d] ??
                        OwnerOperatingHours(
                          dayOfWeek: d,
                          opensAt: '09:00:00',
                          closesAt: '18:00:00',
                        );
                    await ref
                        .read(ownerAvailabilityRepositoryProvider)
                        .saveHours(widget.venueId, [
                          ...hours.values.where((h) => h.dayOfWeek != d),
                          OwnerOperatingHours(
                            dayOfWeek: d,
                            opensAt: current.opensAt,
                            closesAt: current.closesAt,
                            isClosed: !open,
                          ),
                        ]);
                    if (mounted) setState(_load);
                  },
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'TIME SLOTS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _editSlot(),
                icon: const Icon(Icons.add),
                label: const Text('Add time slot'),
              ),
            ),
            if (slots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No time slots yet. Add your first time slot.'),
              ),
            for (final slot in slots)
              SwitchListTile(
                title: Text(slot.label),
                subtitle: Text(
                  '${slot.startTime} – ${slot.endTime} · ₹${slot.priceAmount.toStringAsFixed(0)}',
                ),
                value: slot.isActive,
                secondary: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit slot',
                  onPressed: () => _editSlot(slot),
                ),
                onChanged: (active) async {
                  await ref
                      .read(ownerAvailabilityRepositoryProvider)
                      .setSlotActive(widget.venueId, slot.id!, active);
                  if (mounted) setState(_load);
                },
              ),
          ],
        );
      },
    ),
  );
}
