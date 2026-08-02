import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/app_config.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../infrastructure/supabase_auth_repository.dart';

/// Initialises the Supabase client. Call once before runApp().
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
}

/// Exposes the Supabase client.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Auth repository implementation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseProvider));
});

/// Streams the current authentication state.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});
