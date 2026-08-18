import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_audit_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_list_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_registration_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen.dart';
import '../../features/owner_venues/presentation/screens/create_venue_screen.dart';
import '../../features/legal/presentation/screens/privacy_policy_screen.dart';
import '../../features/legal/presentation/screens/terms_of_service_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/saved/presentation/screens/saved_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/venues/domain/venue.dart';
import '../../features/venues/presentation/screens/venue_details_screen.dart';
import '../localization/app_localizations.dart';

/// Route names used for navigation.
abstract class AppRoutes {
  static const onboarding = '/onboarding';
  static const shell = '/home';
  static const home = '/home';
  static const search = '/search';
  static const bookings = '/bookings';
  static const saved = '/saved';
  static const profile = '/profile';
  static const settings = '/settings';
  static const login = '/login';
  static const venueDetails = '/venues/:id';
  static const bookingFlow = '/venues/:id/book';
  static const paymentFlow = '/bookings/:id/pay';
  static const eventsList = '/events';
  static const eventDetails = '/events/:id';
  static const coursesList = '/courses';
  static const courseDetails = '/courses/:id';
  static const notifications = '/notifications';
  static const analytics = '/analytics';
  static const support = '/support';
  static const adminAudit = '/admin/audit';
  static const ownerRegistration = '/owner/register';
  static const ownerDashboard = '/owner';
  static const ownerVenues = '/owner/venues';
  static const ownerVenueCreate = '/owner/venues/create';
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
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      if (!authReady) return null;
      final location = state.matchedLocation;
      final isPublic =
          location == AppRoutes.onboarding || location == AppRoutes.login;
      if (currentUser == null) {
        return isPublic ? null : AppRoutes.login;
      }
      return isPublic ? AppRoutes.shell : null;
    },
    routes: [
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
          if (venue == null) {
            // Bookmark/refresh navigation without a venue object — fall back
            // to the details screen which can re-fetch the venue.
            return VenueDetailsScreen(
              venueId: state.pathParameters['id'] ?? '',
            );
          }
          return BookingScreen(venue: venue);
        },
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
        path: AppRoutes.courseDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CourseDetailScreen(
          courseId: state.pathParameters['id'] ?? '',
        ),
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
        path: AppRoutes.adminAudit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminAuditScreen(),
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
                  final category = extra is Map<String, dynamic>
                      ? extra['category'] as String?
                      : null;
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: l10n.notifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search_rounded),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: l10n.navBookings,
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school_rounded),
            label: l10n.courses,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

// Temporary placeholder replaced with a real screen in a later milestone.
class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Profile (M7)')));
  }
}
