import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/error_logger.dart';
import 'features/auth/presentation/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasSupabaseConfiguration) {
    try {
      await ErrorLogger.init();
      await initSupabase();
    } catch (e) {
      debugPrint('Error initializing backend: $e');
    }
  } else {
    debugPrint('Running BookMySpace in local Demo UI mode.');
  }

  runApp(const ProviderScope(child: BookMySpaceApp()));
}
