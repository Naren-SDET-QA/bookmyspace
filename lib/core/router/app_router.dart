import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_app_sections_screen.dart';
import '../../features/admin/presentation/screens/admin_feature_configuration_screen.dart';
import '../../features/admin/presentation/screens/admin_audit_screen.dart';
import '../../features/admin/presentation/screens/admin_categories_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_listing_fields_screen.dart';
import '../../features/admin/presentation/screens/admin_listings_screen.dart';
import '../../features/admin/presentation/screens/admin_oversight_screen.dart';
import '../../features/payments/presentation/screens/payment_health_screen.dart';
import '../../features/registration/presentation/unified_registration_screen.dart';
import '../../features/ai/presentation/screens/assistant_screen.dart';
import '../../features/checkin/presentation/screens/qr_check_in_screen.dart';
import '../../features/institutes/presentation/screens/institute_detail_screen.dart';
import '../../features/institutes/presentation/screens/institute_owner_dashboard_screen.dart';
import '../../features/institutes/presentation/screens/institutes_list_screen.dart';
import '../../features/saved/presentation/screens/saved_screen.dart';
import '../../features/settings/presentation/screens/theme_customizer_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/invoice_screen.dart';
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
import '../../features/owner/presentation/screens/registration_field_configuration_screen.dart';
import '../../features/business/presentation/screens/business_pricing_configuration_screen.dart';
import '../../features/owner_bookings/presentation/screens/create_offline_booking_screen.dart';
import '../../features/owner_bookings/presentation/screens/owner_bookings_screen.dart';
import '../../features/owner_bookings/presentation/screens/owner_calendar_screen.dart';
import '../../features/owner_venues/presentation/screens/create_venue_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen.dart';
import '../../features/legal/presentation/screens/privacy_policy_screen.dart';
import '../../features/legal/presentation/screens/terms_of_service_screen.dart';
import '../../features/location/presentation/screens/location_management_screen.dart';
import '../../features/payments/presentation/screens/payment_history_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/rewards/presentation/screens/referral_screen.dart';
import '../../features/rewards/presentation/screens/wallet_screen.dart';
import '../../features/rewards/presentation/screens/admin_reward_config_screen.dart';
import '../../features/customer_analytics/presentation/screens/customer_analytics_screen.dart';
import '../../features/registration/presentation/module_configuration_screen.dart';
import '../../features/registration/presentation/module_registration_screen.dart';
import '../../features/registration/presentation/module_submission_status_screen.dart';
import '../../features/business/presentation/screens/business_plan_configuration_screen.dart';
import '../config/settings_controller.dart';
import '../modular/feature_id.dart';
import '../modular/feature_providers.dart';
import '../modular/feature_registry.dart';
import '../modular/shell_destinations.dart';
import '../../features/search/presentation/screens/map_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/domain/ai_search_intent.dart';
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
  static const map = '/map';
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
  static const adminDashboard = '/admin';
  static const adminListings = '/admin/listings';
  static const adminCategories = '/admin/categories';
  static const adminAppSections = '/admin/app-sections';
  static const adminFeatureConfiguration = '/admin/features';
  static const adminBookings = '/admin/bookings';
  static const adminPayments = '/admin/payments';
  static const adminRefunds = '/admin/refunds';
  static const adminPaymentHealth = '/admin/payment-health';
  static const adminListingFields = '/admin/listing-fields';
  static const unifiedRegistration = '/register';
  static const adminLocations = '/admin/locations';
  static const assistant = '/assistant';
  static const checkIn = '/check-in';
  static const institutesList = '/institutes';
  static const instituteDetails = '/institutes/:id';
  static const ownerInstitute = '/owner/institute';
  static const themeCustomizer = '/theme';
  static const ownerRegistration = '/owner/register';
  static const ownerDashboard = '/owner';
  static const ownerVenues = '/owner/venues';
  static const ownerVenueCreate = '/owner/venues/create';
  static const ownerVenueEdit = '/owner/venues/:id/edit';
  static const ownerBookings = '/owner/bookings';
  static const ownerCalendar = '/owner/calendar';
  static const ownerBookingCreate = '/owner/bookings/create';
  static const ownerLocations = '/owner/locations';
  static const adminRegistrationFields = '/admin/registration-fields';
  static const adminBusinessPricing = '/admin/business-pricing';
  static const adminRewards = '/admin/rewards';
  static const adminBusinessPlans = '/admin/business-plans';
  static const bookingInvoice = '/bookings/:id/invoice';
  static const paymentHistory = '/payments';
  static const wallet = '/wallet';
  static const referrals = '/referrals';
  static const customerAnalytics = '/my-analytics';
  static const adminModuleConfiguration = '/admin/module-configuration';
  static const moduleRegistration = '/register/:module';
  static const moduleSubmissionStatus = '/registration/:id';

  static String ownerVenueEditPath(String id) => '/owner/venues/$id/edit';
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
  bool allowUnauthenticatedTestAccess = false,
  FeatureRegistry? features,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) => resolveAppRedirect(
      location: state.matchedLocation,
      currentUser: currentUser,
      authReady: authReady,
      allowUnauthenticatedTestAccess: allowUnauthenticatedTestAccess,
      features: features,
    ),
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
        path: AppRoutes.themeCustomizer,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ThemeCustomizerScreen(),
      ),
      GoRoute(
        path: AppRoutes.saved,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SavedScreen(),
      ),
      GoRoute(
        path: AppRoutes.assistant,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AssistantScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QrCheckInScreen(),
      ),
      GoRoute(
        path: AppRoutes.institutesList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InstitutesListScreen(),
      ),
      GoRoute(
        path: AppRoutes.instituteDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => InstituteDetailScreen(
          instituteId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerInstitute,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InstituteOwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminListings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminListingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCategories,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminCategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAppSections,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminAppSectionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminFeatureConfiguration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminFeatureConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminBookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AdminOversightScreen(kind: AdminOversightKind.bookings),
      ),
      GoRoute(
        path: AppRoutes.adminPayments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AdminOversightScreen(kind: AdminOversightKind.payments),
      ),
      GoRoute(
        path: AppRoutes.adminRefunds,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AdminOversightScreen(kind: AdminOversightKind.refunds),
      ),
      GoRoute(
        path: AppRoutes.adminPaymentHealth,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PaymentHealthScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminListingFields,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminListingFieldsScreen(),
      ),
      GoRoute(
        path: AppRoutes.unifiedRegistration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const UnifiedRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.map,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SearchMapScreen(),
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
        path: AppRoutes.courseDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            CourseDetailScreen(courseId: state.pathParameters['id'] ?? ''),
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
        path: AppRoutes.adminLocations,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const LocationManagementScreen(admin: true),
      ),
      GoRoute(
        path: AppRoutes.adminRegistrationFields,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const RegistrationFieldConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminBusinessPricing,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BusinessPricingConfigurationScreen(),
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
        builder: (context, state) =>
            CreateVenueScreen(venueId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.ownerBookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerBookingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerCalendar,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerBookingCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateOfflineBookingScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerLocations,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const LocationManagementScreen(admin: false),
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
        path: AppRoutes.bookingInvoice,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          return InvoiceScreen(
            bookingId: state.pathParameters['id'] ?? '',
            initial: extra is Booking ? extra : null,
          );
        },
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
      GoRoute(
        path: AppRoutes.paymentHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminRewards,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminRewardConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminModuleConfiguration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModuleConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.moduleRegistration,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            state.pathParameters['module'] == 'venue_owner'
                ? AppRoutes.ownerRegistration
                : null,
        builder: (context, state) => ModuleRegistrationScreen(
          moduleKey: state.pathParameters['module'] ?? '',
          venueId: state.uri.queryParameters['venue_id'],
          bookingId: state.uri.queryParameters['booking_id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.moduleSubmissionStatus,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ModuleSubmissionStatusScreen(
          submissionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.adminBusinessPlans,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BusinessPlanConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.referrals,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerAnalytics,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CustomerAnalyticsScreen(),
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
                path: AppRoutes.notifications,
                builder: (context, state) => const NotificationsScreen(),
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
                  final section = extra is Map<String, dynamic>
                      ? extra['section'] as String?
                      : null;
                  final query = extra is Map<String, dynamic>
                      ? extra['query'] as String?
                      : null;
                  final intent = extra is Map<String, dynamic>
                      ? extra['intent'] as AiSearchIntent?
                      : null;
                  return SearchScreen(
                    initialCategory: category,
                    initialSection: section,
                    initialQuery: query,
                    initialIntent: intent,
                  );
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
                path: AppRoutes.coursesList,
                builder: (context, state) => const CoursesListScreen(),
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

/// Pure route authorization used by the router and by role-gating tests.
String? resolveAppRedirect({
  required String location,
  required AuthUser? currentUser,
  required bool authReady,
  bool allowUnauthenticatedTestAccess = false,
  FeatureRegistry? features,
}) {
  if (!authReady) return null;
  final isPublic =
      location == AppRoutes.onboarding ||
      location == AppRoutes.login ||
      location == AppRoutes.unifiedRegistration ||
      location == AppRoutes.ownerRegistration ||
      location.startsWith('/register/');
  if (currentUser == null && !allowUnauthenticatedTestAccess) {
    if (!isPublic) return AppRoutes.login;
  }
  if (currentUser != null) {
    final isAdminRoute =
        location == AppRoutes.adminDashboard || location.startsWith('/admin/');
    final isOwnerRoute =
        location.startsWith('/owner') || location == AppRoutes.analytics;
    if (isAdminRoute && !currentUser.isAdmin) return AppRoutes.profile;
    if (isOwnerRoute && !currentUser.isOwner) return AppRoutes.profile;
    if (location == AppRoutes.onboarding || location == AppRoutes.login) {
      return AppRoutes.shell;
    }
  }
  return _featureRedirect(location, features);
}

String? _featureRedirect(String location, FeatureRegistry? features) {
  final registry = features ?? FeatureRegistry.instance;
  final feature = FeatureRegistry.featureForRoute(location);
  if (feature != null && !registry.isExposed(feature)) {
    return AppRoutes.home;
  }
  if (location.endsWith('/pay') && !registry.isExposed(FeatureId.razorpay)) {
    return AppRoutes.home;
  }
  return null;
}

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final simpleMode = ref.watch(simpleModeProvider);
    final visible = visibleShellDestinations(
      ref.watch(featureRegistryProvider),
    );
    final selected = selectedShellIndex(
      currentBranch: navigationShell.currentIndex,
      visible: visible,
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        labelBehavior: simpleMode
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.onlyShowSelected,
        selectedIndex: selected,
        onDestinationSelected: (index) {
          final branch = visible[index].branchIndex;
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final item in visible)
            NavigationDestination(
              key: ValueKey('shell_${item.id}'),
              icon: Icon(_shellIcon(item.id, selected: false)),
              selectedIcon: Icon(_shellIcon(item.id, selected: true)),
              label: _shellLabel(item.id, l10n),
            ),
        ],
      ),
    );
  }
}

IconData _shellIcon(String id, {required bool selected}) {
  return switch (id) {
    'notifications' =>
      selected ? Icons.notifications_rounded : Icons.notifications_outlined,
    'search' => selected ? Icons.search_rounded : Icons.search_outlined,
    'bookings' =>
      selected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
    'courses' => selected ? Icons.school_rounded : Icons.school_outlined,
    'profile' => selected ? Icons.person_rounded : Icons.person_outline_rounded,
    _ => selected ? Icons.home_rounded : Icons.home_outlined,
  };
}

String _shellLabel(String id, AppLocalizations l10n) {
  return switch (id) {
    'notifications' => l10n.notifications,
    'search' => l10n.navSearch,
    'bookings' => l10n.navBookings,
    'courses' => l10n.courses,
    'profile' => l10n.navProfile,
    _ => l10n.navHome,
  };
}

// Temporary placeholder replaced with a real screen in a later milestone.
class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Profile (M7)')));
  }
}
