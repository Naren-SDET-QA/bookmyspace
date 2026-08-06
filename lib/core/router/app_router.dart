import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accommodations/domain/accommodation.dart';
import '../../features/accommodations/presentation/screens/accommodation_detail_screen.dart';
import '../../features/accommodations/presentation/screens/accommodation_list_screen.dart';
import '../../features/accommodations/presentation/screens/stay_management_screens.dart';
import '../../features/admin/presentation/screens/admin_audit_screen.dart';
import '../../features/admin/presentation/screens/admin_content_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/screens/auth_callback_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/booking/presentation/screens/booking_result_screen.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_list_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/home/presentation/screens/all_categories_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/invoices/presentation/screens/invoice_screens.dart';
import '../../features/legal/presentation/screens/privacy_policy_screen.dart';
import '../../features/legal/presentation/screens/terms_of_service_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_room_booking_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_room_detail_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_room_owner_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_rooms_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_operations_screen.dart';
import '../../features/owner/presentation/screens/owner_profile_screen.dart';
import '../../features/owner/presentation/screens/owner_registration_screen.dart';
import '../../features/owner_venues/presentation/screens/create_venue_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen.dart';
import '../../features/payments/presentation/screens/commerce_payment_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/payments/presentation/screens/receipt_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/registration/presentation/screens/registration_screens.dart';
import '../../features/saved/presentation/screens/saved_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/sports/presentation/screens/sports_screens.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/venue_import/presentation/screens/admin_venue_claims_screen.dart';
import '../../features/venue_import/presentation/screens/venue_import_screen.dart';
import '../../features/venues/domain/venue.dart';
import '../../features/venues/presentation/screens/venue_details_screen.dart';
import '../localization/app_localizations.dart';
import '../theme/prototype_visuals.dart';

/// Route names used for navigation.
abstract class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const shell = '/home';
  static const home = '/home';
  static const search = '/search';
  static const bookings = '/bookings';
  static const saved = '/saved';
  static const profile = '/profile';
  static const settings = '/settings';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const authCallback = '/auth/callback';
  static const venueDetails = '/venues/:id';
  static const bookingFlow = '/venues/:id/book';
  static const paymentFlow = '/bookings/:id/pay';
  static const commercePayment = '/commerce/:id/pay';
  static const bookingResult = '/bookings/:id/status';
  static const bookingReceipt = '/bookings/:id/receipt';
  static const eventsList = '/events';
  static const eventDetails = '/events/:id';
  static const coursesList = '/courses';
  static const allCategories = '/categories';
  static const courseDetails = '/courses/:id';
  static const pgList = '/pg';
  static const pgDetails = '/pg/:id';
  static const staysList = '/stays';
  static const stayDetails = '/stays/:id';
  static const myStays = '/stays/bookings/mine';
  static const ownerStays = '/owner/stays';
  static const meetingRooms = '/meeting-rooms';
  static const meetingRoomDetails = '/meeting-rooms/:id';
  static const meetingRoomBooking = '/meeting-rooms/:id/book';
  static const ownerMeetingRooms = '/owner/meeting-rooms';
  static const sportsVenues = '/sports';
  static const sportsVenueDetails = '/sports/:id';
  static const sportsBooking = '/sports/:id/book';
  static const ownerSports = '/owner/sports';
  static const registrationForms = '/owner/registration-forms';
  static const registrationFill = '/registration/forms/:id/fill';
  static const invoiceConfig = '/owner/invoice-settings';
  static const invoiceView = '/invoices/:id';
  static const notifications = '/notifications';
  static const analytics = '/analytics';
  static const support = '/support';
  static const adminAudit = '/admin/audit';
  static const adminVenueImport = '/admin/venue-import';
  static const adminVenueClaims = '/admin/venue-claims';
  static const adminContent = '/admin/content';
  static const adminDashboard = '/admin';
  static const ownerRegistration = '/owner/register';
  static const ownerDashboard = '/owner';
  static const ownerVenues = '/owner/venues';
  static const ownerVenueCreate = '/owner/venues/create';
  static const ownerVenueEdit = '/owner/venues/:id/edit';
  static const ownerProfile = '/owner/profile';
  static const ownerAvailability = '/owner/availability';
  static const ownerBookings = '/owner/bookings';
  static const ownerOfflineBooking = '/owner/offline-booking';
  static const ownerPayments = '/owner/payments';
  static const privacyPolicy = '/privacy';
  static const termsOfService = '/terms';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

/// Creates the application router. [initialLocation] is overridable in tests.
///
/// When [currentUser] is provided, protected routes redirect to the login
/// screen for unauthenticated users, and signed-in users are bounced away from
/// the onboarding/login screens. A `null` [currentUser] disables gating.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.shell,
  AuthUser? currentUser,
  bool authReady = true,
  AppAccessRole accessRole = AppAccessRole.customer,
  bool roleReady = true,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      if (!authReady) return null;
      final location = state.matchedLocation;
      final isAuthEntry =
          location == AppRoutes.onboarding ||
          location == AppRoutes.login ||
          location == AppRoutes.signup ||
          location == AppRoutes.forgotPassword;
      final isAuthCallback = location == AppRoutes.authCallback;
      final isSplash = location == AppRoutes.splash;
      final isPublic = isAuthEntry || isAuthCallback || isSplash;
      if (currentUser == null) {
        return isPublic ? null : AppRoutes.login;
      }
      if (!roleReady) return null;
      if (isAuthCallback) return null;
      final isOwnerRoute =
          location != AppRoutes.ownerRegistration &&
          (location == AppRoutes.ownerDashboard ||
              location.startsWith('/owner/'));
      final isAdminRoute =
          location == AppRoutes.adminDashboard ||
          location.startsWith('/admin/');
      if (isAdminRoute && accessRole != AppAccessRole.admin) {
        return AppRoutes.home;
      }
      if (isOwnerRoute && accessRole != AppAccessRole.owner) {
        return accessRole == AppAccessRole.admin
            ? AppRoutes.adminDashboard
            : AppRoutes.profile;
      }
      if (isAuthEntry) {
        return switch (accessRole) {
          AppAccessRole.admin => AppRoutes.adminDashboard,
          AppAccessRole.owner => AppRoutes.ownerDashboard,
          AppAccessRole.customer => AppRoutes.shell,
        };
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AuthCallbackScreen(
          callbackUri: state.uri.queryParameters.isEmpty ? null : state.uri,
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.venueDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            VenueDetailsScreen(venueId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.bookingFlow,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final venue = extra is Venue ? extra : null;
          final dateParam = state.uri.queryParameters['date'];
          final initialDate = dateParam == null
              ? null
              : DateTime.tryParse(dateParam);
          if (venue == null) {
            // Bookmark/refresh navigation without a venue object — fall back
            // to the details screen which can re-fetch the venue.
            return VenueDetailsScreen(
              venueId: state.pathParameters['id'] ?? '',
            );
          }
          return BookingScreen(venue: venue, initialDate: initialDate);
        },
      ),
      GoRoute(
        path: AppRoutes.bookingResult,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => state.extra is Booking
            ? BookingResultScreen(booking: state.extra! as Booking)
            : const MyBookingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookingReceipt,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ReceiptScreen(bookingId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.eventsList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EventsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.coursesList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CoursesListScreen(),
      ),
            GoRoute(
              path: AppRoutes.allCategories,
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) => const AllCategoriesScreen(),
            ),
      GoRoute(
        path: AppRoutes.pgList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccommodationListScreen(module: AccommodationModule.pg),
      ),
      GoRoute(
        path: AppRoutes.pgDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AccommodationDetailScreen(
          propertyId: state.pathParameters['id'] ?? '',
          module: AccommodationModule.pg,
        ),
      ),
      GoRoute(
        path: AppRoutes.staysList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccommodationListScreen(module: AccommodationModule.stay),
      ),
      GoRoute(
        path: AppRoutes.stayDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AccommodationDetailScreen(
          propertyId: state.pathParameters['id'] ?? '',
          module: AccommodationModule.stay,
        ),
      ),
      GoRoute(
        path: AppRoutes.courseDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            CourseDetailScreen(courseId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.registrationFill,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RegistrationFillScreen(
          formId: state.pathParameters['id'] ?? '',
          bookingId: state.uri.queryParameters['bookingId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.sportsVenues,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SportsVenuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.sportsVenueDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            SportsVenueDetailScreen(venueId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.sportsBooking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            SportsBookingScreen(venueId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.meetingRooms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MeetingRoomsScreen(),
      ),
      GoRoute(
        path: AppRoutes.meetingRoomDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MeetingRoomDetailScreen(roomId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.meetingRoomBooking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MeetingRoomBookingScreen(roomId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.support,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportTicketsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      for (final module in AdminModule.values)
        GoRoute(
          path: '/admin/${module.name}',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => AdminModuleScreen(module: module),
        ),
      GoRoute(
        path: AppRoutes.adminAudit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminAuditScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminVenueImport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const VenueImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminVenueClaims,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminVenueClaimsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminContent,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminContentScreen(),
      ),
      GoRoute(
        path: AppRoutes.commercePayment,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CommercePaymentScreen(
          referenceId: state.pathParameters['id']!,
          amount:
              double.tryParse(state.uri.queryParameters['amount'] ?? '') ?? 0,
          currency: state.uri.queryParameters['currency'] ?? 'INR',
        ),
      ),
      GoRoute(
        path: AppRoutes.myStays,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyStayBookingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerStays,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const StayOwnerScreen(),
      ),
      GoRoute(
        path: AppRoutes.registrationForms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RegistrationFormsAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.invoiceConfig,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InvoiceConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.invoiceView,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            InvoiceScreen(invoiceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.ownerSports,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SportsOwnerScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerMeetingRooms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MeetingRoomOwnerScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerRegistration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerVenues,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerVenuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateVenueScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueEdit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CreateVenueScreen(
          venue: state.extra is Venue ? state.extra as Venue : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerAvailability,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const OwnerOperationsScreen(operation: OwnerOperation.availability),
      ),
      GoRoute(
        path: AppRoutes.ownerBookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const OwnerOperationsScreen(operation: OwnerOperation.bookings),
      ),
      GoRoute(
        path: AppRoutes.ownerOfflineBooking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerOperationsScreen(
          operation: OwnerOperation.offlineBooking,
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerPayments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const OwnerOperationsScreen(operation: OwnerOperation.payments),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentFlow,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final booking = extra is Booking ? extra : null;
          if (booking == null) {
            // Deep link without a booking object — show the bookings tab.
            return const MyBookingsScreen();
          }
          return PaymentScreen(booking: booking);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) {
                  final extra = state.extra;
                  final category =
                      state.uri.queryParameters['category'] ??
                      (extra is Map<String, dynamic>
                          ? extra['category'] as String?
                          : null);
                  return SearchScreen(initialCategory: category);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: PrototypeBottomNav(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          PrototypeNavDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: l10n.navHome,
          ),
          const PrototypeNavDestination(
            icon: Icons.search_outlined,
            selectedIcon: Icons.search_rounded,
            label: 'Explore',
          ),
          PrototypeNavDestination(
            icon: Icons.confirmation_number_outlined,
            selectedIcon: Icons.confirmation_number_rounded,
            label: l10n.navBookings,
          ),
          const PrototypeNavDestination(
            icon: Icons.favorite_border_rounded,
            selectedIcon: Icons.favorite_rounded,
            label: 'Saved',
          ),
          PrototypeNavDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
