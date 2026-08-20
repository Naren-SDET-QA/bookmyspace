import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/settings_controller.dart';
import 'core/config/app_config.dart';
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
      allowUnauthenticatedTestAccess: AppConfig.allowUnauthenticatedTestAccess,
    );

    return MaterialApp.router(
      title: 'BookMySpace',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.lightFor(
        themePaletteColor(ref.watch(themePaletteProvider)),
      ),
      darkTheme: AppTheme.darkFor(
        themePaletteColor(ref.watch(themePaletteProvider)),
      ),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final simple = ref.watch(simpleModeProvider);
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.scale(simple ? 1.15 : 1.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
