import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/test_mode.dart';
import '../../../core/network/logging_http_client.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../infrastructure/supabase_auth_repository.dart';

/// Initialises the Supabase client. Call once before runApp().
///
/// In Test Mode the app uses the existing development backend URL and wraps
/// the real HTTP transport with a logging client so every API call is visible
/// in the debug menu. No local server, proxy or mock is involved.
Future<void> initSupabase() async {
  final client = http.Client();
  final httpClient = TestMode.networkLoggingEnabled
      ? LoggingHttpClient(client)
      : client;

  await Supabase.initialize(
    url: TestMode.supabaseUrl,
    publishableKey: TestMode.supabaseAnonKey,
    httpClient: httpClient,
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
