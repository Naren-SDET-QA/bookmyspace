import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/sports_venue.dart';
import '../infrastructure/supabase_sports_repository.dart';

final sportsRepositoryProvider = Provider<SportsRepository>(
  (ref) => SupabaseSportsRepository(ref.watch(supabaseProvider)),
);
final sportsVenuesProvider = FutureProvider<List<SportsVenue>>(
  (ref) => ref.watch(sportsRepositoryProvider).venues(),
);
final ownerSportsVenuesProvider = FutureProvider<List<SportsVenue>>(
  (ref) => ref.watch(sportsRepositoryProvider).venues(owned: true),
);
final sportsVenueProvider = FutureProvider.family<SportsVenue, String>(
  (ref, id) => ref.watch(sportsRepositoryProvider).venue(id),
);
