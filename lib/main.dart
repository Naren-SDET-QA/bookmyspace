import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/test_mode.dart';
import 'core/debug/debug_log.dart';
import 'core/firebase/error_logger.dart';
import 'features/auth/presentation/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DebugLog.info(
    'STARTUP',
    'Test Mode ${TestMode.enabled ? 'enabled' : 'disabled'} · backend '
    '${TestMode.supabaseUrl}',
    detail:
        'debugMenu=${TestMode.debugMenuEnabled} '
        'network=${TestMode.networkLoggingEnabled} '
        'api=${TestMode.apiLoggingEnabled} '
        'crash=${TestMode.crashLoggingEnabled} '
        'perf=${TestMode.performanceLoggingEnabled}',
  );

  // Initialize Firebase services (Crashlytics, Performance, Analytics)
  await ErrorLogger.init();

  // Initialize Supabase
  await initSupabase();

  DebugLog.info('STARTUP', 'Supabase initialised');

  runApp(const ProviderScope(child: BookMySpaceApp()));
}
