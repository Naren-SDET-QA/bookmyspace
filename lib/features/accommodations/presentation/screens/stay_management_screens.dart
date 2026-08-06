import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';

final _myStaysProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async =>
      (await Supabase.instance.client
              .from('stay_bookings')
              .select('*, accommodation_properties(name)')
              .order('created_at', ascending: false))
          .cast<Map<String, dynamic>>(),
);
final _ownerStayPropertiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, module) async {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;
      final orgs = await client
          .from('organizations')
          .select('id')
          .eq('owner_user_id', uid);
      final ids = orgs.map((row) => row['id'] as String).toList();
      if (ids.isEmpty) return const [];
      return (await client
              .from('accommodation_properties')
              .select('*, accommodation_units(*)')
              .eq('module', module)
              .inFilter('org_id', ids))
          .cast<Map<String, dynamic>>();
    });

final _ownerStayBookingsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async => (await Supabase.instance.client
          .from('stay_bookings')
          .select(
            '*, accommodation_properties!stay_bookings_property_id_fkey(name)',
          )
          .order('created_at', ascending: false))
      .cast<Map<String, dynamic>>(),
);

class MyStayBookingsScreen extends ConsumerWidget {
  const MyStayBookingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('My stays')),
    body: ref
        .watch(_myStaysProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No stay bookings yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i],
                        property = Map<String, dynamic>.from(
                          item['accommodation_properties'] as Map? ?? const {},
                        );
                    return Card(
                      child: ListTile(
                        title: Text(property['name']?.toString() ?? 'Stay'),
                        subtitle: Text(
                          '${item['check_in']} - ${item['check_out']}\n${item['status']} - ${item['payment_status']}',
                        ),
                        trailing: Text('${item['currency']} ${item['total']}'),
                      ),
                    );
                  },
                ),
        ),
  );
}

class StayOwnerScreen extends ConsumerWidget {
  const StayOwnerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Rooms & Stays'),
        actions: [
          IconButton(
            onPressed: () => _addProperty(context, ref),
            icon: const Icon(Icons.add_business),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Properties'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _PropertiesTab(),
          _RequestsTab(),
        ],
      ),
    ),
  );
}

class _PropertiesTab extends ConsumerWidget {
  const _PropertiesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_ownerStayPropertiesProvider('stay'))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Add your first hotel or stay'))
            : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final property = items[i],
                      units =
                          (property['accommodation_units'] as List? ??
                          const []);
                  return Card(
                    child: ExpansionTile(
                      title: Text(property['name'].toString()),
                      subtitle: Text(
                        '${property['property_type']} - ${property['booking_mode']}',
                      ),
                      children: [
                        for (final raw in units)
                          ListTile(
                            title: Text((raw as Map)['name'].toString()),
                            subtitle: Text(
                              'Inventory ${raw['inventory']} - INR ${raw['price_nightly']}/night',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Set date rates',
                                  icon: const Icon(Icons.calendar_month),
                                  onPressed: () => _rate(
                                    context,
                                    ref,
                                    Map<String, dynamic>.from(raw),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Block dates',
                                  icon: const Icon(Icons.event_busy_rounded),
                                  onPressed: () => _blockDates(
                                    context,
                                    ref,
                                    Map<String, dynamic>.from(raw),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        OverflowBar(
                          children: [
                            TextButton.icon(
                              onPressed: () => _addRoom(
                                context,
                                ref,
                                property['id'] as String,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Room type'),
                            ),
                            TextButton.icon(
                              onPressed: () => _offline(context, property),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Walk-in'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_ownerStayBookingsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No stay bookings yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final booking = items[i],
                      property = Map<String, dynamic>.from(
                        booking['accommodation_properties'] as Map? ??
                            const {},
                      );
                  final status = booking['status'] as String? ?? '';
                  return Card(
                    child: ListTile(
                      title: Text(property['name']?.toString() ?? 'Stay'),
                      subtitle: Text(
                        '${booking['booking_ref']}\n${booking['check_in']} → ${booking['check_out']} • ${booking['adults']} adults • ${booking['total']} ${booking['currency']}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text(status.toUpperCase()),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (status == 'requested') ...[
                            TextButton(
                              onPressed: () => _setBookingStatus(
                                context,
                                ref,
                                booking['id'] as String,
                                'confirmed',
                              ),
                              child: const Text('Approve'),
                            ),
                            TextButton(
                              onPressed: () => _setBookingStatus(
                                context,
                                ref,
                                booking['id'] as String,
                                'rejected',
                              ),
                              child: const Text('Reject'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
}

Future<void> _setBookingStatus(
  BuildContext context,
  WidgetRef ref,
  String bookingId,
  String status,
) async {
  try {
    await Supabase.instance.client.rpc<void>(
      'update_stay_booking_status',
      params: {'p_booking_id': bookingId, 'p_status': status},
    );
    ref.invalidate(_ownerStayBookingsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking ${status.toUpperCase()}')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

Future<void> _blockDates(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> unit,
) async {
  final dates = await showDateRangePicker(
    context: context,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );
  if (dates == null || !context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Block ${unit['name']}'),
      content: Text(
        'Block all rooms of this type for ${DateFormat.yMMMd().format(dates.start)} – ${DateFormat.yMMMd().format(dates.end)}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final rooms = await Supabase.instance.client
        .from('stay_physical_rooms')
        .select('id')
        .eq('unit_id', unit['id'] as Object);
    final f = DateFormat('yyyy-MM-dd');
    await Supabase.instance.client.from('stay_blocks').insert([
      for (final room in rooms)
        {
          'physical_room_id': room['id'],
          'stay_dates': '[${f.format(dates.start)},${f.format(dates.end)})',
          'reason': 'owner block',
        },
    ]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dates blocked.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

Future<void> _addProperty(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(),
        city = TextEditingController(),
        address = TextEditingController();
    var type = 'hotel';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add property'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              DropdownButtonFormField(
                initialValue: type,
                items:
                    [
                          'hotel',
                          'resort',
                          'guest_house',
                          'hostel',
                          'service_apartment',
                        ]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                onChanged: (v) => set(() => type = v ?? type),
              ),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final client = Supabase.instance.client, uid = client.auth.currentUser!.id;
    final org = await client
        .from('organizations')
        .select('id')
        .eq('owner_user_id', uid)
        .limit(1)
        .single();
    await client.from('accommodation_properties').insert({
      'org_id': org['id'],
      'module': 'stay',
      'property_type': type,
      'name': name.text.trim(),
      'city': city.text.trim(),
      'address': address.text.trim(),
    });
    ref.invalidate(_ownerStayPropertiesProvider('stay'));
  }

  Future<void> _addRoom(
    BuildContext context,
    WidgetRef ref,
    String propertyId,
  ) async {
    final name = TextEditingController(),
        price = TextEditingController(),
        inventory = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add room type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nightly rate'),
            ),
            TextField(
              controller: inventory,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Physical rooms'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final count = int.tryParse(inventory.text) ?? 1,
        client = Supabase.instance.client;
    final unit = await client
        .from('accommodation_units')
        .insert({
          'property_id': propertyId,
          'name': name.text.trim(),
          'occupancy_type': 'room',
          'capacity': 2,
          'inventory': count,
          'price_nightly': double.tryParse(price.text) ?? 0,
        })
        .select('id')
        .single();
    await client.from('stay_physical_rooms').insert([
      for (var i = 1; i <= count; i++)
        {'unit_id': unit['id'], 'room_code': 'ROOM-$i'},
    ]);
    ref.invalidate(_ownerStayPropertiesProvider('stay'));
  }

  Future<void> _rate(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> unit,
  ) async {
    final rate = TextEditingController(text: '${unit['price_nightly']}');
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (dates == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Set date rate'),
        content: TextField(
          controller: rate,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nightly rate'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final f = DateFormat('yyyy-MM-dd');
      await Supabase.instance.client.from('stay_rates').insert({
        'unit_id': unit['id'],
        'start_date': f.format(dates.start),
        'end_date': f.format(dates.end),
        'nightly_rate': double.tryParse(rate.text) ?? 0,
      });
    }
  }

  Future<void> _offline(
    BuildContext context,
    Map<String, dynamic> property,
  ) async {
    final customer = TextEditingController(),
        unit = TextEditingController(),
        qty = TextEditingController(text: '1');
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (dates == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Walk-in booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customer,
              decoration: const InputDecoration(labelText: 'Customer user ID'),
            ),
            TextField(
              controller: unit,
              decoration: const InputDecoration(labelText: 'Room type ID'),
            ),
            TextField(
              controller: qty,
              decoration: const InputDecoration(labelText: 'Rooms'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Block & confirm'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final f = DateFormat('yyyy-MM-dd');
      await Supabase.instance.client.rpc<void>(
        'create_stay_booking',
        params: {
          'p_property_id': property['id'],
          'p_check_in': f.format(dates.start),
          'p_check_out': f.format(dates.end),
          'p_adults': 1,
          'p_children': 0,
          'p_rooms': [
            {
              'unit_id': unit.text.trim(),
              'quantity': int.tryParse(qty.text) ?? 1,
            },
          ],
          'p_idempotency_key': const Uuid().v4(),
          'p_offline_customer': customer.text.trim(),
        },
      );
    }
  }
