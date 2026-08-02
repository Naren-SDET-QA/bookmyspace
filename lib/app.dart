import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/settings_controller.dart';
import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_providers.dart';

/// Root widget that wires together providers, theming, localization and routing.
class BookMySpaceApp extends ConsumerWidget {
  const BookMySpaceApp({super.key, this.initialLocation});

  /// Overridable initial route (used in tests).
  final String? initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final currentUser = authAsync.value;
    final authReady = !authAsync.isLoading;

    final router = createAppRouter(
      initialLocation: initialLocation ?? AppRoutes.shell,
      currentUser: currentUser,
      authReady: authReady,
    );

    return MaterialApp.router(
      title: 'BookMySpace',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
