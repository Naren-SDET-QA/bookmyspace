import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/owner.dart';
import '../infrastructure/supabase_owner_repository.dart';

/// Owner repository instance.
final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseOwnerRepository(client);
});

/// Current owner profile (null if not an owner).
final currentOwnerProvider = FutureProvider<Owner?>((ref) {
  return ref.watch(ownerRepositoryProvider).currentOwner();
});

/// Sign in with email/password for owners.
final ownerSignInProvider = FutureProvider.autoDispose.family<
    Owner, ({String email, String password})>((ref, params) async {
  return ref.watch(ownerRepositoryProvider).signInWithEmailPassword(
        params.email,
        params.password,
      );
});

/// Create a new owner profile.
final createOwnerProvider = FutureProvider.autoDispose.family<
    Owner, ({String email, String name, String password})>((ref, params) async {
  return ref.watch(ownerRepositoryProvider).createOwner(
        email: params.email,
        name: params.name,
        password: params.password,
      );
});
