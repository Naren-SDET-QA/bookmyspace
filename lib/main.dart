import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/error_logger.dart';
import 'features/auth/presentation/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase services (Crashlytics, Performance, Analytics)
  await ErrorLogger.init();

  // Initialize Supabase
  await initSupabase();

  runApp(const ProviderScope(child: BookMySpaceApp()));
}
