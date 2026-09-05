import 'package:flutter/widgets.dart';

/// Localization keys for BookMySpace.
///
/// Supported locales: English, Telugu, Hindi, Tamil, Kannada, Marathi,
/// Bengali, Gujarati, Malayalam, Spanish. Missing keys fall back to English.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('te'),
    Locale('hi'),
    Locale('ta'),
    Locale('kn'),
    Locale('mr'),
    Locale('bn'),
    Locale('gu'),
    Locale('ml'),
    Locale('es'),
  ];

  static String languageLabel(Locale locale) => switch (locale.languageCode) {
    'en' => 'English',
    'te' => 'తెలుగు',
    'hi' => 'हिन्दी',
    'ta' => 'தமிழ்',
    'kn' => 'ಕನ್ನಡ',
    'mr' => 'मराठी',
    'bn' => 'বাংলা',
    'gu' => 'ગુજરાતી',
    'ml' => 'മലയാളം',
    'es' => 'Español',
    _ => locale.languageCode,
  };

  /// Resolves [locale] onto a supported language, falling back to English.
  static Locale resolve(Locale? locale) {
    if (locale == null) return supportedLocales.first;
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return supportedLocales.first;
  }

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
  String get navMap => _t('navMap');
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
  String get saveVenue => _t('saveVenue');
  String get savedVenues => _t('savedVenues');
  String get noSavedVenues => _t('noSavedVenues');
  String get noSavedVenuesMessage => _t('noSavedVenuesMessage');
  String get filters => _t('filters');
  String get clearFilters => _t('clearFilters');
  String get sortBy => _t('sortBy');
  String get relevance => _t('relevance');
  String get priceLowToHigh => _t('priceLowToHigh');
  String get priceHighToLow => _t('priceHighToLow');
  String get topRated => _t('topRated');
  String get minPrice => _t('minPrice');
  String get maxPrice => _t('maxPrice');
  String get allCategories => _t('allCategories');
  String get apply => _t('apply');
  String get nearest => _t('nearest');
  String get useMyLocation => _t('useMyLocation');
  String get resultsCount => _t('resultsCount');
  String get aboutThisVenue => _t('aboutThisVenue');
  String get details => _t('details');
  String get address => _t('address');
  String get openNow => _t('openNow');
  String get closedNow => _t('closedNow');
  String get foodOptions => _t('foodOptions');
  String get rules => _t('rules');
  String get parking => _t('parking');
  String get taxRate => _t('taxRate');
  String get basePrice => _t('basePrice');
  String get discount => _t('discount');
  String get viewOnMap => _t('viewOnMap');
  String get gallery => _t('gallery');
  String get explore => _t('explore');
  String get events => _t('events');
  String get courses => _t('courses');
  String get searchHint => _t('searchHint');
  String get recentSearches => _t('recentSearches');
  String get clearRecentSearches => _t('clearRecentSearches');
  String get noRecentSearches => _t('noRecentSearches');
  String get servingCachedData => _t('servingCachedData');
  String get holdExpired => _t('holdExpired');
  String holdExpiresIn(String time) =>
      _t('holdExpiresIn').replaceFirst('{time}', time);
  String get venueOptimizer => _t('venueOptimizer');
  String get contextualHelp => _t('contextualHelp');

  // Events
  String get upcomingEvents => _t('upcomingEvents');
  String get noUpcomingEvents => _t('noUpcomingEvents');
  String get noUpcomingEventsMessage => _t('noUpcomingEventsMessage');
  String get freeEvent => _t('freeEvent');
  String get registerNow => _t('registerNow');
  String get registered => _t('registered');
  String get seatsLeft => _t('seatsLeft');
  String get soldOut => _t('soldOut');
  String get yourTicket => _t('yourTicket');
  String get cancelRegistration => _t('cancelRegistration');
  String get cancelRegistrationConfirm => _t('cancelRegistrationConfirm');
  String get registrationCancelled => _t('registrationCancelled');
  String get searchEvents => _t('searchEvents');
  String get allEvents => _t('allEvents');
  String get paidEvent => _t('paidEvent');

  // Courses
  String get noCourses => _t('noCourses');
  String get noCoursesMessage => _t('noCoursesMessage');
  String get enrollNow => _t('enrollNow');
  String get enrolled => _t('enrolled');
  String get enrollInCourse => _t('enrollInCourse');
  String get courseFee => _t('courseFee');
  String get durationWeeks => _t('durationWeeks');
  String get instructor => _t('instructor');
  String get batchStartsOn => _t('batchStartsOn');
  String get modeOnline => _t('modeOnline');
  String get modeOffline => _t('modeOffline');
  String get modeHybrid => _t('modeHybrid');
  String get dropEnrollment => _t('dropEnrollment');
  String get dropEnrollmentConfirm => _t('dropEnrollmentConfirm');
  String get enrollmentDropped => _t('enrollmentDropped');
  String get searchCourses => _t('searchCourses');
  String get allModes => _t('allModes');
  String get demoSession => _t('demoSession');
  String get paidCourse => _t('paidCourse');
  String get searchInstitutes => _t('searchInstitutes');
  String get institutesAndClasses => _t('institutesAndClasses');
  String get noInstitutes => _t('noInstitutes');
  String get noInstitutesMessage => _t('noInstitutesMessage');
  String get verifiedOnly => _t('verifiedOnly');
  String get unifiedRegistration => _t('unifiedRegistration');
  String get unifiedRegistrationHint => _t('unifiedRegistrationHint');

  // Booking
  String get selectDate => _t('selectDate');
  String get selectTimeSlot => _t('selectTimeSlot');
  String get availability => _t('availability');
  String get confirmBooking => _t('confirmBooking');
  String get bookingSummary => _t('bookingSummary');
  String get bookingDetails => _t('bookingDetails');
  String get eventType => _t('eventType');
  String get guestName => _t('guestName');
  String get tenantName => _t('tenantName');
  String get idNumber => _t('idNumber');
  String get payment => _t('payment');
  String get payNow => _t('payNow');
  String get bookAgain => _t('bookAgain');
  String get paymentSuccess => _t('paymentSuccess');
  String get paymentFailed => _t('paymentFailed');
  String get paymentPending => _t('paymentPending');
  String get paymentCancelled => _t('paymentCancelled');
  String get verifyingPayment => _t('verifyingPayment');
  String get paymentPendingMessage => _t('paymentPendingMessage');
  String get requestRefund => _t('requestRefund');
  String get requestRefundConfirm => _t('requestRefundConfirm');
  String get refundRequested => _t('refundRequested');
  String get myBookings => _t('myBookings');
  String get noSlotsForDate => _t('noSlotsForDate');
  String get total => _t('total');
  String get promoCode => _t('promoCode');
  String get promoCodeHint => _t('promoCodeHint');
  String get promoCodeApplied => _t('promoCodeApplied');
  String get remove => _t('remove');
  String get paymentMethod => _t('paymentMethod');
  String get payAtVenue => _t('payAtVenue');
  String get bookingConfirmed => _t('bookingConfirmed');
  String get bookingSuccessTitle => _t('bookingSuccessTitle');
  String get copy => _t('copy');
  String get copiedToClipboard => _t('copiedToClipboard');
  String get exploreMoreSpaces => _t('exploreMoreSpaces');
  String get noBookings => _t('noBookings');
  String get noBookingsMessage => _t('noBookingsMessage');
  String get cancelBooking => _t('cancelBooking');
  String get cancelBookingConfirm => _t('cancelBookingConfirm');
  String get keep => _t('keep');

  // Booking details / invoice
  String get invoice => _t('invoice');
  String get viewInvoice => _t('viewInvoice');
  String get invoiceFor => _t('invoiceFor');
  String get invoiceEmailQueued => _t('invoiceEmailQueued');
  String get invoiceEmailNotQueued => _t('invoiceEmailNotQueued');
  String get bookingRef => _t('bookingRef');
  String get bookingStatus => _t('bookingStatus');
  String get dateOfBooking => _t('dateOfBooking');
  String get customer => _t('customer');
  String get guestCount => _t('guestCount');
  String get checkIn => _t('checkIn');
  String get checkOut => _t('checkOut');
  String get moveIn => _t('moveIn');
  String get sharingOption => _t('sharingOption');
  String get rent => _t('rent');
  String get deposit => _t('deposit');
  String get changeSharing => _t('changeSharing');
  String get monthlyRentCalculator => _t('monthlyRentCalculator');
  String get selectRoomSharing => _t('selectRoomSharing');
  String get stayDuration => _t('stayDuration');
  String get perMonth => _t('perMonth');
  String get monthlyPayable => _t('monthlyPayable');
  String get refundableSecurityDeposit => _t('refundableSecurityDeposit');
  String get estimatedTotalMoveIn => _t('estimatedTotalMoveIn');
  String monthsLabel(int count) => _t(
    count == 1 ? 'monthCount' : 'monthsCount',
  ).replaceFirst('{count}', '$count');
  String totalRentForTenure(int count) =>
      _t('totalRentForTenure').replaceFirst('{count}', '$count');
  String maintenanceCharges(int count) =>
      _t('maintenanceCharges').replaceFirst('{count}', '$count');
  String get slotHeld => _t('slotHeld');
  String get payMethod => _t('payMethod');
  String get onlinePayment => _t('onlinePayment');
  String get offlinePayment => _t('offlinePayment');
  String get paidOn => _t('paidOn');
  String get paymentRef => _t('paymentRef');
  String get paymentHistory => _t('paymentHistory');
  String get noPaymentHistory => _t('noPaymentHistory');
  String get noPaymentHistoryMessage => _t('noPaymentHistoryMessage');
  String get transactionSummary => _t('transactionSummary');
  String get razorpayTransactionId => _t('razorpayTransactionId');
  String get razorpayOrderId => _t('razorpayOrderId');
  String get bookingId => _t('bookingId');
  String get walkIn => _t('walkIn');
  String get statusHeld => _t('statusHeld');
  String get statusPending => _t('statusPending');
  String get statusConfirmed => _t('statusConfirmed');
  String get statusCompleted => _t('statusCompleted');
  String get statusCancelled => _t('statusCancelled');
  String get statusRefunded => _t('statusRefunded');
  String get statusNoShow => _t('statusNoShow');
  String get statusPendingOwnerApproval => _t('statusPendingOwnerApproval');
  String get statusRejected => _t('statusRejected');
  String get slotBooked => _t('slotBooked');
  String get slotUnavailable => _t('slotUnavailable');
  String get slotBlocked => _t('slotBlocked');
  String get slotClosed => _t('slotClosed');
  String get listingOnly => _t('listingOnly');
  String get listingOnlyMessage => _t('listingOnlyMessage');
  String get call => _t('call');
  String get whatsapp => _t('whatsapp');
  String get callingVenue => _t('callingVenue');
  String get openingWhatsApp => _t('openingWhatsApp');
  String get digitalEntryPass => _t('digitalEntryPass');
  String get viewEntryPass => _t('viewEntryPass');
  String get entryPassHint => _t('entryPassHint');
  String get openInGoogleMaps => _t('openInGoogleMaps');

  // Owner bookings / offline
  String get ownerBookings => _t('ownerBookings');
  String get newOfflineBooking => _t('newOfflineBooking');
  String get offlineBooking => _t('offlineBooking');
  String get createOfflineBooking => _t('createOfflineBooking');
  String get customerName => _t('customerName');
  String get customerPhone => _t('customerPhone');
  String get selectVenue => _t('selectVenue');
  String get noOwnerBookings => _t('noOwnerBookings');
  String get noOwnerVenuesMessage => _t('noOwnerVenuesMessage');
  String get completeBooking => _t('completeBooking');
  String get markNoShow => _t('markNoShow');
  String get approveBooking => _t('approveBooking');
  String get rejectBooking => _t('rejectBooking');
  String get approveBookingConfirm => _t('approveBookingConfirm');
  String get rejectBookingConfirm => _t('rejectBookingConfirm');
  String get bookingApproved => _t('bookingApproved');
  String get bookingRejected => _t('bookingRejected');
  String get bookingRejectedRefundRequested =>
      _t('bookingRejectedRefundRequested');

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
  String get signInWithEmailOtp => _t('signInWithEmailOtp');
  String get signInWithPhoneOtp => _t('signInWithPhoneOtp');
  String get otpPlaceholder => _t('otpPlaceholder');
  String get verifyOtp => _t('verifyOtp');
  String get sendOtp => _t('sendOtp');
  String get resendOtp => _t('resendOtp');
  String get otpSent => _t('otpSent');
  String get authFailed => _t('authFailed');
  String get forgotPassword => _t('forgotPassword');
  String get resetPassword => _t('resetPassword');
  String get sendResetLink => _t('sendResetLink');
  String get resetEmailPrompt => _t('resetEmailPrompt');
  String get resetEmailSent => _t('resetEmailSent');
  String get resetEmailSentMessage => _t('resetEmailSentMessage');
  String get resetPasswordPrompt => _t('resetPasswordPrompt');
  String get newPassword => _t('newPassword');
  String get confirmPassword => _t('confirmPassword');
  String get passwordsDoNotMatch => _t('passwordsDoNotMatch');
  String get passwordUpdated => _t('passwordUpdated');
  String get passwordUpdatedMessage => _t('passwordUpdatedMessage');
  String get invalidResetLink => _t('invalidResetLink');
  String get backToLogin => _t('backToLogin');
  String get authUnavailable => _t('authUnavailable');
  String get signInHint => _t('signInHint');
  String get signInToContinue => _t('signInToContinue');
  String get signInRequiredForBooking =>
      _t('signInRequiredForBooking');
  String get orDivider => _t('orDivider');
  String get createProfile => _t('createProfile');
  String get quickBookingMode => _t('quickBookingMode');
  String get bookingDisabledForCategory => _t('bookingDisabledForCategory');
  String get availabilityDisabledForCategory =>
      _t('availabilityDisabledForCategory');
  String get notAnOwner => _t('notAnOwner');
  String get registerAsOwnerHint => _t('registerAsOwnerHint');
  String get instituteOwnerPortal => _t('instituteOwnerPortal');
  String get createInstitute => _t('createInstitute');
  String get addClass => _t('addClass');
  String get addFaculty => _t('addFaculty');
  String get plans => _t('plans');
  String get faculty => _t('faculty');
  String get classes => _t('classes');
  String get verifiedInstitute => _t('verifiedInstitute');
  String get noGalleryYet => _t('noGalleryYet');
  String get facultyPlaceholder => _t('facultyPlaceholder');
  String get noPublishedClasses => _t('noPublishedClasses');
  String get saveDraft => _t('saveDraft');
  String get allFilters => _t('allFilters');
  String get verifiedResults => _t('verifiedResults');
  String get recommended => _t('recommended');
  String get clearDate => _t('clearDate');
  String get clearDates => _t('clearDates');
  String get add => _t('add');
  String get filtersHint => _t('filtersHint');
  String otpSentResendIn(int seconds) =>
      _t('otpSentResendIn').replaceFirst('{seconds}', '$seconds');
  String otpResendIn(int seconds) =>
      _t('otpResendIn').replaceFirst('{seconds}', '$seconds');
  String get qrCheckIn => _t('qrCheckIn');
  String get locationSubmissions => _t('locationSubmissions');
  String get institutePortal => _t('institutePortal');
  String get noInstituteProfile => _t('noInstituteProfile');
  String get createInstituteHint => _t('createInstituteHint');
  String get editInstitute => _t('editInstitute');
  String get description => _t('description');
  String get city => _t('city');
  String get specialization => _t('specialization');
  String get classTitle => _t('classTitle');
  String get fee => _t('fee');
  String get deliveryMode => _t('deliveryMode');
  String get classesAndCourses => _t('classesAndCourses');
  String get hotels => _t('hotels');
  String get functionHalls => _t('functionHalls');
  String inArea(String title, String area) =>
      _t('inArea').replaceFirst('{title}', title).replaceFirst('{area}', area);
  String verifiedResultsCount(int count) =>
      _t('verifiedResultsCount').replaceFirst('{count}', '$count');
  String get priceLow => _t('priceLow');
  String get priceHigh => _t('priceHigh');
  String fieldsRequired(String fields) =>
      _t('fieldsRequired').replaceFirst('{fields}', fields);
  String get verified => _t('verified');
  String get unverified => _t('unverified');
  String get justNow => _t('justNow');
  String minutesAgo(int count) =>
      _t('minutesAgo').replaceFirst('{count}', '$count');
  String hoursAgo(int count) =>
      _t('hoursAgo').replaceFirst('{count}', '$count');
  String daysAgo(int count) => _t('daysAgo').replaceFirst('{count}', '$count');
  String get noActiveAdvertisingPlan => _t('noActiveAdvertisingPlan');
  String listingActiveUntil(String date) =>
      _t('listingActiveUntil').replaceFirst('{date}', date);
  String get plansPaymentHint => _t('plansPaymentHint');

  // Owner
  String get ownerDashboard => _t('ownerDashboard');
  String get myVenues => _t('myVenues');
  String get createVenue => _t('createVenue');
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
  String get analytics => _t('analytics');
  String get support => _t('support');
  String get auditLog => _t('auditLog');
  String get priority => _t('priority');
  String get noNotifications => _t('noNotifications');
  String get noNotificationsMessage => _t('noNotificationsMessage');
  String get markAllRead => _t('markAllRead');
  String get unread => _t('unread');
  String get noAnalyticsData => _t('noAnalyticsData');
  String get noSupportTickets => _t('noSupportTickets');
  String get newTicket => _t('newTicket');
  String get resolved => _t('resolved');
  String get open => _t('open');
  String get inProgress => _t('inProgress');
  String get closed => _t('closed');
  String get adminReply => _t('adminReply');
  String get noAdminReply => _t('noAdminReply');
  String get ticketCreated => _t('ticketCreated');
  String get ticketUpdated => _t('ticketUpdated');
  String get admin => _t('admin');
  String get noAuditLogs => _t('noAuditLogs');
  String get privacyPolicy => _t('privacyPolicy');
  String get termsAndConditions => _t('termsAndConditions');
  String get deleteAccount => _t('deleteAccount');
  String get about => _t('about');

  // Errors
  String get errorNoInternet => _t('errorNoInternet');
  String get errorInvalidEmail => _t('errorInvalidEmail');
  String get errorInvalidPhone => _t('errorInvalidPhone');
  String get errorRequired => _t('errorRequired');
  String get errorInvalidAmount => _t('errorInvalidAmount');

  String _t(String key) =>
      _translations[locale.languageCode]?[key] ??
      _translations['en']?[key] ??
      key;

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
      'navMap': 'Map',
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
      'saveVenue': 'Save venue',
      'savedVenues': 'Saved venues',
      'noSavedVenues': 'No saved venues yet',
      'noSavedVenuesMessage': 'Tap the heart on any venue to keep it here.',
      'filters': 'Filters',
      'clearFilters': 'Clear all',
      'sortBy': 'Sort by',
      'relevance': 'Relevance',
      'priceLowToHigh': 'Price: low to high',
      'priceHighToLow': 'Price: high to low',
      'topRated': 'Top rated',
      'minPrice': 'Min price',
      'maxPrice': 'Max price',
      'allCategories': 'All categories',
      'apply': 'Apply',
      'nearest': 'Nearest',
      'useMyLocation': 'Use my location',
      'resultsCount': '{count} venues found',
      'aboutThisVenue': 'About this venue',
      'details': 'Details',
      'address': 'Address',
      'openNow': 'Open now',
      'closedNow': 'Closed',
      'foodOptions': 'Food options',
      'rules': 'House rules',
      'parking': 'Parking',
      'taxRate': 'GST',
      'basePrice': 'Base price',
      'discount': 'Discount',
      'viewOnMap': 'View on map',
      'gallery': 'Gallery',
      'explore': 'Explore',
      'events': 'Events',
      'courses': 'Courses',
      'searchHint': 'Search venues, areas, categories…',
      'recentSearches': 'Recent searches',
      'clearRecentSearches': 'Clear all',
      'noRecentSearches': 'No recent searches',
      'servingCachedData': 'Showing saved data while you are offline',
      'holdExpired': 'This hold has expired. Pick the slot again.',
      'holdExpiresIn': 'Hold expires in {time}',
      'venueOptimizer': 'Venue Optimizer',
      'contextualHelp': 'Help',
      'upcomingEvents': 'Upcoming events',
      'noUpcomingEvents': 'No upcoming events',
      'noUpcomingEventsMessage':
          'New events will appear here as organisations publish them.',
      'freeEvent': 'Free',
      'registerNow': 'Register now',
      'registered': 'Registered',
      'seatsLeft': '{count} seats left',
      'soldOut': 'Sold out',
      'yourTicket': 'Your ticket',
      'cancelRegistration': 'Cancel registration',
      'cancelRegistrationConfirm':
          'Cancel your registration for this event? Your seat will be released.',
      'registrationCancelled': 'Registration cancelled',
      'searchEvents': 'Search events, venues, categories…',
      'allEvents': 'All',
      'paidEvent': 'Paid',
      'noCourses': 'No courses yet',
      'noCoursesMessage':
          'Courses from verified institutes will appear here when published.',
      'enrollNow': 'Enroll now',
      'enrolled': 'Enrolled',
      'enrollInCourse': 'Enroll in course',
      'courseFee': 'Course fee',
      'durationWeeks': '{weeks} weeks',
      'instructor': 'Instructor',
      'batchStartsOn': 'Starts',
      'modeOnline': 'Online',
      'modeOffline': 'Offline',
      'modeHybrid': 'Hybrid',
      'dropEnrollment': 'Drop enrollment',
      'dropEnrollmentConfirm':
          'Drop your enrollment in this batch? Your seat will be released.',
      'enrollmentDropped': 'Enrollment dropped',
      'searchCourses': 'Search courses, institutes, instructors…',
      'allModes': 'All',
      'demoSession': 'Demo',
      'paidCourse': 'Paid',
      'searchInstitutes': 'Search institutes and classes…',
      'institutesAndClasses': 'Institutes & Classes',
      'noInstitutes': 'No institutes yet',
      'noInstitutesMessage':
          'Verified institutes appear here when owners publish them.',
      'verifiedOnly': 'Verified only',
      'unifiedRegistration': 'Unified registration',
      'unifiedRegistrationHint':
          'One registration entry for every module. Fields come from admin-configured forms in Supabase, not from a local field list.',
      'selectDate': 'Select a date',
      'selectTimeSlot': 'Select a time slot',
      'availability': 'Availability',
      'confirmBooking': 'Confirm booking',
      'bookingSummary': 'Booking summary',
      'bookingDetails': 'Your details for this booking',
      'eventType': 'Event type (wedding, birthday, meeting…)',
      'guestName': 'Guest name',
      'tenantName': 'Tenant name',
      'idNumber': 'ID number (Aadhaar / Passport)',
      'payment': 'Payment',
      'payNow': 'Pay now',
      'paymentMethod': 'Payment method',
      'payAtVenue': 'Pay at venue',
      'bookAgain': 'Book again',
      'paymentSuccess': 'Payment successful',
      'paymentFailed': 'Payment failed',
      'paymentPending': 'Payment pending',
      'paymentCancelled': 'Payment was cancelled. You can try again.',
      'verifyingPayment': 'Verifying your payment…',
      'paymentPendingMessage':
          'Payment received. We are confirming your booking.',
      'requestRefund': 'Request refund',
      'requestRefundConfirm':
          'Request a full refund for this booking? This cannot be undone.',
      'refundRequested': 'Refund requested — it will be processed shortly.',
      'myBookings': 'My bookings',
      'noSlotsForDate': 'No slots available on this date',
      'total': 'Total',
      'promoCode': 'Promo code',
      'promoCodeHint': 'Enter promo code',
      'promoCodeApplied': 'Promo applied',
      'remove': 'Remove',
      'bookingConfirmed': 'Booking confirmed —',
      'bookingSuccessTitle': 'Booking Confirmed!',
      'copy': 'Copy',
      'copiedToClipboard': 'Copied to clipboard',
      'exploreMoreSpaces': 'Explore more spaces',
      'noBookings': 'No bookings yet',
      'noBookingsMessage': 'When you book a venue, it will show up here.',
      'cancelBooking': 'Cancel booking',
      'cancelBookingConfirm': 'Are you sure you want to cancel this booking?',
      'keep': 'Keep booking',
      'invoice': 'Invoice',
      'viewInvoice': 'View invoice',
      'invoiceFor': 'Booking invoice',
      'invoiceEmailQueued':
          'Invoice email queued to your account email. Delivery is handled by the server outbox, not by this device.',
      'invoiceEmailNotQueued':
          'No account email is on file, so nothing was queued. Download the PDF instead.',
      'bookingRef': 'Booking reference',
      'bookingStatus': 'Status',
      'dateOfBooking': 'Booking date',
      'customer': 'Customer',
      'guestCount': 'Guests',
      'checkIn': 'Check-in',
      'checkOut': 'Check-out',
      'moveIn': 'Move-in',
      'sharingOption': 'Sharing option',
      'rent': 'Rent',
      'deposit': 'Deposit',
      'changeSharing': 'Change sharing',
      'monthlyRentCalculator': 'Monthly rent calculator',
      'selectRoomSharing': 'Select room sharing',
      'stayDuration': 'Stay duration',
      'perMonth': '/mo',
      'monthlyPayable': 'Monthly payable',
      'refundableSecurityDeposit': 'Refundable security deposit',
      'estimatedTotalMoveIn': 'Estimated total move-in payable',
      'monthCount': '{count} month',
      'monthsCount': '{count} months',
      'totalRentForTenure': 'Total rent ({count} mo)',
      'maintenanceCharges': 'Maintenance ({count} mo)',
      'slotHeld': 'Slot held for 10 minutes. Complete the payment to confirm.',
      'payMethod': 'Payment method',
      'onlinePayment': 'Online (Razorpay)',
      'offlinePayment': 'Offline (walk-in)',
      'paidOn': 'Paid on',
      'paymentRef': 'Payment reference',
      'paymentHistory': 'Payment history',
      'noPaymentHistory': 'No completed payments',
      'noPaymentHistoryMessage':
          'Your successful transactions will appear here.',
      'transactionSummary': 'Transaction summary',
      'razorpayTransactionId': 'Razorpay transaction ID',
      'razorpayOrderId': 'Razorpay order ID',
      'bookingId': 'Booking ID',
      'walkIn': 'Walk-in',
      'statusHeld': 'Held',
      'statusPending': 'Pending',
      'statusConfirmed': 'Confirmed',
      'statusCompleted': 'Completed',
      'statusCancelled': 'Cancelled',
      'statusRefunded': 'Refunded',
      'statusNoShow': 'No show',
      'statusPendingOwnerApproval': 'Awaiting approval',
      'statusRejected': 'Rejected',
      'slotBooked': 'Booked',
      'slotUnavailable': 'Unavailable',
      'slotBlocked': 'Blocked',
      'slotClosed': 'Closed',
      'listingOnly': 'Listing only',
      'listingOnlyMessage':
          'Institutes and classes are advertising listings. Use Call or WhatsApp from the details page.',
      'call': 'Call',
      'whatsapp': 'WhatsApp',
      'callingVenue': 'Calling {name}…',
      'openingWhatsApp': 'Opening WhatsApp for {name}…',
      'digitalEntryPass': 'Digital Entry Pass',
      'viewEntryPass': 'View Entry Pass / QR',
      'entryPassHint':
          'Show this QR pass at the venue entrance gate for instant check-in verification.',
      'openInGoogleMaps': 'Open in Google Maps',
      'ownerBookings': 'Owner bookings',
      'newOfflineBooking': 'New offline booking',
      'offlineBooking': 'Offline booking',
      'createOfflineBooking': 'Create offline booking',
      'customerName': 'Customer name',
      'customerPhone': 'Customer phone',
      'selectVenue': 'Select venue',
      'noOwnerBookings': 'No bookings for your venues yet',
      'noOwnerVenuesMessage':
          'You need at least one venue before managing bookings.',
      'completeBooking': 'Mark completed',
      'markNoShow': 'Mark no-show',
      'approveBooking': 'Approve',
      'rejectBooking': 'Reject',
      'approveBookingConfirm':
          'Approve this booking? The customer will be notified and the booking confirmed.',
      'rejectBookingConfirm':
          "Reject this booking? If the customer paid online, a refund will be requested automatically.",
      'bookingApproved': 'Booking approved',
      'bookingRejected': 'Booking rejected',
      'bookingRejectedRefundRequested': 'Booking rejected. Refund requested.',
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
      'signInWithEmailOtp': 'Log in with email OTP',
      'signInWithPhoneOtp': 'Log in with phone OTP',
      'otpPlaceholder': '6-digit code',
      'verifyOtp': 'Verify & log in',
      'sendOtp': 'Send code',
      'resendOtp': 'Resend code',
      'otpSent': 'We sent you a verification code.',
      'forgotPassword': 'Forgot password?',
      'resetPassword': 'Reset password',
      'sendResetLink': 'Send reset link',
      'resetEmailPrompt':
          'Enter the email on your account. We will send a reset link if it exists.',
      'resetEmailSent': 'Check your email',
      'resetEmailSentMessage':
          'If an account exists for that address, a reset link is on its way. Open it on this device to choose a new password.',
      'resetPasswordPrompt': 'Choose a new password for your account.',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm password',
      'passwordsDoNotMatch': 'Passwords do not match',
      'passwordUpdated': 'Password updated',
      'passwordUpdatedMessage': 'Sign in with your new password to continue.',
      'invalidResetLink':
          'This reset link is invalid or has expired. Request a new one from the login screen.',
      'backToLogin': 'Back to login',
      'authUnavailable': 'Authentication is currently unavailable.',
      'signInHint':
          'Sign in with email or phone. Extra details are asked only when you book.',
      'signInToContinue': 'Sign in to continue',
      'signInRequiredForBooking':
          'Sign in required to confirm this booking. Your selections are saved.',
      'orDivider': 'OR',
      'createProfile': 'Create a profile',
      'quickBookingMode': 'Quick booking mode',
      'bookingDisabledForCategory': 'Booking is disabled for this category',
      'availabilityDisabledForCategory':
          'Availability is disabled for this category',
      'notAnOwner': 'Not an owner',
      'registerAsOwnerHint': 'Register as an owner to access the dashboard.',
      'instituteOwnerPortal': 'Institute owner portal',
      'createInstitute': 'Create institute',
      'addClass': 'Add class',
      'addFaculty': 'Add faculty',
      'plans': 'Plans',
      'faculty': 'Faculty',
      'classes': 'Classes',
      'verifiedInstitute': 'Verified institute',
      'noGalleryYet': 'No gallery images yet.',
      'facultyPlaceholder': 'Faculty profiles will appear here.',
      'noPublishedClasses': 'No published classes yet.',
      'saveDraft': 'Save draft',
      'allFilters': 'All filters',
      'verifiedResults': 'verified results',
      'recommended': 'Recommended',
      'clearDate': 'Clear date',
      'clearDates': 'Clear dates',
      'add': 'Add',
      'filtersHint': 'Location, price, rating, capacity and amenities',
      'otpSentResendIn': 'A verification code was sent. Resend in {seconds}s',
      'otpResendIn': 'Resend in {seconds}s',
      'qrCheckIn': 'QR check-in',
      'locationSubmissions': 'Location submissions',
      'institutePortal': 'Institute portal',
      'noInstituteProfile': 'No institute profile',
      'createInstituteHint':
          'Create an institute to publish classes, faculty and a gallery.',
      'editInstitute': 'Edit institute',
      'description': 'Description',
      'city': 'City',
      'specialization': 'Specialization',
      'classTitle': 'Title',
      'fee': 'Fee',
      'deliveryMode': 'Delivery mode',
      'classesAndCourses': 'Classes & courses',
      'hotels': 'Hotels',
      'functionHalls': 'Function Halls',
      'inArea': '{title} in {area}',
      'verifiedResultsCount': '{count} verified results',
      'priceLow': 'Price: low',
      'priceHigh': 'Price: high',
      'fieldsRequired': 'Need: {fields}',
      'verified': 'Verified',
      'unverified': 'Unverified',
      'justNow': 'now',
      'minutesAgo': '{count}m ago',
      'hoursAgo': '{count}h ago',
      'daysAgo': '{count}d ago',
      'noActiveAdvertisingPlan': 'No active advertising plan',
      'listingActiveUntil': 'Listing active until {date}',
      'plansPaymentHint':
          'Plans are purchased through the existing payment flow.',
      'authFailed': 'Authentication failed. Please try again.',
      'ownerDashboard': 'Owner dashboard',
      'myVenues': 'My Venues',
      'createVenue': 'Create Venue',
      'ownerVenues': 'Owner Venues',
      'ownerRequests': 'Booking requests',
      'ownerCalendar': 'Calendar',
      'earnings': 'Earnings',
      'addVenue': 'Add venue',
      'settings': 'Settings',
      'language': 'Language',
      'themeMode': 'Theme',
      'notifications': 'Notifications',
      'analytics': 'Analytics',
      'support': 'Support',
      'auditLog': 'Audit Log',
      'priority': 'Priority',
      'noNotifications': 'No notifications',
      'noNotificationsMessage':
          'You will see notifications here when they arrive.',
      'markAllRead': 'Mark all read',
      'unread': 'Unread',
      'noAnalyticsData': 'No analytics data',
      'noSupportTickets': 'No support tickets',
      'newTicket': 'New Ticket',
      'resolved': 'Resolved',
      'open': 'Open',
      'inProgress': 'In Progress',
      'closed': 'Closed',
      'adminReply': 'Admin Reply',
      'noAdminReply': 'No admin reply yet',
      'ticketCreated': 'Ticket created',
      'ticketUpdated': 'Ticket updated',
      'admin': 'Admin',
      'noAuditLogs': 'No audit logs',
      'privacyPolicy': 'Privacy policy',
      'termsAndConditions': 'Terms & conditions',
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
      'saveVenue': 'వేదికను సేవ్ చేయండి',
      'savedVenues': 'సేవ్ చేసిన వేదికలు',
      'noSavedVenues': 'ఇంకా సేవ్ చేసిన వేదికలు లేవు',
      'noSavedVenuesMessage':
          'ఏదైనా వేదికపై హార్ట్‌పై నొక్కితే ఇక్కడ కనిపిస్తుంది.',
      'filters': 'ఫిల్టర్లు',
      'clearFilters': 'అన్నీ క్లియర్ చేయండి',
      'sortBy': 'క్రమబద్ధీకరించండి',
      'relevance': 'ఔచిత్యం',
      'priceLowToHigh': 'ధర: తక్కువ నుండి ఎక్కువ',
      'priceHighToLow': 'ధర: ఎక్కువ నుండి తక్కువ',
      'topRated': 'అత్యధిక రేటింగ్',
      'minPrice': 'కనిష్ట ధర',
      'maxPrice': 'గరిష్ట ధర',
      'allCategories': 'అన్ని వర్గాలు',
      'apply': 'వర్తించు',
      'nearest': 'దగ్గరి',
      'useMyLocation': 'నా లొకేషన్ ఉపయోగించండి',
      'resultsCount': '{count} వేదికలు దొరికాయి',
      'aboutThisVenue': 'ఈ వేదిక గురించి',
      'details': 'వివరాలు',
      'address': 'చిరునామా',
      'openNow': 'ఇప్పుడు తెరిచి ఉంది',
      'closedNow': 'మూసివేయబడింది',
      'foodOptions': 'ఆహార ఎంపికలు',
      'rules': 'నిబంధనలు',
      'parking': 'పార్కింగ్',
      'taxRate': 'GST',
      'basePrice': 'ప్రాథమిక ధర',
      'discount': 'తగ్గింపు',
      'viewOnMap': 'మ్యాప్‌లో చూడండి',
      'gallery': 'గ్యాలరీ',
      'explore': 'అన్వేషించండి',
      'events': 'ఈవెంట్స్',
      'courses': 'కోర్సులు',
      'searchHint': 'వేదికలు, ప్రాంతాలు, వర్గాలను వెతకండి…',
      'upcomingEvents': 'రాబోయే ఈవెంట్స్',
      'noUpcomingEvents': 'రాబోయే ఈవెంట్స్ లేవు',
      'noUpcomingEventsMessage':
          'సంస్థలు ప్రచురించిన కొత్త ఈవెంట్స్ ఇక్కడ కనిపిస్తాయి.',
      'freeEvent': 'ఉచితం',
      'registerNow': 'ఇప్పుడే నమోదు చేయండి',
      'registered': 'నమోదు చేయబడింది',
      'seatsLeft': '{count} సీట్లు మిగిలి ఉన్నాయి',
      'soldOut': 'అన్నీ అమ్ముడయ్యాయి',
      'yourTicket': 'మీ టికెట్',
      'cancelRegistration': 'నమోదు రద్దు చేయండి',
      'cancelRegistrationConfirm':
          'ఈ ఈవెంట్‌కు మీ నమోదును రద్దు చేయాలా? మీ సీటు విడుదల అవుతుంది.',
      'registrationCancelled': 'నమోదు రద్దు చేయబడింది',
      'searchEvents': 'ఈవెంట్లు, వేదికలు, వర్గాలు శోధించండి…',
      'allEvents': 'అన్నీ',
      'paidEvent': 'చెల్లింపు',
      'noCourses': 'ఇంకా కోర్సులు లేవు',
      'noCoursesMessage':
          'ధృవీకరించబడిన సంస్థల నుండి కోర్సులు ప్రచురించినప్పుడు ఇక్కడ కనిపిస్తాయి.',
      'enrollNow': 'ఇప్పుడే చేరండి',
      'enrolled': 'చేరారు',
      'enrollInCourse': 'కోర్సులో చేరండి',
      'courseFee': 'కోర్సు ఫీజు',
      'durationWeeks': '{weeks} వారాలు',
      'instructor': 'బోధకుడు',
      'batchStartsOn': 'ప్రారంభం',
      'modeOnline': 'ఆన్‌లైన్',
      'modeOffline': 'ఆఫ్‌లైన్',
      'modeHybrid': 'హైబ్రిడ్',
      'dropEnrollment': 'చేరికను వదిలివేయండి',
      'dropEnrollmentConfirm':
          'ఈ బ్యాచ్‌లో మీ చేరికను వదిలివేయాలా? మీ సీటు విడుదల అవుతుంది.',
      'enrollmentDropped': 'చేరిక విడిచిపెట్టబడింది',
      'searchCourses': 'కోర్సులు, సంస్థలు, బోధకులు శోధించండి…',
      'allModes': 'అన్నీ',
      'demoSession': 'డెమో',
      'paidCourse': 'చెల్లింపు',
      'searchInstitutes': 'సంస్థలు మరియు తరగతులు శోధించండి…',
      'institutesAndClasses': 'సంస్థలు & తరగతులు',
      'noInstitutes': 'ఇంకా సంస్థలు లేవు',
      'noInstitutesMessage':
          'యజమానులు ప్రచురించినప్పుడు ధృవీకరించిన సంస్థలు ఇక్కడ కనిపిస్తాయి.',
      'verifiedOnly': 'ధృవీకరించినవి మాత్రమే',
      'unifiedRegistration': 'ఏకీకృత నమోదు',
      'unifiedRegistrationHint':
          'ప్రతి మాడ్యూల్‌కు ఒక నమోదు ప్రవేశం. ఫీల్డ్‌లు స్థానిక జాబితా నుండి కాకుండా సుపాబేస్‌లోని నిర్వాహక ఫారమ్‌ల నుండి వస్తాయి.',
      'selectDate': 'తేదీని ఎంచుకోండి',
      'selectTimeSlot': 'టైమ్ స్లాట్ ఎంచుకోండి',
      'availability': 'అందుబాటు',
      'confirmBooking': 'బుకింగ్ నిర్ధారించండి',
      'bookingSummary': 'బుకింగ్ సారాంశం',
      'bookingDetails': 'ఈ బుకింగ్ కోసం మీ వివరాలు',
      'eventType': 'ఈవెంట్ రకం',
      'guestName': 'అతిథి పేరు',
      'tenantName': 'అద్దెదారు పేరు',
      'idNumber': 'ఐడి నంబర్ (ఆధార్ / పాస్‌పోర్ట్)',
      'payment': 'చెల్లింపు',
      'payNow': 'ఇప్పుడే చెల్లించండి',
      'paymentMethod': 'చెల్లింపు విధానం',
      'payAtVenue': 'వేదిక వద్ద చెల్లించండి',
      'bookAgain': 'మళ్లీ బుక్ చేయండి',
      'paymentSuccess': 'చెల్లింపు విజయవంతమైంది',
      'paymentFailed': 'చెల్లింపు విఫలమైంది',
      'paymentPending': 'చెల్లింపు పెండింగ్‌లో ఉంది',
      'paymentCancelled':
          'చెల్లింపు రద్దు చేయబడింది. మీరు మళ్లీ ప్రయత్నించవచ్చు.',
      'verifyingPayment': 'మీ చెల్లింపు ధృవీకరిస్తోంది…',
      'paymentPendingMessage':
          'చెల్లింపు అందింది. మీ బుకింగ్‌ను నిర్ధారిస్తున్నాము.',
      'requestRefund': 'వాపసు అభ్యర్థించండి',
      'requestRefundConfirm':
          'ఈ బుకింగ్‌కు పూర్తి వాపసు అభ్యర్థించాలా? దీన్ని రద్దు చేయలేము.',
      'refundRequested':
          'వాపసు అభ్యర్థించబడింది — త్వరలో ప్రాసెస్ చేయబడుతుంది.',
      'myBookings': 'నా బుకింగ్స్',
      'noSlotsForDate': 'ఈ తేదీన స్లాట్‌లు అందుబాటులో లేవు',
      'total': 'మొత్తం',
      'promoCode': 'ప్రోమో కోడ్',
      'promoCodeHint': 'ప్రోమో కోడ్ నమోదు చేయండి',
      'promoCodeApplied': 'ప్రోమో వర్తించబడింది',
      'remove': 'తీసివేయి',
      'bookingConfirmed': 'బుకింగ్ నిర్ధారించబడింది —',
      'noBookings': 'ఇంకా బుకింగ్స్ లేవు',
      'noBookingsMessage':
          'మీరు వేదికను బుక్ చేసినప్పుడు అది ఇక్కడ కనిపిస్తుంది.',
      'cancelBooking': 'బుకింగ్ రద్దు చేయండి',
      'cancelBookingConfirm': 'మీరు ఈ బుకింగ్‌ను రద్దు చేయాలనుకుంటున్నారా?',
      'keep': 'బుకింగ్ ఉంచండి',
      'invoice': 'ఇన్వాయిస్',
      'viewInvoice': 'ఇన్వాయిస్ చూడండి',
      'invoiceFor': 'బుకింగ్ ఇన్వాయిస్',
      'invoiceEmailQueued':
          'మీ ఖాతా ఇమెయిల్‌కు ఇన్వాయిస్ ఇమెయిల్ క్యూ చేయబడింది. డెలివరీ సర్వర్ అవుట్‌బాక్స్ నిర్వహిస్తుంది.',
      'invoiceEmailNotQueued':
          'ఖాతా ఇమెయిల్ లేదు, కాబట్టి ఏమీ క్యూ కాలేదు. PDF డౌన్‌లోడ్ చేయండి.',
      'bookingRef': 'బుకింగ్ రిఫరెన్స్',
      'bookingStatus': 'స్థితి',
      'dateOfBooking': 'బుకింగ్ తేదీ',
      'customer': 'కస్టమర్',
      'guestCount': 'అతిథులు',
      'checkIn': 'చెక్-ఇన్',
      'checkOut': 'చెక్-అవుట్',
      'moveIn': 'మూవ్-ఇన్',
      'sharingOption': 'షేరింగ్ ఎంపిక',
      'rent': 'అద్దె',
      'deposit': 'డిపాజిట్',
      'changeSharing': 'షేరింగ్ మార్చండి',
      'monthlyRentCalculator': 'నెలవారీ అద్దె కాలిక్యులేటర్',
      'selectRoomSharing': 'రూమ్ షేరింగ్ ఎంచుకోండి',
      'stayDuration': 'బస వ్యవధి',
      'perMonth': '/నెల',
      'monthlyPayable': 'నెలవారీ చెల్లింపు',
      'refundableSecurityDeposit': 'వాపసు అయ్యే డిపాజిట్',
      'estimatedTotalMoveIn': 'అంచనా మూవ్-ఇన్ మొత్తం',
      'monthCount': '{count} నెల',
      'monthsCount': '{count} నెలలు',
      'totalRentForTenure': 'మొత్తం అద్దె ({count} నెల)',
      'maintenanceCharges': 'నిర్వహణ ({count} నెల)',
      'slotHeld':
          'స్లాట్ 10 నిమిషాలు రిజర్వ్ చేయబడింది. నిర్ధారించడానికి చెల్లించండి.',
      'payMethod': 'చెల్లింపు విధానం',
      'onlinePayment': 'ఆన్‌లైన్ (Razorpay)',
      'offlinePayment': 'ఆఫ్‌లైన్ (వాక్-ఇన్)',
      'paidOn': 'చెల్లించిన తేదీ',
      'paymentRef': 'చెల్లింపు రిఫరెన్స్',
      'paymentHistory': 'చెల్లింపు చరిత్ర',
      'noPaymentHistory': 'పూర్తయిన చెల్లింపులు లేవు',
      'noPaymentHistoryMessage': 'మీ విజయవంతమైన లావాదేవీలు ఇక్కడ కనిపిస్తాయి.',
      'transactionSummary': 'లావాదేవీ సారాంశం',
      'razorpayTransactionId': 'రేజర్‌పే లావాదేవీ ID',
      'razorpayOrderId': 'రేజర్‌పే ఆర్డర్ ID',
      'bookingId': 'బుకింగ్ ID',
      'walkIn': 'వాక్-ఇన్',
      'statusHeld': 'రిజర్వ్ చేయబడింది',
      'statusPending': 'పెండింగ్',
      'statusConfirmed': 'నిర్ధారించబడింది',
      'statusCompleted': 'పూర్తయింది',
      'statusCancelled': 'రద్దు చేయబడింది',
      'statusRefunded': 'వాపసు చేయబడింది',
      'statusNoShow': 'నో-షో',
      'statusPendingOwnerApproval': 'ఆమోదం కోసం వేచి ఉంది',
      'statusRejected': 'తిరస్కరించబడింది',
      'slotBooked': 'బుక్ చేయబడింది',
      'slotUnavailable': 'అందుబాటులో లేదు',
      'slotBlocked': 'బ్లాక్ చేయబడింది',
      'slotClosed': 'మూసివేయబడింది',
      'listingOnly': 'లిస్టింగ్ మాత్రమే',
      'listingOnlyMessage':
          'ఇన్‌స్టిట్యూట్లు మరియు క్లాసులు ప్రకటనల లిస్టింగ్‌లు. వివరాల పేజీ నుండి కాల్ లేదా వాట్సాప్ ఉపయోగించండి.',
      'call': 'కాల్',
      'whatsapp': 'వాట్సాప్',
      'callingVenue': '{name} కు కాల్ చేస్తోంది…',
      'openingWhatsApp': '{name} కోసం వాట్సాప్ తెరుస్తోంది…',
      'digitalEntryPass': 'డిజిటల్ ఎంట్రీ పాస్',
      'viewEntryPass': 'ఎంట్రీ పాస్ / QR చూడండి',
      'entryPassHint':
          'తక్షణ చెక్-ఇన్ ధృవీకరణ కోసం వేదిక ప్రవేశ ద్వారం వద్ద ఈ QR పాస్ చూపించండి.',
      'openInGoogleMaps': 'Google మ్యాప్స్‌లో తెరవండి',
      'ownerBookings': 'యజమాని బుకింగ్స్',
      'newOfflineBooking': 'కొత్త ఆఫ్‌లైన్ బుకింగ్',
      'offlineBooking': 'ఆఫ్‌లైన్ బుకింగ్',
      'createOfflineBooking': 'ఆఫ్‌లైన్ బుకింగ్ సృష్టించండి',
      'customerName': 'కస్టమర్ పేరు',
      'customerPhone': 'కస్టమర్ ఫోన్',
      'selectVenue': 'వేదికను ఎంచుకోండి',
      'noOwnerBookings': 'మీ వేదికలకు ఇంకా బుకింగ్స్ లేవు',
      'noOwnerVenuesMessage':
          'బుకింగ్స్ నిర్వహించడానికి మీకు కనీసం ఒక వేదిక అవసరం.',
      'completeBooking': 'పూర్తి చేసినట్లు గుర్తించండి',
      'markNoShow': 'నో-షో గుర్తించండి',
      'approveBooking': 'ఆమోదించండి',
      'rejectBooking': 'తిరస్కరించండి',
      'approveBookingConfirm':
          'ఈ బుకింగ్‌ను ఆమోదించాలా? కస్టమర్‌కు తెలియజేయబడుతుంది మరియు బుకింగ్ నిర్ధారించబడుతుంది.',
      'rejectBookingConfirm':
          'ఈ బుకింగ్‌ను తిరస్కరించాలా? కస్టమర్ ఆన్‌లైన్‌లో చెల్లించి ఉంటే, రీఫండ్ స్వయంచాలకంగా అభ్యర్థించబడుతుంది.',
      'bookingApproved': 'బుకింగ్ ఆమోదించబడింది',
      'bookingRejected': 'బుకింగ్ తిరస్కరించబడింది',
      'bookingRejectedRefundRequested':
          'బుకింగ్ తిరస్కరించబడింది. రీఫండ్ అభ్యర్థించబడింది.',
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
      'signInWithEmailOtp': 'ఇమెయిల్ OTP తో లాగిన్ అవ్వండి',
      'signInWithPhoneOtp': 'ఫోన్ OTP తో లాగిన్ అవ్వండి',
      'otpPlaceholder': '6 అంకెల కోడ్',
      'verifyOtp': 'ధృవీకరించి లాగిన్ అవ్వండి',
      'sendOtp': 'కోడ్ పంపండి',
      'resendOtp': 'కోడ్ మళ్లీ పంపండి',
      'otpSent': 'మేము మీకు ధృవీకరణ కోడ్ పంపాము.',
      'authFailed': 'ప్రమాణీకరణ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.',
      'ownerDashboard': 'యజమాని డాష్‌బోర్డ్',
      'myVenues': 'నా వేదికలు',
      'createVenue': 'వేదికను సృష్టించండి',
      'ownerVenues': 'యజమాని వేదికలు',
      'ownerRequests': 'బుకింగ్ అభ్యర్థనలు',
      'ownerCalendar': 'క్యాలెండర్',
      'earnings': 'ఆదాయాలు',
      'addVenue': 'వేదికను జోడించండి',
      'settings': 'సెట్టింగ్స్',
      'language': 'భాష',
      'themeMode': 'థీమ్',
      'notifications': 'నోటిఫికేషన్లు',
      'analytics': 'విశ్లేషణ',
      'support': 'సహాయం',
      'auditLog': 'ఆడిట్ లాగ్',
      'priority': 'ప్రాధాన్యత',
      'noNotifications': 'నోటిఫికేషన్లు లేవు',
      'noNotificationsMessage': 'నోటిఫికేషన్లు వచ్చినప్పుడు ఇక్కడ కనిపిస్తాయి.',
      'markAllRead': 'అన్నీ చదివినట్లు గుర్తించండి',
      'unread': 'చదలపడలేదు',
      'noAnalyticsData': 'విశ్లేషణ డేటా లేదు',
      'noSupportTickets': 'సహాయ టికెట్లు లేవు',
      'newTicket': 'కొత్త టికెట్',
      'resolved': 'పరిష్కరించబడింది',
      'open': 'తెరగింది',
      'inProgress': 'ప్రక్రియలో',
      'closed': 'మూసివేయబడింది',
      'adminReply': 'నిర్వాహక స్పందన',
      'noAdminReply': 'ఇంకా నిర్వాహక స్పందన లేదు',
      'ticketCreated': 'టికెట్ సృష్టించబడింది',
      'ticketUpdated': 'టికెట్ నవీకరించబడింది',
      'admin': 'నిర్వాహకుడు',
      'noAuditLogs': 'ఆడిట్ లాగ్లు లేవు',
      'privacyPolicy': 'గోప్యతా విధానం',
      'termsAndConditions': 'నిబంధనలు & షరతులు',
      'deleteAccount': 'ఖాతాను తొలగించండి',
      'about': 'గురించి',
      'errorNoInternet': 'ఇంటర్నెట్ కనెక్షన్ లేదు',
      'errorInvalidEmail': 'చెల్లుబాటు అయ్యే ఇమెయిల్ నమోదు చేయండి',
      'errorInvalidPhone': 'చెల్లుబాటు అయ్యే ఫోన్ నంబర్ నమోదు చేయండి',
      'errorRequired': 'ఈ ఫీల్డ్ అవసరం',
      'errorInvalidAmount': 'చెల్లుబాటు అయ్యే మొత్తం నమోదు చేయండి',
      'authUnavailable': 'ప్రమాణీకరణ ప్రస్తుతం అందుబాటులో లేదు.',
      'signInHint':
          'ఇమెయిల్ లేదా ఫోన్‌తో సైన్ ఇన్ చేయండి. అదనపు వివరాలు మీరు బుక్ చేసినప్పుడు మాత్రమే అడుగుతాము.',
      'orDivider': 'లేదా',
      'createProfile': 'ప్రొఫైల్ సృష్టించండి',
      'quickBookingMode': 'క్విక్ బుకింగ్ మోడ్',
      'bookingDisabledForCategory': 'ఈ వర్గానికి బుకింగ్ నిలిపివేయబడింది',
      'availabilityDisabledForCategory': 'ఈ వర్గానికి అందుబాటు నిలిపివేయబడింది',
      'notAnOwner': 'యజమాని కాదు',
      'registerAsOwnerHint':
          'డాష్‌బోర్డ్‌ను యాక్సెస్ చేయడానికి యజమానిగా నమోదు చేసుకోండి.',
      'instituteOwnerPortal': 'ఇన్‌స్టిట్యూట్ యజమాని పోర్టల్',
      'createInstitute': 'ఇన్‌స్టిట్యూట్ సృష్టించండి',
      'addClass': 'క్లాస్ జోడించండి',
      'addFaculty': 'ఫ్యాకల్టీ జోడించండి',
      'plans': 'ప్లాన్లు',
      'faculty': 'ఫ్యాకల్టీ',
      'classes': 'క్లాసులు',
      'verifiedInstitute': 'ధృవీకరించబడిన ఇన్‌స్టిట్యూట్',
      'noGalleryYet': 'ఇంకా గ్యాలరీ చిత్రాలు లేవు.',
      'facultyPlaceholder': 'ఫ్యాకల్టీ ప్రొఫైల్స్ ఇక్కడ కనిపిస్తాయి.',
      'noPublishedClasses': 'ఇంకా ప్రచురించిన క్లాసులు లేవు.',
      'saveDraft': 'డ్రాఫ్ట్ సేవ్ చేయండి',
      'allFilters': 'అన్ని ఫిల్టర్లు',
      'verifiedResults': 'ధృవీకరించిన ఫలితాలు',
      'recommended': 'సిఫార్సు',
      'clearDate': 'తేదీ క్లియర్ చేయండి',
      'clearDates': 'తేదీలు క్లియర్ చేయండి',
      'add': 'జోడించండి',
      'filtersHint': 'ప్రాంతం, ధర, రేటింగ్, సామర్థ్యం మరియు సౌకర్యాలు',
      'otpSentResendIn': 'ధృవీకరణ కోడ్ పంపబడింది. {seconds}సెలో మళ్లీ పంపండి',
      'otpResendIn': '{seconds}సెలో మళ్లీ పంపండి',
      'qrCheckIn': 'QR చెక్-ఇన్',
      'locationSubmissions': 'లొకేషన్ సమర్పణలు',
      'institutePortal': 'ఇన్‌స్టిట్యూట్ పోర్టల్',
      'noInstituteProfile': 'ఇన్‌స్టిట్యూట్ ప్రొఫైల్ లేదు',
      'createInstituteHint':
          'క్లాసులు, ఫ్యాకల్టీ మరియు గ్యాలరీ ప్రచురించడానికి ఇన్‌స్టిట్యూట్ సృష్టించండి.',
      'editInstitute': 'ఇన్‌స్టిట్యూట్‌ను సవరించండి',
      'description': 'వివరణ',
      'city': 'నగరం',
      'specialization': 'ప్రత్యేకత',
      'classTitle': 'శీర్షిక',
      'fee': 'ఫీజు',
      'deliveryMode': 'డెలివరీ మోడ్',
      'classesAndCourses': 'క్లాసులు & కోర్సులు',
      'hotels': 'హోటళ్లు',
      'functionHalls': 'ఫంక్షన్ హాళ్లు',
      'inArea': '{area}లో {title}',
      'verifiedResultsCount': '{count} ధృవీకరించిన ఫలితాలు',
      'priceLow': 'ధర: తక్కువ',
      'priceHigh': 'ధర: ఎక్కువ',
      'fieldsRequired': 'అవసరం: {fields}',
      'verified': 'ధృవీకరించబడింది',
      'unverified': 'ధృవీకరించబడలేదు',
      'justNow': 'ఇప్పుడు',
      'minutesAgo': '{count}ని క్రితం',
      'hoursAgo': '{count}గం క్రితం',
      'daysAgo': '{count}రో క్రితం',
    },
    'hi': {
      'appName': 'बुकमाईस्पेस',
      'tagline': 'अपनी जगह खोजें और बुक करें',
      'retry': 'फिर कोशिश करें',
      'cancel': 'रद्द करें',
      'confirm': 'पुष्टि करें',
      'save': 'सहेजें',
      'search': 'खोजें',
      'loading': 'लोड हो रहा है…',
      'navHome': 'होम',
      'navSearch': 'खोज',
      'navBookings': 'बुकिंग',
      'navSaved': 'सेव्ड',
      'navProfile': 'प्रोफ़ाइल',
      'bookNow': 'अभी बुक करें',
      'nearbyVenues': 'नज़दीकी स्थान',
      'myBookings': 'मेरी बुकिंग',
      'login': 'लॉग इन',
      'logout': 'लॉग आउट',
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'notifications': 'सूचनाएँ',
      'ownerDashboard': 'मालिक डैशबोर्ड',
      'venues': 'स्थान',
      'payment': 'भुगतान',
      'payNow': 'अभी भुगतान करें',
      'paymentMethod': 'भुगतान का तरीका',
      'onlinePayment': 'ऑनलाइन भुगतान (Razorpay)',
      'payAtVenue': 'स्थान पर भुगतान करें',
      'confirmBooking': 'बुकिंग की पुष्टि करें',
      'bookAgain': 'फिर बुक करें',
      'checkIn': 'चेक-इन',
      'courses': 'कोर्स',
      'events': 'इवेंट्स',
      'support': 'सहायता',
      'admin': 'एडमिन',
      'searchEvents': 'इवेंट, स्थान, श्रेणियाँ खोजें…',
      'allEvents': 'सभी',
      'paidEvent': 'सशुल्क',
      'searchCourses': 'कोर्स, संस्थान, प्रशिक्षक खोजें…',
      'allModes': 'सभी',
      'demoSession': 'डेमो',
      'paidCourse': 'सशुल्क',
      'searchInstitutes': 'संस्थान और कक्षाएँ खोजें…',
      'institutesAndClasses': 'संस्थान और कक्षाएँ',
      'noInstitutes': 'अभी संस्थान नहीं हैं',
      'noInstitutesMessage':
          'मालिक प्रकाशित करने पर सत्यापित संस्थान यहाँ दिखते हैं।',
      'verifiedOnly': 'केवल सत्यापित',
      'unifiedRegistration': 'एकीकृत पंजीकरण',
      'unifiedRegistrationHint':
          'हर मॉड्यूल के लिए एक पंजीकरण प्रवेश। फ़ील्ड सुपाबेस में एडमिन फ़ॉर्म से आते हैं, स्थानीय सूची से नहीं।',
      'invoiceEmailQueued':
          'आपके खाता ईमेल पर इनवॉइस ईमेल कतार में है। डिलीवरी सर्वर आउटबॉक्स करता है।',
      'invoiceEmailNotQueued':
          'खाता ईमेल नहीं है, इसलिए कुछ कतार में नहीं गया। PDF डाउनलोड करें।',
      'viewOnMap': 'मानचित्र पर देखें',
      'noResults': 'कोई परिणाम नहीं',
      'noResultsMessage': 'फ़िल्टर या खोज शब्द बदलकर देखें।',
      'freeEvent': 'मुफ़्त',
      'modeOnline': 'ऑनलाइन',
      'modeOffline': 'ऑफ़लाइन',
      'modeHybrid': 'हाइब्रिड',
      'authUnavailable': 'प्रमाणीकरण अभी उपलब्ध नहीं है।',
      'signInHint':
          'ईमेल या फ़ोन से साइन इन करें। अतिरिक्त विवरण बुकिंग के समय ही मांगे जाते हैं।',
      'orDivider': 'या',
      'createProfile': 'प्रोफ़ाइल बनाएँ',
      'quickBookingMode': 'त्वरित बुकिंग मोड',
      'bookingDisabledForCategory': 'इस श्रेणी के लिए बुकिंग बंद है',
      'availabilityDisabledForCategory': 'इस श्रेणी के लिए उपलब्धता बंद है',
      'notAnOwner': 'मालिक नहीं हैं',
      'registerAsOwnerHint':
          'डैशबोर्ड इस्तेमाल करने के लिए मालिक के रूप में पंजीकरण करें।',
      'instituteOwnerPortal': 'संस्थान मालिक पोर्टल',
      'createInstitute': 'संस्थान बनाएँ',
      'addClass': 'कक्षा जोड़ें',
      'addFaculty': 'फैकल्टी जोड़ें',
      'plans': 'प्लान',
      'faculty': 'फैकल्टी',
      'classes': 'कक्षाएँ',
      'verifiedInstitute': 'सत्यापित संस्थान',
      'noGalleryYet': 'अभी गैलरी चित्र नहीं हैं।',
      'facultyPlaceholder': 'फैकल्टी प्रोफ़ाइल यहाँ दिखेंगी।',
      'noPublishedClasses': 'अभी प्रकाशित कक्षाएँ नहीं हैं।',
      'saveDraft': 'ड्राफ़्ट सहेजें',
      'allFilters': 'सभी फ़िल्टर',
      'verifiedResults': 'सत्यापित परिणाम',
      'recommended': 'अनुशंसित',
      'clearDate': 'तारीख हटाएँ',
      'clearDates': 'तारीखें हटाएँ',
      'add': 'जोड़ें',
      'filtersHint': 'स्थान, कीमत, रेटिंग, क्षमता और सुविधाएँ',
      'otpSentResendIn': 'सत्यापन कोड भेजा गया। {seconds}से में फिर भेजें',
      'otpResendIn': '{seconds}से में फिर भेजें',
      'qrCheckIn': 'QR चेक-इन',
      'locationSubmissions': 'स्थान सबमिशन',
      'institutePortal': 'संस्थान पोर्टल',
      'noInstituteProfile': 'संस्थान प्रोफ़ाइल नहीं',
      'createInstituteHint':
          'कक्षाएँ, फैकल्टी और गैलरी प्रकाशित करने के लिए संस्थान बनाएँ।',
      'editInstitute': 'संस्थान संपादित करें',
      'description': 'विवरण',
      'city': 'शहर',
      'specialization': 'विशेषज्ञता',
      'classTitle': 'शीर्षक',
      'fee': 'शुल्क',
      'deliveryMode': 'डिलीवरी मोड',
      'classesAndCourses': 'कक्षाएँ और कोर्स',
      'hotels': 'होटल',
      'functionHalls': 'फ़ंक्शन हॉल',
      'inArea': '{area} में {title}',
      'verifiedResultsCount': '{count} सत्यापित परिणाम',
      'priceLow': 'कीमत: कम',
      'priceHigh': 'कीमत: अधिक',
      'fieldsRequired': 'आवश्यक: {fields}',
      'verified': 'सत्यापित',
      'unverified': 'असत्यापित',
      'justNow': 'अभी',
      'minutesAgo': '{count}मि पहले',
      'hoursAgo': '{count}घं पहले',
      'daysAgo': '{count}दि पहले',
    },
    'ta': {
      'appName': 'புக் மை ஸ்பேஸ்',
      'searchHint': 'மண்டபம், பிஜி, ஹோட்டல் தேடுக...',
      'search': 'தேடல்',
      'bookNow': 'இப்போது முன்பதிவு செய்',
      'cancel': 'ரத்துசெய்',
      'confirm': 'உறுதிசெய்',
      'save': 'சேமி',
      'navHome': 'முகப்பு',
      'navSearch': 'தேடல்',
      'navBookings': 'என் பதிவுகள்',
      'navSaved': 'சேமித்தவை',
      'navProfile': 'சுயவிவரம்',
      'reviews': 'விமர்சனங்கள்',
      'amenities': 'வசதிகள்',
      'capacity': 'கொள்திறன்',
      'pricing': 'விலை',
      'recentSearches': 'சமீபத்திய தேடல்கள்',
      'clearRecentSearches': 'அழி',
      'venueOptimizer': 'வென்யூ ஆப்டிமைசர்',
      'offline': 'நீங்கள் ஆஃப்லைனில் உள்ளீர்கள்',
      'language': 'மொழி',
      'login': 'உள்நுழை',
      'password': 'கடவுச்சொல்',
      'payNow': 'பணம் செலுத்து',
      'notifications': 'அறிவிப்புகள்',
      'call': 'அழை',
      'whatsapp': 'வாட்ஸ்அப்',
      'ownerDashboard': 'உரிமையாளர் தளம்',
      'createProfile': 'சுயவிவரம் உருவாக்கு',
      'orDivider': 'அல்லது',
      'notAnOwner': 'உரிமையாளர் அல்ல',
      'instituteOwnerPortal': 'நிறுவன உரிமையாளர் தளம்',
      'createInstitute': 'நிறுவனம் உருவாக்கு',
      'addClass': 'வகுப்பு சேர்',
      'allFilters': 'அனைத்து வடிகட்டிகள்',
      'recommended': 'பரிந்துரைக்கப்பட்டவை',
      'noResults': 'முடிவுகள் இல்லை',
      'filters': 'வடிகட்டி',
      'verified': 'சரிபார்க்கப்பட்டது',
      'hotels': 'ஹோட்டல்கள்',
      'functionHalls': 'மண்டபங்கள்',
      'qrCheckIn': 'QR செக்-இன்',
      'quickBookingMode': 'விரைவு புக்கிங்',
    },
    'kn': {
      'appName': 'ಬುಕ್ ಮೈ ಸ್ಪೇಸ್',
      'searchHint': 'ಫಂಕ್ಷನ್ ಹಾಲ್, ಪಿಜಿ, ಹೋಟೆಲ್ ಹುಡುಕಿ...',
      'search': 'ಹುಡುಕಿ',
      'bookNow': 'ಈಗಲೇ ಬುಕ್ ಮಾಡಿ',
      'cancel': 'ರದ್ದುಮಾಡಿ',
      'confirm': 'ಖಚಿತಪಡಿಸಿ',
      'save': 'ಉಳಿಸಿ',
      'navHome': 'ಹೋಮ್',
      'navSearch': 'ಹುಡುಕಿ',
      'navBookings': 'ನನ್ನ ಬುಕಿಂಗ್‌ಗಳು',
      'navSaved': 'ಉಳಿಸಿದವು',
      'navProfile': 'ಪ್ರೊಫೈಲ್',
      'reviews': 'ವಿಮರ್ಶೆಗಳು',
      'amenities': 'ಸೌಲಭ್ಯಗಳು',
      'capacity': 'ಸಾಮರ್ಥ್ಯ',
      'pricing': 'ಬೆಲೆ',
      'recentSearches': 'ಇತ್ತೀಚಿನ ಹುಡುಕಾಟಗಳು',
      'clearRecentSearches': 'ತೆರವುಗೊಳಿಸಿ',
      'venueOptimizer': 'ವೆನ್ಯೂ ಆಪ್ಟಿಮೈಜರ್',
      'offline': 'ನೀವು ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ',
      'language': 'ಭಾಷೆ',
      'login': 'ಲಾಗಿನ್',
      'password': 'ಪಾಸ್‌ವರ್ಡ್',
      'payNow': 'ಈಗ ಪಾವತಿಸಿ',
      'notifications': 'ಅಧಿಸೂಚನೆಗಳು',
      'call': 'ಕರೆ',
      'whatsapp': 'ವಾಟ್ಸಾಪ್',
      'ownerDashboard': 'ಮಾಲೀಕರ ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
      'createProfile': 'ಪ್ರೊಫೈಲ್ ರಚಿಸಿ',
      'orDivider': 'ಅಥವಾ',
      'notAnOwner': 'ಮಾಲೀಕರಲ್ಲ',
      'instituteOwnerPortal': 'ಸಂಸ್ಥೆ ಮಾಲೀಕರ ಪೋರ್ಟಲ್',
      'createInstitute': 'ಸಂಸ್ಥೆ ರಚಿಸಿ',
      'addClass': 'ತರಗತಿ ಸೇರಿಸಿ',
      'allFilters': 'ಎಲ್ಲಾ ಫಿಲ್ಟರ್‌ಗಳು',
      'recommended': 'ಶಿಫಾರಸು',
      'noResults': 'ಫಲಿತಾಂಶಗಳಿಲ್ಲ',
      'filters': 'ಫಿಲ್ಟರ್',
      'verified': 'ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
      'hotels': 'ಹೋಟೆಲ್‌ಗಳು',
      'functionHalls': 'ಫಂಕ್ಷನ್ ಹಾಲ್‌ಗಳು',
      'qrCheckIn': 'QR ಚೆಕ್-ಇನ್',
      'quickBookingMode': 'ಕ್ವಿಕ್ ಬುಕಿಂಗ್',
    },
    'mr': {
      'appName': 'बुक माय स्पेस',
      'searchHint': 'हॉल, पीजी, हॉटेल शोधा...',
      'search': 'शोधा',
      'bookNow': 'आत्ताच बुक करा',
      'cancel': 'रद्द करा',
      'confirm': 'नक्की करा',
      'save': 'सेव्ह करा',
      'navHome': 'होम',
      'navSearch': 'शोधा',
      'navBookings': 'माझ्या बुकिंग्स',
      'navSaved': 'सेव्ह केलेले',
      'navProfile': 'प्रोफाइल',
      'reviews': 'समीक्षा',
      'amenities': 'सुविधा',
      'capacity': 'क्षमता',
      'pricing': 'किंमत',
      'recentSearches': 'अलीकडील शोध',
      'clearRecentSearches': 'साफ करा',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'तुम्ही ऑफलाइन आहात',
      'language': 'भाषा',
      'login': 'लॉग इन',
      'password': 'पासवर्ड',
      'payNow': 'आत्ताच पैसे द्या',
      'notifications': 'सूचना',
      'call': 'कॉल',
      'whatsapp': 'व्हॉट्सॲप',
      'ownerDashboard': 'मालक डॅशबोर्ड',
      'createProfile': 'प्रोफाइल तयार करा',
      'orDivider': 'किंवा',
      'notAnOwner': 'मालक नाही',
      'instituteOwnerPortal': 'संस्था मालक पोर्टल',
      'createInstitute': 'संस्था तयार करा',
      'addClass': 'क्लास जोडा',
      'allFilters': 'सर्व फिल्टर',
      'recommended': 'शिफारस',
      'noResults': 'निकाल नाहीत',
      'filters': 'फिल्टर',
      'verified': 'सत्यापित',
      'hotels': 'हॉटेल्स',
      'functionHalls': 'फंक्शन हॉल',
      'qrCheckIn': 'QR चेक-इन',
      'quickBookingMode': 'क्विक बुकिंग',
    },
    'bn': {
      'appName': 'বুক মাই স্পেস',
      'searchHint': 'ভেন্যু, পিজি, হোটেল খুঁজুন...',
      'search': 'খুঁজুন',
      'bookNow': 'এখনই বুক করুন',
      'cancel': 'বাতিল করুন',
      'confirm': 'নিশ্চিত করুন',
      'save': 'সংরক্ষণ করুন',
      'navHome': 'হোম',
      'navSearch': 'খুঁজুন',
      'navBookings': 'আমার বুকিং',
      'navSaved': 'সংরক্ষিত',
      'navProfile': 'প্রোফাইল',
      'reviews': 'রিভিউ',
      'amenities': 'সুযোগ-সুবিধা',
      'capacity': 'ক্ষমতা',
      'pricing': 'মূল্য',
      'recentSearches': 'সাম্প্রতিক অনুসন্ধান',
      'clearRecentSearches': 'মুছুন',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'আপনি অফলাইন আছেন',
      'language': 'ভাষা',
      'login': 'লগ ইন',
      'password': 'পাসওয়ার্ড',
      'payNow': 'পেমেন্ট করুন',
      'notifications': 'বিজ্ঞপ্তি',
      'call': 'কল',
      'whatsapp': 'হোয়াটসঅ্যাপ',
      'ownerDashboard': 'মালিক ড্যাশবোর্ড',
      'createProfile': 'প্রোফাইল তৈরি করুন',
      'orDivider': 'অথবা',
      'notAnOwner': 'মালিক নন',
      'instituteOwnerPortal': 'ইনস্টিটিউট ওনার পোর্টাল',
      'createInstitute': 'ইনস্টিটিউট তৈরি করুন',
      'addClass': 'ক্লাস যোগ করুন',
      'allFilters': 'সব ফিল্টার',
      'recommended': 'সুপারিশকৃত',
      'noResults': 'কোনো ফলাফল নেই',
      'filters': 'ফিল্টার',
      'verified': 'যাচাইকৃত',
      'hotels': 'হোটেল',
      'functionHalls': 'ফাংশন হল',
      'qrCheckIn': 'QR চেক-ইন',
      'quickBookingMode': 'কুইক বুকিং',
    },
    'gu': {
      'appName': 'બુક માય સ્પેસ',
      'searchHint': 'હોલ, પીજી, હોટેલ શોધો...',
      'search': 'શોધો',
      'bookNow': 'હમણાં બુક કરો',
      'cancel': 'રદ કરો',
      'confirm': 'કન્ફર્મ કરો',
      'save': 'સેવ કરો',
      'navHome': 'હોમ',
      'navSearch': 'શોધો',
      'navBookings': 'મારી બુકિંગ',
      'navSaved': 'સેવ કરેલ',
      'navProfile': 'પ્રોફાઈલ',
      'reviews': 'રિવ્યુ',
      'amenities': 'સુવિધાઓ',
      'capacity': 'ક્ષમતા',
      'pricing': 'કિંમત',
      'recentSearches': 'તાજેતરની શોધ',
      'clearRecentSearches': 'સાફ કરો',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'તમે ઑફલાઇન છો',
      'language': 'ભાષા',
      'login': 'લોગિન',
      'password': 'પાસવર્ડ',
      'payNow': 'હમણાં ચૂકવો',
      'notifications': 'સૂચનાઓ',
      'call': 'કોલ',
      'whatsapp': 'વોટ્સએપ',
      'ownerDashboard': 'માલિક ડેશબોર્ડ',
      'createProfile': 'પ્રોફાઈલ બનાવો',
      'orDivider': 'અથવા',
      'notAnOwner': 'માલિક નથી',
      'instituteOwnerPortal': 'સંસ્થા માલિક પોર્ટલ',
      'createInstitute': 'સંસ્થા બનાવો',
      'addClass': 'ક્લાસ ઉમેરો',
      'allFilters': 'બધા ફિલ્ટર',
      'recommended': 'ભલામણ',
      'noResults': 'પરિણામ નથી',
      'filters': 'ફિલ્ટર',
      'verified': 'ચકાસાયેલ',
      'hotels': 'હોટેલ્સ',
      'functionHalls': 'ફંક્શન હોલ',
      'qrCheckIn': 'QR ચેક-ઇન',
      'quickBookingMode': 'ક્વિક બુકિંગ',
    },
    'ml': {
      'appName': 'ബുക്ക് മൈ സ്‌പേസ്',
      'searchHint': 'ഹാൾ, പിജി, ഹോട്ടൽ തിരയുക...',
      'search': 'തിരയുക',
      'bookNow': 'ഇപ്പോൾ ബുക്ക് ചെയ്യുക',
      'cancel': 'റദ്ദാക്കുക',
      'confirm': 'ഉറപ്പാക്കുക',
      'save': 'സേവ് ചെയ്യുക',
      'navHome': 'ഹോം',
      'navSearch': 'തിരയുക',
      'navBookings': 'എന്റെ ബുക്കിംഗുകൾ',
      'navSaved': 'സേവ് ചെയ്‌തവ',
      'navProfile': 'പ്രൊഫൈൽ',
      'reviews': 'അഭിപ്രായങ്ങൾ',
      'amenities': 'സൗകര്യങ്ങൾ',
      'capacity': 'ശേഷി',
      'pricing': 'വില',
      'recentSearches': 'സമീപകാല തിരച്ചിലുകൾ',
      'clearRecentSearches': 'മായ്ക്കുക',
      'venueOptimizer': 'Venue Optimizer',
      'offline': 'നിങ്ങൾ ഓഫ്‌ലൈനാണ്',
      'language': 'ഭാഷ',
      'login': 'ലോഗിൻ',
      'password': 'പാസ്‌വേഡ്',
      'payNow': 'ഇപ്പോൾ പണമടയ്ക്കുക',
      'notifications': 'അറിയിപ്പുകൾ',
      'call': 'വിളിക്കുക',
      'whatsapp': 'വാട്ട്‌സ്ആപ്പ്',
      'ownerDashboard': 'ഉടമ ഡാഷ്‌ബോർഡ്',
      'createProfile': 'പ്രൊഫൈൽ സൃഷ്ടിക്കുക',
      'orDivider': 'അല്ലെങ്കിൽ',
      'notAnOwner': 'ഉടമയല്ല',
      'instituteOwnerPortal': 'ഇൻസ്റ്റിറ്റ്യൂട്ട് ഉടമ പോർട്ടൽ',
      'createInstitute': 'ഇൻസ്റ്റിറ്റ്യൂട്ട് സൃഷ്ടിക്കുക',
      'addClass': 'ക്ലാസ് ചേർക്കുക',
      'allFilters': 'എല്ലാ ഫിൽട്ടറുകളും',
      'recommended': 'ശുപാർശ',
      'noResults': 'ഫലങ്ങളില്ല',
      'filters': 'ഫിൽട്ടർ',
      'verified': 'സ്ഥിരീകരിച്ചത്',
      'hotels': 'ഹോട്ടലുകൾ',
      'functionHalls': 'ഫംഗ്ഷൻ ഹാളുകൾ',
      'qrCheckIn': 'QR ചെക്ക്-ഇൻ',
      'quickBookingMode': 'ക്വിക്ക് ബുക്കിംഗ്',
    },
    'es': {
      'appName': 'BookMySpace',
      'searchHint': 'Buscar local, PG, hotel...',
      'search': 'Buscar',
      'bookNow': 'Reservar ahora',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'save': 'Guardar',
      'navHome': 'Inicio',
      'navSearch': 'Buscar',
      'navBookings': 'Mis reservas',
      'navSaved': 'Guardados',
      'navProfile': 'Perfil',
      'reviews': 'Reseñas',
      'amenities': 'Comodidades',
      'capacity': 'Capacidad',
      'pricing': 'Precio',
      'recentSearches': 'Búsquedas recientes',
      'clearRecentSearches': 'Borrar',
      'venueOptimizer': 'Optimizador de locales',
      'offline': 'Estás sin conexión',
      'language': 'Idioma',
      'login': 'Iniciar sesión',
      'password': 'Contraseña',
      'payNow': 'Pagar ahora',
      'notifications': 'Notificaciones',
      'call': 'Llamar',
      'whatsapp': 'WhatsApp',
      'ownerDashboard': 'Panel del propietario',
      'createProfile': 'Crear un perfil',
      'orDivider': 'O',
      'notAnOwner': 'No es propietario',
      'instituteOwnerPortal': 'Portal del instituto',
      'createInstitute': 'Crear instituto',
      'addClass': 'Añadir clase',
      'allFilters': 'Todos los filtros',
      'recommended': 'Recomendados',
      'noResults': 'Sin resultados',
      'filters': 'Filtros',
      'verified': 'Verificado',
      'hotels': 'Hoteles',
      'functionHalls': 'Salones',
      'qrCheckIn': 'Check-in QR',
      'quickBookingMode': 'Reserva rápida',
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
