import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/check_in.dart';
import '../infrastructure/supabase_check_in_repository.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return SupabaseCheckInRepository(ref.watch(supabaseProvider));
});
