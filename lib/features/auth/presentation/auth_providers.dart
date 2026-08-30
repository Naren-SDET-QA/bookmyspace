import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/app_config.dart';
import '../../../core/notifications/onesignal_push_service.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../infrastructure/supabase_auth_repository.dart';

/// Initialises the Supabase client. Call once before runApp().
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );
}

/// Optionally establishes a real DEV Auth session for browser regression runs.
/// Credentials are supplied at launch and are never available in production.
Future<void> signInDevelopmentTestUser() async {
  if (!AppConfig.isDevelopment ||
      AppConfig.devTestEmail.isEmpty ||
      AppConfig.devTestPassword.isEmpty) {
    return;
  }
  final client = Supabase.instance.client;
  if (client.auth.currentSession != null) return;
  await client.auth.signInWithPassword(
    email: AppConfig.devTestEmail,
    password: AppConfig.devTestPassword,
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

/// Auth state holder.
class AuthState {
  const AuthState({this.user, this.isLoading = false, this.error});

  final AuthUser? user;
  final bool isLoading;
  final String? error;

  AuthState copyWith({AuthUser? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// State notifier managing active user profile updates and authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository)
    : super(AuthState(user: _repository.currentUser)) {
    _repository.authStateChanges().listen((user) {
      state = state.copyWith(user: user, isLoading: false);
    });
  }

  final AuthRepository _repository;

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.updateProfile(
        fullName: fullName,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(user: updatedUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    // Drop the OneSignal push-subscription registration and log this
    // device out of its OneSignal External ID association while the
    // session is still valid, so RLS can delete the device_tokens row
    // and this device stops being targetable as this user. After
    // signOut(), auth.uid() is null.
    await OneSignalPushService.instance.onSignedOut();
    await _repository.signOut();
    state = const AuthState(user: null);
  }
}

/// Global AuthNotifierProvider for reactive UI consumption.
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// Direct accessor for the current user.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authNotifierProvider).user;
});
