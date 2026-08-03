import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/event.dart';
import '../domain/event_repository.dart';
import '../infrastructure/supabase_event_repository.dart';

/// Events repository instance.
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseEventRepository(client);
});

/// Upcoming published events, soonest first.
final upcomingEventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).upcomingEvents();
});

/// A single event's live detail (capacity + my registration state).
final eventDetailProvider = FutureProvider.autoDispose.family<Event, String>((
  ref,
  eventId,
) {
  return ref.watch(eventRepositoryProvider).eventDetail(eventId);
});

/// Registers the current user and refreshes the event caches.
final registerForEventProvider = FutureProvider.autoDispose
    .family<EventRegistration, String>((ref, eventId) async {
      final repo = ref.watch(eventRepositoryProvider);
      final registration = await repo.register(eventId: eventId);
      ref.invalidate(eventDetailProvider(eventId));
      ref.invalidate(upcomingEventsProvider);
      return registration;
    });

/// Cancels my registration and refreshes the event caches.
final cancelEventRegistrationProvider = FutureProvider.autoDispose
    .family<void, String>((ref, eventId) async {
      final repo = ref.watch(eventRepositoryProvider);
      await repo.cancelRegistration(eventId: eventId);
      ref.invalidate(eventDetailProvider(eventId));
      ref.invalidate(upcomingEventsProvider);
    });
