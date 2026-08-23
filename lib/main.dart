import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/error_logger.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/owner/infrastructure/supabase_owner_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase services (Crashlytics, Performance, Analytics)
  await ErrorLogger.init();

  // Initialize Supabase
  await initSupabase();
  try {
    await SupabaseOwnerRepository(
      Supabase.instance.client,
    ).completePendingOwnerRegistration();
  } catch (error) {
    debugPrint('Pending owner registration could not be completed: $error');
  }
  // Optional, explicitly supplied DEV-only account for live regression.
  // Without these dart-defines the normal login/bypass behavior is unchanged.
  try {
    await signInDevelopmentTestUser();
  } catch (error) {
    debugPrint('DEV test sign-in unavailable: $error');
  }

  runApp(const ProviderScope(child: BookMySpaceApp()));
}
