import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../infrastructure/supabase_discovery_repository.dart';

final discoveryRepositoryProvider = Provider<SupabaseDiscoveryRepository>((
  ref,
) {
  return SupabaseDiscoveryRepository(ref.watch(supabaseProvider));
});

/// Staging rows awaiting admin review (`venue_discovery_staging`,
/// status = PENDING_REVIEW). Populated both by this app's own search screen
/// and by anyone else calling the `import-venues` edge function.
final pendingDiscoveryStagingProvider = FutureProvider<
  List<Map<String, dynamic>>
>((ref) {
  return ref.watch(discoveryRepositoryProvider).pendingReview();
});
