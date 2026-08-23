import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../institute_listings/domain/institute_listing.dart';
import '../../institute_listings/domain/institute_listing_plan.dart';
import '../../institute_listings/domain/institute_listing_repository.dart';
import '../../institute_listings/infrastructure/supabase_institute_listing_repository.dart';
import '../domain/institute_profile.dart';
import '../domain/institute_repository.dart';
import '../infrastructure/supabase_institute_repository.dart';

final instituteRepositoryProvider = Provider<InstituteRepository>((ref) {
  return SupabaseInstituteRepository(ref.watch(supabaseProvider));
});

final instituteListingRepositoryProvider =
    Provider<InstituteListingRepository>((ref) {
  return SupabaseInstituteListingRepository(ref.watch(supabaseProvider));
});

final publishedInstitutesProvider =
    FutureProvider<List<InstituteProfile>>((ref) {
  return ref.watch(instituteRepositoryProvider).publishedInstitutes();
});

final instituteDetailProvider =
    FutureProvider.family<InstituteProfile, String>((ref, id) {
  return ref.watch(instituteRepositoryProvider).detail(id);
});

final myInstituteProvider = FutureProvider<InstituteProfile?>((ref) {
  return ref.watch(instituteRepositoryProvider).myInstitute();
});

final instituteListingPlansProvider =
    FutureProvider<List<InstituteListingPlan>>((ref) async {
  try {
    final rows = await ref
        .watch(supabaseProvider)
        .from('institute_listing_plans')
        .select()
        .eq('is_active', true);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(InstituteListingPlan.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
});

final activeInstituteListingProvider =
    FutureProvider.family<InstituteListing?, String>((ref, instituteId) {
  return ref
      .watch(instituteListingRepositoryProvider)
      .getActiveListingForInstitute(instituteId);
});
