import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/config/settings_controller.dart';
import 'core/notifications/onesignal_push_service.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/preferences_offline_store.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/booking/domain/booking_reminder_scheduler.dart';
import 'features/owner/infrastructure/supabase_owner_repository.dart';
import 'core/health/app_health.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize push notifications (OneSignal). No-op when
  // ONESIGNAL_APP_ID is not configured, e.g. in this dev environment or
  // in flutter test.
  await OneSignalPushService.instance.init();

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

  runApp(
    ProviderScope(
      overrides: [
        offlineStoreProvider.overrideWithValue(
          PreferencesOfflineStore(Preferences(const FlutterSecureStorage())),
        ),
        localReminderGatewayProvider.overrideWithValue(
          FlutterLocalReminderGateway(),
        ),
      ],
      child: const BookMySpaceApp(),
    ),
  );
  // Health is deliberately started after the first frame boundary and is
  // never awaited by startup or allowed to prevent UI rendering.
  unawaited(_scanAppHealth());
}

Future<void> _scanAppHealth() async {
  final container = ProviderContainer();
  try {
    await container.read(appHealthProvider.future);
  } finally {
    container.dispose();
  }
}
