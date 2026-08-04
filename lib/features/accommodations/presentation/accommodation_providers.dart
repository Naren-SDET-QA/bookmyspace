import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/accommodation.dart';
import '../domain/accommodation_repository.dart';
import '../infrastructure/supabase_accommodation_repository.dart';

final accommodationRepositoryProvider = Provider<AccommodationRepository>((
  ref,
) {
  return SupabaseAccommodationRepository(ref.watch(supabaseProvider));
});

final accommodationSearchProvider = FutureProvider.autoDispose
    .family<List<AccommodationProperty>, AccommodationQuery>((ref, query) {
      return ref.watch(accommodationRepositoryProvider).search(query);
    });

final accommodationDetailProvider = FutureProvider.autoDispose
    .family<AccommodationProperty, String>((ref, id) {
      return ref.watch(accommodationRepositoryProvider).detail(id);
    });
