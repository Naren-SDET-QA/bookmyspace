import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../domain/sports_venue.dart';
import '../sports_providers.dart';

class SportsVenuesScreen extends ConsumerStatefulWidget {
  const SportsVenuesScreen({super.key});
  @override
  ConsumerState<SportsVenuesScreen> createState() => _SportsListState();
}

class _SportsListState extends ConsumerState<SportsVenuesScreen> {
  SportType? type;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(sportsVenuesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sports Grounds & Courts')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final t in SportType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.name.toUpperCase()),
                      selected: type == t,
                      onSelected: (v) => setState(() => type = v ? t : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(sportsVenuesProvider),
              ),
              data: (items) {
                final shown = items
                    .where((v) => type == null || v.type == type)
                    .toList();
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.sports_tennis,
                    title: 'No sports venues',
                    message: 'Try another sport.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  itemCount: shown.length,
                  itemBuilder: (c, i) {
                    final v = shown[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('/sports/${v.id}'),
                        leading: const CircleAvatar(child: Icon(Icons.sports)),
                        title: Text(v.name),
                        subtitle: Text(
                          '${v.type.name.toUpperCase()} • ${v.capacity} people • ${v.city}',
                        ),
                        trailing: Text('₹${v.hourlyRate.toStringAsFixed(0)}/h'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SportsVenueDetailScreen extends ConsumerWidget {
  const SportsVenueDetailScreen({super.key, required this.venueId});
  final String venueId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sportsVenueProvider(venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Sports venue')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(sportsVenueProvider(venueId)),
        ),
        data: (v) => ListView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff00875a), Color(0xff35c58b)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.sports_soccer,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              v.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              '${v.type.name.toUpperCase()} • Capacity ${v.capacity} • ${v.city}',
            ),
            const SizedBox(height: 12),
            Text(v.description),
            const SizedBox(height: 16),
            Text(
              '₹${v.hourlyRate.toStringAsFixed(0)}/hour • ₹${v.sessionRate.toStringAsFixed(0)}/${v.sessionMinutes} min session',
            ),
            Wrap(
              spacing: 6,
              children: [
                ...v.equipment,
                ...v.amenities,
              ].map((x) => Chip(label: Text(x))).toList(),
            ),
            Text('${v.bufferMinutes} minute buffer • ${v.bookingMode} booking'),
          ],
        ),
      ),
      bottomNavigationBar: data.valueOrNull == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => context.push('/sports/$venueId/book'),
                  child: const Text('Check availability & book'),
                ),
              ),
            ),
    );
  }
}

class SportsBookingScreen extends ConsumerStatefulWidget {
  const SportsBookingScreen({super.key, required this.venueId});
  final String venueId;
  @override
  ConsumerState<SportsBookingScreen> createState() => _SportsBookingState();
}

class _SportsBookingState extends ConsumerState<SportsBookingScreen> {
  DateTime date = DateTime.now().add(const Duration(days: 1));
  String start = '18:00';
  int duration = 60, repeats = 1;
  SportsQuote? quote;
  bool busy = false;
  String? error;
  Future<void> check() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      quote = await ref
          .read(sportsRepositoryProvider)
          .quote(widget.venueId, date, start, duration);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (quote?.available != true || busy) return;
    setState(() => busy = true);
    try {
      final rec = [
        for (var i = 1; i < repeats; i++) date.add(Duration(days: i * 7)),
      ];
      final list = await ref
          .read(sportsRepositoryProvider)
          .book(widget.venueId, date, start, duration, rec);
      ref.invalidate(myBookingsProvider);
      if (!mounted || list.isEmpty) return;
      final b = list.first;
      if (b.status == BookingStatus.paymentPending) {
        await context.push('/bookings/${b.id}/pay', extra: b);
      } else {
        await context.push('/bookings/${b.id}/status', extra: b);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book sports venue')),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        ListTile(
          title: const Text('Date'),
          subtitle: Text(DateFormat.yMMMMd().format(date)),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) {
              setState(() {
                date = d;
                quote = null;
              });
            }
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: start,
          decoration: const InputDecoration(labelText: 'Start time'),
          items: [
            for (var h = 6; h <= 22; h++)
              for (final m in ['00', '30'])
                DropdownMenuItem(
                  value: '${h.toString().padLeft(2, '0')}:$m',
                  child: Text('${h.toString().padLeft(2, '0')}:$m'),
                ),
          ],
          onChanged: (v) => setState(() {
            start = v ?? start;
            quote = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: duration,
          decoration: const InputDecoration(labelText: 'Duration / session'),
          items: [60, 90, 120, 180, 240]
              .map((v) => DropdownMenuItem(value: v, child: Text('$v minutes')))
              .toList(),
          onChanged: (v) => setState(() {
            duration = v ?? 60;
            quote = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: repeats,
          decoration: const InputDecoration(labelText: 'Repeat weekly'),
          items: [1, 2, 4, 8, 12]
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(v == 1 ? 'Does not repeat' : '$v sessions'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => repeats = v ?? 1),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: busy ? null : check,
          icon: const Icon(Icons.search),
          label: const Text('Check live availability'),
        ),
        if (quote != null)
          Card(
            child: ListTile(
              leading: Icon(
                quote!.available ? Icons.check_circle : Icons.block,
              ),
              title: Text(
                quote!.available
                    ? 'Available until ${quote!.endTime}'
                    : 'Unavailable',
              ),
              subtitle: Text(
                quote!.available
                    ? '₹${quote!.price.toStringAsFixed(0)} before tax'
                    : quote!.reason,
              ),
            ),
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: quote?.available == true && !busy ? submit : null,
          child: Text(
            busy
                ? 'Please wait…'
                : 'Book${repeats > 1 ? ' $repeats sessions' : ''}',
          ),
        ),
      ),
    ),
  );
}

class SportsOwnerScreen extends ConsumerStatefulWidget {
  const SportsOwnerScreen({super.key});
  @override
  ConsumerState<SportsOwnerScreen> createState() => _SportsOwnerState();
}

class _SportsOwnerState extends ConsumerState<SportsOwnerScreen> {
  final name = TextEditingController(),
      city = TextEditingController(),
      capacity = TextEditingController(text: '20'),
      hourly = TextEditingController(text: '1000'),
      session = TextEditingController(text: '1000');
  SportType type = SportType.badminton;
  bool busy = false;
  @override
  void dispose() {
    for (final c in [name, city, capacity, hourly, session]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> create() async {
    setState(() => busy = true);
    try {
      await ref
          .read(sportsRepositoryProvider)
          .create(
            name: name.text,
            city: city.text,
            capacity: int.tryParse(capacity.text) ?? 1,
            type: type,
            hourlyRate: double.tryParse(hourly.text) ?? 0,
            sessionMinutes: 60,
            sessionRate: double.tryParse(session.text) ?? 0,
            bufferMinutes: 15,
          );
      ref.invalidate(ownerSportsVenuesProvider);
      ref.invalidate(sportsVenuesProvider);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(SportsVenue v, String a) async {
    final repo = ref.read(sportsRepositoryProvider);
    if (a == 'mode') {
      await repo.setMode(
        v.id,
        v.bookingMode == 'approval' ? 'instant' : 'approval',
      );
    } else if (a == 'break') {
      await repo.addBreak(v.id, 0, '13:00', '14:00');
    } else {
      await repo.offline(
        v.id,
        DateTime.now().add(const Duration(days: 1)),
        '18:00',
        60,
      );
    }
    ref.invalidate(ownerSportsVenuesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sports availability updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(ownerSportsVenuesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sports Venues')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        children: [
          Text('Inventory', style: Theme.of(context).textTheme.titleLarge),
          data.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) => Column(
              children: items
                  .map(
                    (v) => Card(
                      child: ListTile(
                        title: Text(v.name),
                        subtitle: Text(
                          '${v.type.name} • ${v.bookingMode} • ${v.bufferMinutes}m buffer',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (a) => action(v, a),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'mode',
                              child: Text('Toggle Instant / Approval'),
                            ),
                            PopupMenuItem(
                              value: 'break',
                              child: Text('Add maintenance break'),
                            ),
                            PopupMenuItem(
                              value: 'offline',
                              child: Text('Add offline booking'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 32),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Ground / court name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField(
            initialValue: type,
            items: SportType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => type = v ?? type),
            decoration: const InputDecoration(labelText: 'Sport type'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacity'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: hourly,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Hourly price'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: session,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '60-minute session price',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : create,
            icon: const Icon(Icons.add),
            label: const Text('Create sports venue'),
          ),
        ],
      ),
    );
  }
}
