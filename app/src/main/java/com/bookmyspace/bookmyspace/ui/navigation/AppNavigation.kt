package com.bookmyspace.bookmyspace.ui.navigation

import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.*
import androidx.navigation.navArgument
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.ContextAwareHelpFab
import com.bookmyspace.bookmyspace.ui.screens.*
import com.bookmyspace.bookmyspace.util.LocalizedStrings

sealed class Screen(val route: String, val title: String, val icon: ImageVector? = null) {
    object Home : Screen("home", "Home", Icons.Default.Home)
    object Map : Screen("map", "Venue Map", Icons.Default.Map)
    object Search : Screen("search?category={category}", "Search", Icons.Default.Search) {
        fun createRoute(categorySlug: String? = null) = if (categorySlug != null) "search?category=$categorySlug" else "search"
    }
    object Bookings : Screen("bookings", "Bookings", Icons.Default.ConfirmationNumber)
    object Saved : Screen("saved", "Saved", Icons.Default.Bookmark)
    object Profile : Screen("profile", "Profile", Icons.Default.Person)

    object VenueDetails : Screen("venues/{id}", "Venue Details") {
        fun createRoute(id: String) = "venues/$id"
    }
    object BookingFlow : Screen("venues/{id}/book", "Book Court") {
        fun createRoute(id: String) = "venues/$id/book"
    }
    object PaymentFlow : Screen("bookings/{id}/pay", "Payment") {
        fun createRoute(id: String) = "bookings/$id/pay"
    }
    object Events : Screen("events", "Events")
    object Courses : Screen("courses", "Courses")
    object Notifications : Screen("notifications", "Notifications")
    object QrScanner : Screen("qr_scanner", "QR Check-In", Icons.Default.QrCodeScanner)
    object Analytics : Screen("analytics", "Analytics")
    object Support : Screen("support", "Support")
    object AdminAudit : Screen("admin/audit", "Admin Audit")
    object OwnerDashboard : Screen("owner", "Owner Dashboard")
    object CreateVenue : Screen("owner/create", "Create Venue")
    object Privacy : Screen("privacy", "Privacy Policy")
    object Terms : Screen("terms", "Terms of Service")
    object Login : Screen("login", "Login")
    object Referral : Screen("referral", "Refer & Earn", Icons.Default.CardGiftcard)
    object ThemeCustomizer : Screen("theme_customizer", "Theme Customizer", Icons.Default.Palette)
    object InstitutesAndClasses : Screen("institutes", "Institutes & Classes", Icons.Default.School)
    object InstituteOwnerDashboard : Screen("institute_owner", "Institute Owner Portal", Icons.Default.Apartment)
    object ListingFieldsConfig : Screen("listing_fields_config", "Listing Fields Configuration", Icons.Default.Tune)
    object AdminAppSections : Screen("admin/app_sections", "App Sections & Feature Toggles", Icons.Default.ToggleOn)
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bottomBarScreens = listOf(
        Screen.Home,
        Screen.Map,
        Screen.Search,
        Screen.Bookings,
        Screen.Profile
    )

    val showBottomBar = currentRoute in listOf(
        Screen.Home.route,
        Screen.Map.route,
        "search",
        Screen.Search.route,
        Screen.Bookings.route,
        Screen.Saved.route,
        Screen.Profile.route
    )

    Scaffold(
        floatingActionButton = {
            val isDetailOrBookingRoute = currentRoute?.startsWith("venues/") == true ||
                    currentRoute?.startsWith("bookings/") == true ||
                    currentRoute?.contains("/book") == true ||
                    currentRoute?.contains("/pay") == true

            val bottomPadding = if (isDetailOrBookingRoute) 110.dp else if (showBottomBar) 88.dp else 16.dp

            ContextAwareHelpFab(
                currentRoute = currentRoute,
                onNavigateToRoute = { route -> navController.navigate(route) },
                modifier = Modifier.padding(bottom = bottomPadding)
            )
        },
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    bottomBarScreens.forEach { screen ->
                        val selected = currentRoute == screen.route ||
                                (screen == Screen.Search && currentRoute?.startsWith("search") == true)
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(screen.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(screen.icon ?: Icons.Default.Home, contentDescription = screen.title) },
                            label = {
                                val localizedTitle = when (screen) {
                                    Screen.Home -> LocalizedStrings.get("home")
                                    Screen.Map -> LocalizedStrings.get("map")
                                    Screen.Search -> LocalizedStrings.get("search")
                                    Screen.Bookings -> LocalizedStrings.get("my_bookings")
                                    Screen.Saved -> LocalizedStrings.get("saved")
                                    Screen.Profile -> LocalizedStrings.get("profile")
                                    else -> screen.title
                                }
                                Text(localizedTitle)
                            }
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        SharedTransitionLayout {
            NavHost(
                navController = navController,
                startDestination = Screen.Home.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(Screen.Home.route) {
                    HomeScreen(
                        onNavigateToVenue = { id -> navController.navigate(Screen.VenueDetails.createRoute(id)) },
                        onNavigateToSearch = { cat -> navController.navigate(Screen.Search.createRoute(cat)) },
                        onNavigateToEvents = { navController.navigate(Screen.Events.route) },
                        onNavigateToCourses = { navController.navigate(Screen.Courses.route) },
                        onNavigateToInstitutes = { navController.navigate(Screen.InstitutesAndClasses.route) },
                        onNavigateToNotifications = { navController.navigate(Screen.Notifications.route) },
                        onNavigateToQrScanner = { navController.navigate(Screen.QrScanner.route) },
                        onNavigateToLogin = { navController.navigate(Screen.Login.route) },
                        onNavigateToProfile = { navController.navigate(Screen.Profile.route) },
                        onNavigateToMap = { navController.navigate(Screen.Map.route) },
                        sharedTransitionScope = this@SharedTransitionLayout,
                        animatedVisibilityScope = this
                    )
                }

                composable(Screen.Map.route) {
                    VenueMapScreen(
                        onNavigateToVenue = { id -> navController.navigate(Screen.VenueDetails.createRoute(id)) }
                    )
                }

                composable(
                    route = Screen.Search.route,
                    arguments = listOf(navArgument("category") {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    })
                ) { backStackEntry ->
                    val categorySlug = backStackEntry.arguments?.getString("category")
                    SearchScreen(
                        initialCategorySlug = categorySlug,
                        onNavigateToVenue = { id -> navController.navigate(Screen.VenueDetails.createRoute(id)) },
                        sharedTransitionScope = this@SharedTransitionLayout,
                        animatedVisibilityScope = this
                    )
                }

                composable(Screen.Bookings.route) {
                    MyBookingsScreen(
                        onPayBooking = { id -> navController.navigate(Screen.PaymentFlow.createRoute(id)) }
                    )
                }

                composable(Screen.Saved.route) {
                    SavedScreen(
                        onNavigateToVenue = { id -> navController.navigate(Screen.VenueDetails.createRoute(id)) },
                        sharedTransitionScope = this@SharedTransitionLayout,
                        animatedVisibilityScope = this
                    )
                }

                composable(Screen.Profile.route) {
                    ProfileScreen(
                        onNavigateToOwnerDashboard = { navController.navigate(Screen.OwnerDashboard.route) },
                        onNavigateToAnalytics = { navController.navigate(Screen.Analytics.route) },
                        onNavigateToAdminAudit = { navController.navigate(Screen.AdminAudit.route) },
                        onNavigateToSupport = { navController.navigate(Screen.Support.route) },
                        onNavigateToPrivacy = { navController.navigate(Screen.Privacy.route) },
                        onNavigateToTerms = { navController.navigate(Screen.Terms.route) },
                        onNavigateToLogin = { navController.navigate(Screen.Login.route) },
                        onNavigateToReferral = { navController.navigate(Screen.Referral.route) },
                        onNavigateToThemeCustomizer = { navController.navigate(Screen.ThemeCustomizer.route) },
                        onNavigateToAdminAppSections = { navController.navigate(Screen.AdminAppSections.route) },
                        onNavigateToInstitutesClasses = { navController.navigate(Screen.InstitutesAndClasses.route) },
                        onNavigateToInstituteOwnerDashboard = { navController.navigate(Screen.InstituteOwnerDashboard.route) },
                        onNavigateToListingFieldsConfig = { navController.navigate(Screen.ListingFieldsConfig.route) }
                    )
                }

                composable(Screen.Referral.route) {
                    ReferralScreen(
                        onBack = { navController.popBackStack() }
                    )
                }

                composable(
                    route = Screen.VenueDetails.route,
                    arguments = listOf(navArgument("id") { type = NavType.StringType })
                ) { backStackEntry ->
                    val venueId = backStackEntry.arguments?.getString("id") ?: ""
                    VenueDetailsScreen(
                        venueId = venueId,
                        onBack = { navController.popBackStack() },
                        onBookSlot = { id -> navController.navigate(Screen.BookingFlow.createRoute(id)) },
                        sharedTransitionScope = this@SharedTransitionLayout,
                        animatedVisibilityScope = this
                    )
                }

            composable(
                route = Screen.BookingFlow.route,
                arguments = listOf(navArgument("id") { type = NavType.StringType })
            ) { backStackEntry ->
                val venueId = backStackEntry.arguments?.getString("id") ?: ""
                BookingScreen(
                    venueId = venueId,
                    onBack = { navController.popBackStack() },
                    onProceedToPayment = { bookingId -> navController.navigate(Screen.PaymentFlow.createRoute(bookingId)) }
                )
            }

            composable(
                route = Screen.PaymentFlow.route,
                arguments = listOf(navArgument("id") { type = NavType.StringType })
            ) { backStackEntry ->
                val bookingId = backStackEntry.arguments?.getString("id") ?: ""
                PaymentScreen(
                    bookingId = bookingId,
                    onBack = { navController.popBackStack() },
                    onPaymentSuccess = {
                        navController.navigate(Screen.Bookings.route) {
                            popUpTo(Screen.Home.route)
                        }
                    }
                )
            }

            composable(Screen.Events.route) {
                EventsScreen()
            }

            composable(Screen.Courses.route) {
                InstitutesAndClassesScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToOwnerDashboard = { navController.navigate(Screen.InstituteOwnerDashboard.route) }
                )
            }

            composable(Screen.InstitutesAndClasses.route) {
                InstitutesAndClassesScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToOwnerDashboard = { navController.navigate(Screen.InstituteOwnerDashboard.route) }
                )
            }

            composable(Screen.InstituteOwnerDashboard.route) {
                InstituteOwnerDashboardScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToLogin = { navController.navigate(Screen.Login.route) }
                )
            }

            composable(Screen.ListingFieldsConfig.route) {
                ListingFieldsConfigScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }

            composable(Screen.AdminAppSections.route) {
                AdminAppSectionsScreen(
                    onNavigateBack = { navController.popBackStack() }
                )
            }

            composable(Screen.Notifications.route) {
                NotificationsScreen(
                    onBack = { navController.popBackStack() },
                    onNavigateToBookings = {
                        navController.navigate(Screen.Bookings.route) {
                            popUpTo(Screen.Home.route)
                        }
                    }
                )
            }

            composable(Screen.QrScanner.route) {
                QrCheckInScannerScreen(
                    onBack = { navController.popBackStack() },
                    onNavigateToBookings = {
                        navController.navigate(Screen.Bookings.route) {
                            popUpTo(Screen.Home.route)
                        }
                    }
                )
            }

            composable(Screen.Analytics.route) {
                AnalyticsScreen(onBack = { navController.popBackStack() })
            }

            composable(Screen.Support.route) {
                SupportScreen()
            }

            composable(Screen.AdminAudit.route) {
                AdminAuditScreen()
            }

            composable(Screen.OwnerDashboard.route) {
                OwnerDashboardScreen(
                    onCreateVenue = { navController.navigate(Screen.CreateVenue.route) }
                )
            }

            composable(Screen.CreateVenue.route) {
                CreateVenueScreen(
                    onVenueCreated = { navController.popBackStack() },
                    onBack = { navController.popBackStack() }
                )
            }

            composable(Screen.Privacy.route) {
                PrivacyPolicyScreen(onBack = { navController.popBackStack() })
            }

            composable(Screen.Terms.route) {
                TermsOfServiceScreen(onBack = { navController.popBackStack() })
            }

            composable(Screen.ThemeCustomizer.route) {
                ThemeCustomizerScreen(onNavigateBack = { navController.popBackStack() })
            }

            composable(Screen.Login.route) {
                LoginScreen(
                    onLoginSuccess = { role ->
                        when (role) {
                            UserRole.VENUE_OWNER -> {
                                navController.navigate(Screen.OwnerDashboard.route) {
                                    popUpTo(Screen.Home.route) { inclusive = false }
                                }
                            }
                            UserRole.ADMIN -> {
                                navController.navigate(Screen.AdminAudit.route) {
                                    popUpTo(Screen.Home.route) { inclusive = false }
                                }
                            }
                            else -> {
                                navController.navigate(Screen.Home.route) {
                                    popUpTo(Screen.Home.route) { inclusive = true }
                                }
                            }
                        }
                    }
                )
            }
        }
    }
}
}
