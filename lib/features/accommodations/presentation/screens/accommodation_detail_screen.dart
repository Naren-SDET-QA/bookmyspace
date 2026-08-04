import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../invoices/presentation/invoice_providers.dart';
import '../../../payments/presentation/payment_providers.dart';
import '../../../registration/presentation/screens/registration_screens.dart';
import '../../domain/accommodation.dart';
import '../accommodation_providers.dart';

class AccommodationDetailScreen extends ConsumerWidget {
  const AccommodationDetailScreen({
    super.key,
    required this.propertyId,
    required this.module,
  });

  final String propertyId;
  final AccommodationModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(accommodationDetailProvider(propertyId));
    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(accommodationDetailProvider(propertyId)),
        ),
        data: (property) => _DetailBody(property: property),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.property});
  final AccommodationProperty property;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  AccommodationUnit? _unit;
  DateTime? _moveIn;
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;
  int _children = 0;
  int _roomQuantity = 1;
  bool _submitting = false;

  bool get _isPg => widget.property.module == AccommodationModule.pg;

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );

  Future<void> _reserve() async {
    if (_unit == null ||
        (_isPg ? _moveIn == null : _checkIn == null || _checkOut == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a room and valid dates.')),
      );
      return;
    }
    if (!_isPg) {
      final available = await ref
          .read(accommodationRepositoryProvider)
          .availability(
            propertyId: widget.property.id,
            checkIn: _checkIn!,
            checkOut: _checkOut!,
            adults: _guests,
            children: _children,
          );
      final match = available
          .where((item) => item.unitId == _unit!.id)
          .firstOrNull;
      if (!mounted) return;
      if (match == null || match.available < _roomQuantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected rooms are no longer available.'),
            ),
          );
        }
        return;
      }
      final nights = _checkOut!.difference(_checkIn!).inDays;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Review stay'),
          content: Text(
            '${widget.property.name}\n${_unit!.name} × $_roomQuantity\n$nights nights • $_guests adults • $_children children\nSubtotal ₹${(match.nightlyRate * nights * _roomQuantity).toStringAsFixed(0)}\n${widget.property.bookingMode == 'approval' ? 'Owner approval required' : 'Instant booking'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      if (widget.property.registrationFormId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RegistrationFillScreen(
              formId: widget.property.registrationFormId!,
            ),
          ),
        );
        if (!mounted) return;
      }
    }
    setState(() => _submitting = true);
    try {
      final reservationId = await ref
          .read(accommodationRepositoryProvider)
          .reserve(
            AccommodationReservationRequest(
              propertyId: widget.property.id,
              unitId: _unit!.id,
              moveIn: _moveIn,
              checkIn: _checkIn,
              checkOut: _checkOut,
              guests: _guests,
              children: _children,
              rooms: _isPg
                  ? const []
                  : [StayRoomSelection(_unit!.id, _roomQuantity)],
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation created successfully.')),
      );
      if (!_isPg) {
        final row = await Supabase.instance.client
            .from('stay_bookings')
            .select('total,currency,status')
            .eq('id', reservationId)
            .single();
        final referenceId = await ref
            .read(paymentRepositoryProvider)
            .referenceForReservation('stays', reservationId);
        if (!mounted) return;
        if (row['status'] == 'payment_pending') {
          context.go(
            '${AppRoutes.commercePayment.replaceFirst(':id', referenceId)}?amount=${row['total']}&currency=${row['currency']}',
          );
        } else if (row['status'] == 'confirmed') {
          final invoiceId = await ref
              .read(invoiceRepositoryProvider)
              .issueCommerce(referenceId: referenceId);
          if (mounted) {
            context.go(AppRoutes.invoiceView.replaceFirst(':id', invoiceId));
          }
        } else {
          context.go(AppRoutes.myStays);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _scheduleVisit() async {
    final day = await _pickDate(DateTime.now().add(const Duration(days: 1)));
    if (day == null || !mounted) return;
    final visit = DateTime(day.year, day.month, day.day, 11);
    try {
      await ref
          .read(accommodationRepositoryProvider)
          .scheduleVisit(propertyId: widget.property.id, visitAt: visit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Visit scheduled for ${DateFormat.yMMMd().format(day)} at 11:00 AM.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          title: Text(property.name),
          flexibleSpace: FlexibleSpaceBar(
            background: property.coverImage.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: property.coverImage,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _propertyHeroFallback(_isPg),
                  )
                : _propertyHeroFallback(_isPg),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          sliver: SliverList.list(
            children: [
              Text(
                property.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Text('${property.address}, ${property.city}'),
              if (_isPg) ...[
                const SizedBox(height: 10),
                Chip(
                  label: Text(
                    '${property.genderPolicy?.toUpperCase()} • ${property.foodIncluded ? 'Food included' : 'Food optional'}',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Amenities',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: property.amenities
                    .map((item) => Chip(label: Text(item)))
                    .toList(),
              ),
              const SizedBox(height: 22),
              Text(
                'Choose ${_isPg ? 'room / bed' : 'room type'}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (final unit in property.units)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      enabled: unit.inventory > 0,
                      onTap: unit.inventory > 0
                          ? () => setState(() => _unit = unit)
                          : null,
                      leading: _unitPhoto(unit) ??
                          Icon(
                            _unit?.id == unit.id
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: _unit?.id == unit.id
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                      title: Text(
                        unit.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${unit.occupancyType.toUpperCase()} • ${unit.inventory} available${_isPg ? ' • Deposit ₹${unit.deposit.toStringAsFixed(0)}' : ''}',
                      ),
                      trailing: Text(
                        '₹${unit.price.toStringAsFixed(0)}\n${_isPg ? '/month' : '/night'}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (_isPg)
                OutlinedButton.icon(
                  onPressed: _scheduleVisit,
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Schedule Visit'),
                ),
              const SizedBox(height: 10),
              if (_isPg)
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final date = await _pickDate(
                      _moveIn ?? DateTime.now().add(const Duration(days: 1)),
                    );
                    if (date != null) {
                      setState(() => _moveIn = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    _moveIn == null
                        ? 'Select move-in date'
                        : 'Move-in ${DateFormat.yMMMd().format(_moveIn!)}',
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () async {
                          final date = await _pickDate(
                            _checkIn ?? DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _checkIn = date;
                              if (_checkOut == null ||
                                  !_checkOut!.isAfter(date)) {
                                _checkOut = date.add(const Duration(days: 1));
                              }
                            });
                          }
                        },
                        child: Text(
                          _checkIn == null
                              ? 'Check-in'
                              : DateFormat.MMMd().format(_checkIn!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () async {
                          final date = await _pickDate(
                            _checkOut ??
                                DateTime.now().add(const Duration(days: 1)),
                          );
                          if (date != null) setState(() => _checkOut = date);
                        },
                        child: Text(
                          _checkOut == null
                              ? 'Check-out'
                              : DateFormat.MMMd().format(_checkOut!),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      'Children',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _children > 0
                          ? () => setState(() => _children--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_children'),
                    IconButton(
                      onPressed: () => setState(() => _children++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      'Rooms',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _roomQuantity > 1
                          ? () => setState(() => _roomQuantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_roomQuantity'),
                    IconButton(
                      onPressed: () => setState(() => _roomQuantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Guests',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _guests > 1
                          ? () => setState(() => _guests--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_guests'),
                    IconButton(
                      onPressed: () => setState(() => _guests++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _reserve,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded),
                label: Text(_submitting ? 'Reserving…' : 'Reserve'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _propertyHeroFallback(bool isPg) => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
    child: Icon(
      isPg ? Icons.apartment_rounded : Icons.hotel_rounded,
      color: Colors.white.withValues(alpha: .75),
      size: 86,
    ),
  );

  Widget? _unitPhoto(AccommodationUnit unit) {
    final url = unit.primaryPhoto;
    if (url == null || url.isEmpty) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const Icon(Icons.bed_rounded),
      ),
    );
  }
}
