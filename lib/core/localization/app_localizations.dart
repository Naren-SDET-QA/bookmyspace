import 'package:flutter/widgets.dart';

/// Localization keys for BookMySpace.
///
/// Two locales are supported:
///  * English (`en`)
///  * Telugu (`te`)
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [Locale('en'), Locale('te')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get appName => _t('appName');
  String get tagline => _t('tagline');

  // Common
  String get retry => _t('retry');
  String get cancel => _t('cancel');
  String get confirm => _t('confirm');
  String get save => _t('save');
  String get delete => _t('delete');
  String get search => _t('search');
  String get loading => _t('loading');
  String get next => _t('next');
  String get back => _t('back');
  String get done => _t('done');
  String get edit => _t('edit');
  String get viewAll => _t('viewAll');
  String get noResults => _t('noResults');
  String get noResultsMessage => _t('noResultsMessage');
  String get offline => _t('offline');
  String get offlineMessage => _t('offlineMessage');
  String get unknownError => _t('unknownError');
  String get somethingWentWrong => _t('somethingWentWrong');
  String get tryAgain => _t('tryAgain');

  // Onboarding
  String get onboardingTitle1 => _t('onboardingTitle1');
  String get onboardingSubtitle1 => _t('onboardingSubtitle1');
  String get onboardingTitle2 => _t('onboardingTitle2');
  String get onboardingSubtitle2 => _t('onboardingSubtitle2');
  String get onboardingTitle3 => _t('onboardingTitle3');
  String get onboardingSubtitle3 => _t('onboardingSubtitle3');
  String get getStarted => _t('getStarted');
  String get skip => _t('skip');

  // Navigation / bottom bar
  String get navHome => _t('navHome');
  String get navSearch => _t('navSearch');
  String get navBookings => _t('navBookings');
  String get navSaved => _t('navSaved');
  String get navProfile => _t('navProfile');

  // Venues
  String get venues => _t('venues');
  String get venueDetails => _t('venueDetails');
  String get amenities => _t('amenities');
  String get capacity => _t('capacity');
  String get operatingHours => _t('operatingHours');
  String get pricing => _t('pricing');
  String get ratings => _t('ratings');
  String get reviews => _t('reviews');
  String get checkAvailability => _t('checkAvailability');
  String get bookNow => _t('bookNow');
  String get nearbyVenues => _t('nearbyVenues');
  String get popularVenues => _t('popularVenues');

  // Home
  String get homeGreeting => _t('homeGreeting');
  String get findYourSpace => _t('findYourSpace');
  String get whatAreYouLookingFor => _t('whatAreYouLookingFor');
  String get explore => _t('explore');
  String get events => _t('events');
  String get courses => _t('courses');
  String get searchHint => _t('searchHint');

  // Booking
  String get selectDate => _t('selectDate');
  String get selectTimeSlot => _t('selectTimeSlot');
  String get availability => _t('availability');
  String get confirmBooking => _t('confirmBooking');
  String get bookingSummary => _t('bookingSummary');
  String get payment => _t('payment');
  String get payNow => _t('payNow');
  String get paymentSuccess => _t('paymentSuccess');
  String get paymentFailed => _t('paymentFailed');
  String get paymentPending => _t('paymentPending');
  String get myBookings => _t('myBookings');

  // Profile / Auth
  String get login => _t('login');
  String get signUp => _t('signUp');
  String get logout => _t('logout');
  String get email => _t('email');
  String get phone => _t('phone');
  String get name => _t('name');
  String get password => _t('password');
  String get continueWithGoogle => _t('continueWithGoogle');
  String get continueWithApple => _t('continueWithApple');
  String get myProfile => _t('myProfile');

  // Owner
  String get ownerDashboard => _t('ownerDashboard');
  String get ownerVenues => _t('ownerVenues');
  String get ownerRequests => _t('ownerRequests');
  String get ownerCalendar => _t('ownerCalendar');
  String get earnings => _t('earnings');
  String get addVenue => _t('addVenue');

  // Settings
  String get settings => _t('settings');
  String get language => _t('language');
  String get themeMode => _t('themeMode');
  String get notifications => _t('notifications');
  String get privacyPolicy => _t('privacyPolicy');
  String get termsAndConditions => _t('termsAndConditions');
  String get support => _t('support');
  String get deleteAccount => _t('deleteAccount');
  String get about => _t('about');

  // Errors
  String get errorNoInternet => _t('errorNoInternet');
  String get errorInvalidEmail => _t('errorInvalidEmail');
  String get errorInvalidPhone => _t('errorInvalidPhone');
  String get errorRequired => _t('errorRequired');
  String get errorInvalidAmount => _t('errorInvalidAmount');

  String _t(String key) =>
      _translations[locale.languageCode]?[key] ?? _translations['en']![key]!;

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'appName': 'BookMySpace',
      'tagline': 'Find and book your perfect space',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'search': 'Search',
      'loading': 'Loading…',
      'next': 'Next',
      'back': 'Back',
      'done': 'Done',
      'edit': 'Edit',
      'viewAll': 'View all',
      'noResults': 'No results found',
      'noResultsMessage': 'Try adjusting your filters or search term.',
      'offline': 'You are offline',
      'offlineMessage': 'Check your internet connection and try again.',
      'unknownError': 'Something went wrong',
      'somethingWentWrong': 'An unexpected error occurred. Please try again.',
      'tryAgain': 'Try again',
      'onboardingTitle1': 'Discover venues',
      'onboardingSubtitle1':
          'Find function halls, marriage halls, meeting rooms and more near you.',
      'onboardingTitle2': 'Book in seconds',
      'onboardingSubtitle2':
          'Check live availability, pick your slot and pay securely.',
      'onboardingTitle3': 'Manage everything',
      'onboardingSubtitle3':
          'Track bookings, get notifications and manage your calendar.',
      'getStarted': 'Get started',
      'skip': 'Skip',
      'navHome': 'Home',
      'navSearch': 'Search',
      'navBookings': 'Bookings',
      'navSaved': 'Saved',
      'navProfile': 'Profile',
      'venues': 'Venues',
      'venueDetails': 'Venue details',
      'amenities': 'Amenities',
      'capacity': 'Capacity',
      'operatingHours': 'Operating hours',
      'pricing': 'Pricing',
      'ratings': 'Ratings',
      'reviews': 'Reviews',
      'checkAvailability': 'Check availability',
      'bookNow': 'Book now',
      'nearbyVenues': 'Nearby venues',
      'popularVenues': 'Popular venues',
      'homeGreeting': 'Hello',
      'findYourSpace': 'Find your perfect space',
      'whatAreYouLookingFor': 'What are you looking for?',
      'explore': 'Explore',
      'events': 'Events',
      'courses': 'Courses',
      'searchHint': 'Search venues, areas, categories…',
      'selectDate': 'Select a date',
      'selectTimeSlot': 'Select a time slot',
      'availability': 'Availability',
      'confirmBooking': 'Confirm booking',
      'bookingSummary': 'Booking summary',
      'payment': 'Payment',
      'payNow': 'Pay now',
      'paymentSuccess': 'Payment successful',
      'paymentFailed': 'Payment failed',
      'paymentPending': 'Payment pending',
      'myBookings': 'My bookings',
      'login': 'Log in',
      'signUp': 'Sign up',
      'logout': 'Log out',
      'email': 'Email',
      'phone': 'Phone',
      'name': 'Name',
      'password': 'Password',
      'continueWithGoogle': 'Continue with Google',
      'continueWithApple': 'Continue with Apple',
      'myProfile': 'My profile',
      'ownerDashboard': 'Owner dashboard',
      'ownerVenues': 'My venues',
      'ownerRequests': 'Booking requests',
      'ownerCalendar': 'Calendar',
      'earnings': 'Earnings',
      'addVenue': 'Add venue',
      'settings': 'Settings',
      'language': 'Language',
      'themeMode': 'Theme',
      'notifications': 'Notifications',
      'privacyPolicy': 'Privacy policy',
      'termsAndConditions': 'Terms & conditions',
      'support': 'Support',
      'deleteAccount': 'Delete account',
      'about': 'About',
      'errorNoInternet': 'No internet connection',
      'errorInvalidEmail': 'Enter a valid email address',
      'errorInvalidPhone': 'Enter a valid phone number',
      'errorRequired': 'This field is required',
      'errorInvalidAmount': 'Enter a valid amount',
    },
    'te': {
      'appName': 'బుక్‌మైస్‌పేస్',
      'tagline': 'మీ స్థలాన్ని కనుగొని బుక్ చేసుకోండి',
      'retry': 'తిరిగి ప్రయత్నించండి',
      'cancel': 'రద్దు చేయండి',
      'confirm': 'నిర్ధారించండి',
      'save': 'సేవ్ చేయండి',
      'delete': 'తొలగించండి',
      'search': 'వెతకండి',
      'loading': 'లోడ్ అవుతోంది…',
      'next': 'తరువాత',
      'back': 'వెనుకకు',
      'done': 'పూర్తయింది',
      'edit': 'సవరించండి',
      'viewAll': 'అన్నీ చూడండి',
      'noResults': 'ఫలితాలు లేవు',
      'noResultsMessage': 'మీ ఫిల్టర్లు లేదా శోధన పదాన్ని మార్చండి.',
      'offline': 'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు',
      'offlineMessage': 'ఇంటర్నెట్ కనెక్షన్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
      'unknownError': 'ఏదో తప్పు జరిగింది',
      'somethingWentWrong':
          'ఊహించని లోపం సంభవించింది. దయచేసి మళ్లీ ప్రయత్నించండి.',
      'tryAgain': 'మళ్లీ ప్రయత్నించండి',
      'onboardingTitle1': 'వేదికలను కనుగొనండి',
      'onboardingSubtitle1':
          'మీ సమీపంలో ఫంక్షన్ హాల్స్, మ్యారేజ్ హాల్స్, మీటింగ్ రూమ్స్ కనుగొనండి.',
      'onboardingTitle2': 'సెకన్లలో బుక్ చేయండి',
      'onboardingSubtitle2':
          'లైవ్ అందుబాటును తనిఖీ చేసి, స్లాట్ ఎంచుకుని సురక్షితంగా చెల్లించండి.',
      'onboardingTitle3': 'అన్నింటినీ నిర్వహించండి',
      'onboardingSubtitle3':
          'బుకింగ్‌లను ట్రాక్ చేయండి, నోటిఫికేషన్లు పొందండి.',
      'getStarted': 'ప్రారంభించండి',
      'skip': 'దాటవేయి',
      'navHome': 'హోమ్',
      'navSearch': 'శోధన',
      'navBookings': 'బుకింగ్స్',
      'navSaved': 'సేవ్డ్',
      'navProfile': 'ప్రొఫైల్',
      'venues': 'వేదికలు',
      'venueDetails': 'వేదిక వివరాలు',
      'amenities': 'సౌకర్యాలు',
      'capacity': 'సామర్థ్యం',
      'operatingHours': 'పని వేళలు',
      'pricing': 'ధర',
      'ratings': 'రేటింగ్స్',
      'reviews': 'సమీక్షలు',
      'checkAvailability': 'అందుబాటు తనిఖీ',
      'bookNow': 'ఇప్పుడే బుక్ చేయండి',
      'nearbyVenues': 'సమీప వేదికలు',
      'popularVenues': 'ప్రసిద్ధ వేదికలు',
      'homeGreeting': 'నమస్తే',
      'findYourSpace': 'మీ స్థలాన్ని కనుగొనండి',
      'whatAreYouLookingFor': 'మీరు ఏమి వెతుకుతున్నారు?',
      'explore': 'అన్వేషించండి',
      'events': 'ఈవెంట్స్',
      'courses': 'కోర్సులు',
      'searchHint': 'వేదికలు, ప్రాంతాలు, వర్గాలను వెతకండి…',
      'selectDate': 'తేదీని ఎంచుకోండి',
      'selectTimeSlot': 'టైమ్ స్లాట్ ఎంచుకోండి',
      'availability': 'అందుబాటు',
      'confirmBooking': 'బుకింగ్ నిర్ధారించండి',
      'bookingSummary': 'బుకింగ్ సారాంశం',
      'payment': 'చెల్లింపు',
      'payNow': 'ఇప్పుడే చెల్లించండి',
      'paymentSuccess': 'చెల్లింపు విజయవంతమైంది',
      'paymentFailed': 'చెల్లింపు విఫలమైంది',
      'paymentPending': 'చెల్లింపు పెండింగ్‌లో ఉంది',
      'myBookings': 'నా బుకింగ్స్',
      'login': 'లాగిన్',
      'signUp': 'సైన్ అప్',
      'logout': 'లాగ్ అవుట్',
      'email': 'ఇమెయిల్',
      'phone': 'ఫోన్',
      'name': 'పేరు',
      'password': 'పాస్‌వర్డ్',
      'continueWithGoogle': 'Google తో కొనసాగండి',
      'continueWithApple': 'Apple తో కొనసాగండి',
      'myProfile': 'నా ప్రొఫైల్',
      'ownerDashboard': 'యజమాని డాష్‌బోర్డ్',
      'ownerVenues': 'నా వేదికలు',
      'ownerRequests': 'బుకింగ్ అభ్యర్థనలు',
      'ownerCalendar': 'క్యాలెండర్',
      'earnings': 'ఆదాయాలు',
      'addVenue': 'వేదికను జోడించండి',
      'settings': 'సెట్టింగ్స్',
      'language': 'భాష',
      'themeMode': 'థీమ్',
      'notifications': 'నోటిఫికేషన్లు',
      'privacyPolicy': 'గోప్యతా విధానం',
      'termsAndConditions': 'నిబంధనలు & షరతులు',
      'support': 'సహాయం',
      'deleteAccount': 'ఖాతాను తొలగించండి',
      'about': 'గురించి',
      'errorNoInternet': 'ఇంటర్నెట్ కనెక్షన్ లేదు',
      'errorInvalidEmail': 'చెల్లుబాటు అయ్యే ఇమెయిల్ నమోదు చేయండి',
      'errorInvalidPhone': 'చెల్లుబాటు అయ్యే ఫోన్ నంబర్ నమోదు చేయండి',
      'errorRequired': 'ఈ ఫీల్డ్ అవసరం',
      'errorInvalidAmount': 'చెల్లుబాటు అయ్యే మొత్తం నమోదు చేయండి',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
