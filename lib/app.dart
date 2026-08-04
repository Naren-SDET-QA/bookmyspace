import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/settings_controller.dart';
import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_callback.dart';
import 'features/auth/domain/auth_user.dart';
import 'features/auth/presentation/auth_providers.dart';

/// Root widget that wires together providers, theming, localization and routing.
class BookMySpaceApp extends ConsumerWidget {
  const BookMySpaceApp({super.key, this.initialLocation});

  /// Overridable initial route (used in tests).
  final String? initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final currentUser = authAsync.asData?.value;
    final authReady = !authAsync.isLoading;
    final roleAsync = ref.watch(appAccessRoleProvider);
    final themeColor = ref.watch(themeColorProvider);

    final router = createAppRouter(
      initialLocation:
          initialLocation ??
          (isAuthCallbackUri(Uri.base)
              ? AppRoutes.authCallback
              : AppRoutes.shell),
      currentUser: currentUser,
      authReady: authReady,
      accessRole: roleAsync.asData?.value ?? AppAccessRole.customer,
      roleReady: !roleAsync.isLoading,
    );

    return MaterialApp.router(
      title: 'BookMySpace',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.lightFor(themeColor),
      darkTheme: AppTheme.darkFor(themeColor),
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
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
