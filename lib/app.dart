import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/settings_controller.dart';
import 'core/config/app_config.dart';
import 'core/localization/app_localizations.dart';
import 'core/notifications/onesignal_push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/admin/presentation/admin_settings_providers.dart';
import 'features/admin/domain/admin_settings.dart';
import 'features/notifications/presentation/notification_providers.dart';
import 'core/health/app_health.dart';
import 'core/health/app_health_status.dart';
import 'core/offline/offline_cached_banner.dart';
import 'core/offline/offline_providers.dart';
import 'features/booking/presentation/booking_providers.dart';
import 'features/venues/presentation/venue_providers.dart';

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

    // Register/deregister this device's OneSignal push subscription
    // whenever the signed-in user changes. A no-op when ONESIGNAL_APP_ID
    // is not configured (e.g. missing native config in this dev
    // environment, or in widget tests, which never initialize OneSignal).
    ref.listen(passwordRecoveryProvider, (previous, next) {
      if (next.valueOrNull == true) {
        final navContext = rootNavigatorKey.currentContext;
        if (navContext != null) {
          GoRouter.of(navContext).go(AppRoutes.resetPassword);
        }
      }
    });
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        unawaited(
          OneSignalPushService.instance.onSignedIn(
            ref.read(deviceTokenRepositoryProvider),
            user.id,
          ),
        );
      } else if (previous?.value != null) {
        unawaited(OneSignalPushService.instance.onSignedOut());
      }
    });
    final adminSettings =
        ref.watch(adminSettingsProvider).valueOrNull ?? AdminSettings.defaults;
    final palette = ref.watch(themePaletteProvider);
    final adminColor = AdminSettings.color(
      adminSettings.theme['primary_color'],
      AppTheme.brand,
    );
    final primaryColor = palette == ThemePalette.defaultPalette.name
        ? adminColor
        : themePaletteColor(palette);

    final router = createAppRouter(
      initialLocation: initialLocation ?? AppRoutes.shell,
      currentUser: currentUser,
      authReady: authReady,
      allowUnauthenticatedTestAccess: AppConfig.allowUnauthenticatedTestAccess,
    );

    return MaterialApp.router(
      title: 'BookMySpace',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.lightFor(primaryColor),
      darkTheme: AppTheme.darkFor(primaryColor),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, _) => AppLocalizations.resolve(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final simple = ref.watch(simpleModeProvider);
        final media = MediaQuery.of(context);
        final servingCached = ref.watch(servingCachedDataProvider);
        final health = ref.watch(appHealthProvider);
        final showHealthBanner = health.maybeWhen(
          data: (snapshot) =>
              snapshot.status == AppHealthStatus.degraded ||
              snapshot.status == AppHealthStatus.failed,
          error: (_, _) => true,
          orElse: () => false,
        );
        final showTopBanners = showHealthBanner || servingCached;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1) * (simple ? 1.15 : 1.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTopBanners)
                SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppHealthStatusWidget(),
                      OfflineCachedBanner(
                        onRetry: () {
                          ref.invalidate(searchResultsProvider);
                          ref.invalidate(popularVenuesProvider);
                          ref.invalidate(nearbyVenuesProvider);
                          ref.invalidate(moduleVenuesProvider);
                          ref.invalidate(venueDetailsProvider);
                          ref.invalidate(favoritesProvider);
                          ref.invalidate(myBookingsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: showTopBanners,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
