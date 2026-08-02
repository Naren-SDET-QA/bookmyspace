/// Central constants used across the application.
class AppConstants {
  AppConstants._();

  static const String appName = 'BookMySpace';
  static const String appVersion = '1.0.0';

  /// Supabase auth storage key in FlutterSecureStorage.
  static const String secureStorageAuthKey = 'bms_auth_session';

  /// Key used to persist the chosen locale.
  static const String prefsLocaleKey = 'bms_locale';

  /// Key used to persist the theme mode.
  static const String prefsThemeModeKey = 'bms_theme_mode';

  /// Key used to flag whether onboarding has been completed.
  static const String prefsOnboardingDoneKey = 'bms_onboarding_done';

  /// Radius presets (in kilometres) for nearby search.
  static const List<double> searchRadiusKm = [1, 2, 5, 10, 25, 50];

  static const int defaultPageSize = 20;
  static const int maxSearchResults = 100;
}
