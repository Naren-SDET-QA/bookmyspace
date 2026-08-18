package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.auth.UserRoleProvider
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.LanguageSelectorChip
import com.bookmyspace.bookmyspace.ui.components.LanguageSelectorDialog
import com.bookmyspace.bookmyspace.util.LocalizedStrings

data class ProfileActionItem(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val iconTint: Color? = null,
    val targetRoles: Set<UserRole> = setOf(UserRole.USER, UserRole.VENUE_OWNER, UserRole.ADMIN),
    val isFeatureEnabled: Boolean = true,
    val testTag: String? = null,
    val onClick: () -> Unit
)

@Composable
fun ProfileScreen(
    onNavigateToOwnerDashboard: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {},
    onNavigateToAdminAudit: () -> Unit = {},
    onNavigateToSupport: () -> Unit = {},
    onNavigateToPrivacy: () -> Unit = {},
    onNavigateToTerms: () -> Unit = {},
    onNavigateToLogin: () -> Unit = {},
    onNavigateToReferral: () -> Unit = {},
    onNavigateToThemeCustomizer: () -> Unit = {},
    onNavigateToAdminAppSections: () -> Unit = {},
    onNavigateToInstitutesClasses: () -> Unit = {},
    onNavigateToInstituteOwnerDashboard: () -> Unit = {},
    onNavigateToListingFieldsConfig: () -> Unit = {}
) {
    val user by BookMySpaceRepository.authUser.collectAsState()
    val themeMode by BookMySpaceRepository.themeMode.collectAsState()
    val selectedThemePreset by BookMySpaceRepository.selectedThemePreset.collectAsState()
    val isSimpleMode by BookMySpaceRepository.isSimpleMode.collectAsState()
    val isQuickBookingModeEnabled by BookMySpaceRepository.isQuickBookingModeEnabled.collectAsState()
    val userReferralCode by BookMySpaceRepository.userReferralCode.collectAsState()
    val totalReferralCreditsEarned by BookMySpaceRepository.totalReferralCreditsEarned.collectAsState()
    val walletBalance by BookMySpaceRepository.walletBalance.collectAsState()
    val appSections by BookMySpaceRepository.appSections.collectAsState()
    val isInstitutesEnabled = remember(appSections) { BookMySpaceRepository.isSectionEnabled("institutes_classes") }
    val isVenuesOrHotelsEnabled = remember(appSections) { 
        BookMySpaceRepository.isSectionEnabled("venues_halls") || 
        BookMySpaceRepository.isSectionEnabled("hotels_rooms") || 
        BookMySpaceRepository.isSectionEnabled("pg_hostels") || 
        BookMySpaceRepository.isSectionEnabled("coworking_other") 
    }
    var showLanguageDialog by remember { mutableStateOf(false) }
    var showEditProfileModal by remember { mutableStateOf(false) }

    if (showLanguageDialog) {
        LanguageSelectorDialog(onDismiss = { showLanguageDialog = false })
    }

    if (showEditProfileModal && user != null) {
        EditProfileModal(
            user = user!!,
            onDismiss = { showEditProfileModal = false }
        )
    }

    val currentRole by UserRoleProvider.role.collectAsState()
    val dynamicMenuItems = remember(user, currentRole, isInstitutesEnabled, isVenuesOrHotelsEnabled) {
        val allItems = listOf(
            ProfileActionItem(
                id = "institutes_classes",
                title = "Institutes & Classes Directory",
                subtitle = "Find certified coaching, sports academies & batch timings",
                icon = Icons.Default.School,
                targetRoles = setOf(UserRole.USER, UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = isInstitutesEnabled,
                testTag = "profile_institutes_classes_menu_item",
                onClick = onNavigateToInstitutesClasses
            ),
            ProfileActionItem(
                id = "institute_owner",
                title = "Institute Owner Portal",
                subtitle = "Manage academy profile, faculty roster & post class batches",
                icon = Icons.Default.Apartment,
                targetRoles = setOf(UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = isInstitutesEnabled,
                testTag = "profile_institute_owner_menu_item",
                onClick = onNavigateToInstituteOwnerDashboard
            ),
            ProfileActionItem(
                id = "venue_owner",
                title = "Venue Owner Portal & Dashboard",
                subtitle = "Manage listings, pricing, slot availability & incoming bookings",
                icon = Icons.Default.Storefront,
                targetRoles = setOf(UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = isVenuesOrHotelsEnabled,
                testTag = "profile_venue_owner_menu_item",
                onClick = onNavigateToOwnerDashboard
            ),
            ProfileActionItem(
                id = "listing_fields_config",
                title = "Listing Fields Configuration",
                subtitle = "Dynamic schema engine for Venues, Hostels, Institutes & Classes",
                icon = Icons.Default.Tune,
                targetRoles = setOf(UserRole.ADMIN),
                isFeatureEnabled = true,
                testTag = "profile_listing_fields_config_menu_item",
                onClick = onNavigateToListingFieldsConfig
            ),
            ProfileActionItem(
                id = "app_sections_toggles",
                title = "App Sections & Feature Toggles",
                subtitle = "Admin controls: Enable/Disable major sections (Venues, Hotels, PG, Institutes, Courses, Events)",
                icon = Icons.Default.ToggleOn,
                targetRoles = setOf(UserRole.ADMIN),
                isFeatureEnabled = true,
                testTag = "profile_admin_app_sections_menu_item",
                onClick = onNavigateToAdminAppSections
            ),
            ProfileActionItem(
                id = "audit_logs",
                title = "Audit Trail & Activity Logs",
                subtitle = "Audit trail of security events, administrative updates & actions",
                icon = Icons.Default.AdminPanelSettings,
                targetRoles = setOf(UserRole.ADMIN),
                isFeatureEnabled = true,
                testTag = "profile_admin_audit_menu_item",
                onClick = onNavigateToAdminAudit
            ),
            ProfileActionItem(
                id = "analytics",
                title = "Usage Analytics & Spending",
                subtitle = "Track platform activity and booking history spending",
                icon = Icons.Default.Analytics,
                targetRoles = setOf(UserRole.USER, UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = true,
                testTag = "profile_analytics_menu_item",
                onClick = onNavigateToAnalytics
            ),
            ProfileActionItem(
                id = "support",
                title = "Help & Support",
                subtitle = "FAQs, customer support desk & query assistance",
                icon = Icons.Default.HelpOutline,
                targetRoles = setOf(UserRole.USER, UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = true,
                testTag = "profile_support_menu_item",
                onClick = onNavigateToSupport
            )
        )
        UserRoleProvider.filterForRole(
            items = allItems,
            targetRoles = { it.targetRoles },
            isFeatureEnabled = { it.isFeatureEnabled },
            userRole = currentRole
        )
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .testTag("profile_screen"),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // App Header Logo
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                com.bookmyspace.bookmyspace.ui.components.BookMySpaceLogo()
                LanguageSelectorChip(onClick = { showLanguageDialog = true })
            }
        }

        // User Profile Header or Log In Banner
        item {
            if (user != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    AnimatedContent(
                        targetState = Triple(user?.id, user?.fullName, currentRole),
                        transitionSpec = {
                            fadeIn(animationSpec = tween(durationMillis = 350)) togetherWith
                                    fadeOut(animationSpec = tween(durationMillis = 150))
                        },
                        label = "profile_avatar_and_user_info_fade"
                    ) { _ ->
                        Row(
                            modifier = Modifier.padding(20.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(60.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.primary)
                                    .testTag("profile_avatar_image"),
                                contentAlignment = Alignment.Center
                            ) {
                                if (!user?.avatarUrl.isNullOrBlank()) {
                                    AsyncImage(
                                        model = user?.avatarUrl,
                                        contentDescription = "User profile picture",
                                        modifier = Modifier
                                            .fillMaxSize()
                                            .clip(CircleShape),
                                        contentScale = ContentScale.Crop
                                    )
                                } else {
                                    Text(
                                        text = user?.fullName?.take(1)?.uppercase() ?: "U",
                                        fontSize = 24.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.width(16.dp))
                            Column {
                                Text(user?.fullName ?: "Guest User", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(user?.email ?: "customer.dev@bookmyspace.app", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    if (user?.isEmailVerified == true) {
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Icon(
                                            imageVector = Icons.Default.Verified,
                                            contentDescription = "Email Verified",
                                            tint = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(14.dp)
                                        )
                                        Spacer(modifier = Modifier.width(2.dp))
                                        Text("Verified", fontSize = 10.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                                    }
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(8.dp)) {
                                    Text(
                                        text = "Role: ${currentRole.name}",
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            FilledTonalIconButton(
                                onClick = { showEditProfileModal = true },
                                modifier = Modifier.testTag("edit_profile_button")
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Edit,
                                    contentDescription = "Edit Profile"
                                )
                            }
                        }
                    }
                }
            } else {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                ) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            imageVector = Icons.Default.AccountCircle,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Not Signed In", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(
                            "Sign in with your DEV account to manage bookings, list venues, or access admin tools.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = onNavigateToLogin,
                            modifier = Modifier.fillMaxWidth().testTag("profile_login_button"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Login, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Sign In to BookMySpace DEV")
                        }
                    }
                }
            }
        }

        // Quick Role Switcher (For DEV testing)
        if (user != null) {
            item {
                Text("Switch Role (DEV Testing Mode)", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(4.dp))
                Text("Select role to test Customer, Owner, or Admin permissions:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = currentRole == UserRole.USER,
                        onClick = { UserRoleProvider.switchUserRole(UserRole.USER) },
                        label = { Text("Customer") },
                        modifier = Modifier.testTag("role_switch_customer")
                    )
                    FilterChip(
                        selected = currentRole == UserRole.VENUE_OWNER,
                        onClick = { UserRoleProvider.switchUserRole(UserRole.VENUE_OWNER) },
                        label = { Text("Venue Owner") },
                        modifier = Modifier.testTag("role_switch_owner")
                    )
                    FilterChip(
                        selected = currentRole == UserRole.ADMIN,
                        onClick = { UserRoleProvider.switchUserRole(UserRole.ADMIN) },
                        label = { Text("Admin") },
                        modifier = Modifier.testTag("role_switch_admin")
                    )
                }
            }
        }

        // Single Refer a Friend Entry
        item {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onNavigateToReferral() }
                    .testTag("profile_referral_banner_card")
                    .testTag("profile_referral_menu_item"),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
            ) {
                Row(
                    modifier = Modifier.padding(18.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(52.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.CardGiftcard,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(28.dp)
                        )
                    }

                    Spacer(modifier = Modifier.width(14.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("🎁 Refer & Earn ₹500", fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                            Surface(
                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text(
                                    text = "₹${walletBalance.toInt()} Wallet",
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            "Your Code: $userReferralCode • Earned ₹${totalReferralCreditsEarned.toInt()} Credits",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            "Share with friends & get booking discounts!",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                        )
                    }

                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = "Navigate to Referral",
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }

        // Action Menu Items
        item {
            Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
                Column {
                    AnimatedContent(
                        targetState = dynamicMenuItems,
                        transitionSpec = {
                            fadeIn(animationSpec = tween(durationMillis = 300)) togetherWith
                                    fadeOut(animationSpec = tween(durationMillis = 150))
                        },
                        label = "dynamic_menu_items_fade"
                    ) { items ->
                        Column {
                            items.forEach { menuItem ->
                                val itemModifier = if (menuItem.testTag != null) {
                                    Modifier
                                        .clickable { menuItem.onClick() }
                                        .testTag(menuItem.testTag)
                                } else {
                                    Modifier.clickable { menuItem.onClick() }
                                }
                                ListItem(
                                    headlineContent = { Text(menuItem.title, fontWeight = FontWeight.Bold) },
                                    supportingContent = menuItem.subtitle?.let { sub -> { Text(sub, fontSize = 11.sp) } },
                                    leadingContent = {
                                        Icon(
                                            imageVector = menuItem.icon,
                                            contentDescription = null,
                                            tint = menuItem.iconTint ?: MaterialTheme.colorScheme.primary
                                        )
                                    },
                                    modifier = itemModifier
                                )
                                HorizontalDivider()
                            }
                        }
                    }
                    ListItem(
                        headlineContent = { Text("App Language / भाषा") },
                        supportingContent = { Text("Switch regional language for navigation & voice readouts", fontSize = 11.sp) },
                        leadingContent = { Icon(Icons.Default.Language, contentDescription = null) },
                        trailingContent = {
                            LanguageSelectorChip(onClick = { showLanguageDialog = true })
                        },
                        modifier = Modifier.clickable { showLanguageDialog = true }
                    )
                    HorizontalDivider()
                    ListItem(
                        headlineContent = { Text("Elderly / Simple Mode") },
                        supportingContent = { Text("Hides complex filters, enlarged text & 1-tap instant voice/picture booking", fontSize = 11.sp) },
                        leadingContent = { Icon(Icons.Default.AccessibilityNew, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                        trailingContent = {
                            Switch(
                                checked = isSimpleMode,
                                onCheckedChange = { BookMySpaceRepository.toggleSimpleMode() },
                                modifier = Modifier.testTag("simple_mode_switch")
                            )
                        }
                    )
                    HorizontalDivider()
                    ListItem(
                        headlineContent = { Text("Booking Mode Configuration", fontWeight = FontWeight.Bold) },
                        supportingContent = {
                            Text(
                                if (isQuickBookingModeEnabled) "ON: 1-Tap Quick Booking Flow applied globally" else "OFF: Standard Multi-Step Booking Flow active",
                                fontSize = 11.sp
                            )
                        },
                        leadingContent = { Icon(Icons.Default.FlashOn, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary) },
                        trailingContent = {
                            Switch(
                                checked = isQuickBookingModeEnabled,
                                onCheckedChange = { BookMySpaceRepository.setQuickBookingMode(it) },
                                modifier = Modifier.testTag("profile_quick_booking_switch")
                            )
                        }
                    )
                    HorizontalDivider()
                    ListItem(
                        headlineContent = {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Theme & Color Engine", fontWeight = FontWeight.Bold)
                                Surface(
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                    shape = RoundedCornerShape(8.dp)
                                ) {
                                    Text(
                                        text = selectedThemePreset.displayName.take(18) + "...",
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        },
                        supportingContent = {
                            Column {
                                Text(
                                    text = "12 Curated themes, custom hex accent generator, and Light/Dark/System modes:",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Spacer(modifier = Modifier.height(10.dp))
                                SingleChoiceSegmentedButtonRow(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("theme_switcher_segmented_row")
                                ) {
                                    SegmentedButton(
                                        selected = themeMode == com.bookmyspace.bookmyspace.ui.theme.ThemeMode.SYSTEM_DEFAULT,
                                        onClick = { BookMySpaceRepository.setThemeMode(com.bookmyspace.bookmyspace.ui.theme.ThemeMode.SYSTEM_DEFAULT) },
                                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 3),
                                        icon = {
                                            Icon(
                                                imageVector = Icons.Default.BrightnessAuto,
                                                contentDescription = null,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        },
                                        modifier = Modifier.testTag("theme_button_system")
                                    ) {
                                        Text("System", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                    }
                                    SegmentedButton(
                                        selected = themeMode == com.bookmyspace.bookmyspace.ui.theme.ThemeMode.LIGHT,
                                        onClick = { BookMySpaceRepository.setThemeMode(com.bookmyspace.bookmyspace.ui.theme.ThemeMode.LIGHT) },
                                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 3),
                                        icon = {
                                            Icon(
                                                imageVector = Icons.Default.LightMode,
                                                contentDescription = null,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        },
                                        modifier = Modifier.testTag("theme_button_light")
                                    ) {
                                        Text("Light", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                    }
                                    SegmentedButton(
                                        selected = themeMode == com.bookmyspace.bookmyspace.ui.theme.ThemeMode.DARK,
                                        onClick = { BookMySpaceRepository.setThemeMode(com.bookmyspace.bookmyspace.ui.theme.ThemeMode.DARK) },
                                        shape = SegmentedButtonDefaults.itemShape(index = 2, count = 3),
                                        icon = {
                                            Icon(
                                                imageVector = Icons.Default.DarkMode,
                                                contentDescription = null,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        },
                                        modifier = Modifier.testTag("theme_button_dark")
                                    ) {
                                        Text("Dark", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                    }
                                }

                                Spacer(modifier = Modifier.height(10.dp))

                                OutlinedButton(
                                    onClick = onNavigateToThemeCustomizer,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("open_theme_customizer_button"),
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.ColorLens,
                                        contentDescription = null,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text("Explore 12 Themes & Custom Hex Palette", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        },
                        leadingContent = {
                            Icon(
                                imageVector = Icons.Default.Palette,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary
                            )
                        },
                        modifier = Modifier.testTag("theme_switcher_list_item")
                    )
                    HorizontalDivider()
                    ListItem(
                        headlineContent = { Text("Privacy Policy") },
                        modifier = Modifier.clickable { onNavigateToPrivacy() }
                    )
                    HorizontalDivider()
                    ListItem(
                        headlineContent = { Text("Terms of Service") },
                        modifier = Modifier.clickable { onNavigateToTerms() }
                    )
                }
            }
        }

        // Logout or Login Switch Button
        item {
            if (user != null) {
                Button(
                    onClick = {
                        BookMySpaceRepository.logout()
                        onNavigateToLogin()
                    },
                    modifier = Modifier.fillMaxWidth().testTag("logout_button"),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.errorContainer, contentColor = MaterialTheme.colorScheme.onErrorContainer)
                ) {
                    Icon(Icons.Default.Logout, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Log Out")
                }
            } else {
                OutlinedButton(
                    onClick = onNavigateToLogin,
                    modifier = Modifier.fillMaxWidth().testTag("login_redirect_button")
                ) {
                    Icon(Icons.Default.Login, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Log In")
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
    onLoginSuccess: (UserRole) -> Unit
) {
    val pendingVerification by BookMySpaceRepository.pendingVerificationState.collectAsState()
    val pendingPasswordReset by BookMySpaceRepository.pendingPasswordResetState.collectAsState()
    var isSignUpMode by remember { mutableStateOf(false) }
    var isForgotPasswordMode by remember { mutableStateOf(false) }
    var authMethod by remember { mutableStateOf("EMAIL") } // "EMAIL" or "MOBILE"

    // Form states
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var countryCode by remember { mutableStateOf("+91") }
    var mobileNumber by remember { mutableStateOf("") }
    var otpCode by remember { mutableStateOf("") }
    var verificationCodeInput by remember { mutableStateOf("") }
    var resetEmailInput by remember { mutableStateOf("") }
    var resetTokenInput by remember { mutableStateOf("") }
    var newPasswordInput by remember { mutableStateOf("") }
    var confirmNewPasswordInput by remember { mutableStateOf("") }
    var isNewPasswordVisible by remember { mutableStateOf(false) }
    var acceptTerms by remember { mutableStateOf(true) }

    var isPasswordVisible by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var statusNotice by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(false) }

    com.bookmyspace.bookmyspace.util.TraceComposition("LoginScreen")

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (pendingVerification != null) "Verify Email"
                        else if (pendingPasswordReset != null || isForgotPasswordMode) "Forgot Password"
                        else if (isSignUpMode) "Create Account"
                        else "BookMySpace Login",
                        fontWeight = FontWeight.Bold
                    )
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            com.bookmyspace.bookmyspace.ui.components.BookMySpaceLogo(showSubtext = true)

            Spacer(modifier = Modifier.height(16.dp))

            if (pendingVerification != null) {
                // --- EMAIL VERIFICATION FLOW CARD ---
                Card(
                    modifier = Modifier.fillMaxWidth().testTag("email_verification_container"),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Box(
                            modifier = Modifier
                                .size(64.dp)
                                .background(MaterialTheme.colorScheme.primaryContainer, CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.MarkEmailRead,
                                contentDescription = "Email Verification",
                                modifier = Modifier.size(36.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("Verify Your Email Address", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "We sent a 6-digit confirmation code to ${pendingVerification?.email} via Supabase Auth. Enter it below to activate your account.",
                            fontSize = 12.sp,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(10.dp))
                        Surface(
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Security,
                                    contentDescription = null,
                                    modifier = Modifier.size(12.dp),
                                    tint = MaterialTheme.colorScheme.primary
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    "Supabase Auth • SMTP Mailer Sync Active",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        OutlinedTextField(
                            value = verificationCodeInput,
                            onValueChange = { verificationCodeInput = it; errorMessage = null },
                            label = { Text("6-Digit Verification Code") },
                            placeholder = { Text("e.g. 123456") },
                            leadingIcon = { Icon(Icons.Default.Pin, contentDescription = null) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().testTag("email_verification_code_input")
                        )

                        if (errorMessage != null) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(errorMessage ?: "", color = MaterialTheme.colorScheme.error, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.Info, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text("DEV Verification Code Token:", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                    Text(
                                        "Code: ${pendingVerification?.verificationCode} (or enter 123456)",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Button(
                            onClick = {
                                if (verificationCodeInput.isBlank()) {
                                    errorMessage = "Please enter the 6-digit verification code."
                                    return@Button
                                }
                                isLoading = true
                                errorMessage = null
                                val result = BookMySpaceRepository.verifyEmailCode(
                                    emailInput = pendingVerification?.email ?: email,
                                    inputCode = verificationCodeInput
                                )
                                isLoading = false
                                result.fold(
                                    onSuccess = { user ->
                                        onLoginSuccess(user.role)
                                    },
                                    onFailure = { ex ->
                                        errorMessage = ex.message ?: "Invalid verification code."
                                    }
                                )
                            },
                            enabled = !isLoading,
                            modifier = Modifier.fillMaxWidth().height(48.dp).testTag("verify_email_button"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            if (isLoading) {
                                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
                            } else {
                                Text("Verify Email & Activate Account", fontWeight = FontWeight.Bold)
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            TextButton(
                                onClick = {
                                    BookMySpaceRepository.resendVerificationCode(pendingVerification?.email ?: email)
                                    statusNotice = "New verification code dispatched via Supabase Auth SMTP."
                                },
                                modifier = Modifier.testTag("resend_verification_code_button")
                            ) {
                                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Resend Code", fontSize = 12.sp)
                            }

                            TextButton(
                                onClick = {
                                    BookMySpaceRepository.cancelPendingVerification()
                                    errorMessage = null
                                },
                                modifier = Modifier.testTag("cancel_verification_button")
                            ) {
                                Text("Change Email / Back", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                            }
                        }
                    }
                }
            } else if (pendingPasswordReset != null || isForgotPasswordMode) {
                // --- FORGOT / RESET PASSWORD FLOW CARD ---
                Card(
                    modifier = Modifier.fillMaxWidth().testTag("forgot_password_container"),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Box(
                            modifier = Modifier
                                .size(64.dp)
                                .background(MaterialTheme.colorScheme.primaryContainer, CircleShape),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.LockReset,
                                contentDescription = "Reset Password",
                                modifier = Modifier.size(36.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("Reset Your Password", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = if (pendingPasswordReset == null)
                                "Enter your registered email address below. We'll send a password recovery token via Supabase Auth mailer."
                            else
                                "A recovery token was dispatched to ${pendingPasswordReset?.email}. Enter the token and your new password below.",
                            fontSize = 12.sp,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(10.dp))
                        Surface(
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Security,
                                    contentDescription = null,
                                    modifier = Modifier.size(12.dp),
                                    tint = MaterialTheme.colorScheme.primary
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    "Supabase Auth • Password Recovery Mailer Active",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        if (pendingPasswordReset == null) {
                            // STEP 1: REQUEST EMAIL
                            OutlinedTextField(
                                value = resetEmailInput,
                                onValueChange = { resetEmailInput = it; errorMessage = null },
                                label = { Text("Registered Email Address") },
                                placeholder = { Text("e.g. customer@gmail.com") },
                                leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("forgot_password_email_input")
                            )

                            if (errorMessage != null) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(errorMessage ?: "", color = MaterialTheme.colorScheme.error, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            Button(
                                onClick = {
                                    if (resetEmailInput.isBlank()) {
                                        errorMessage = "Please enter your email address."
                                        return@Button
                                    }
                                    isLoading = true
                                    errorMessage = null
                                    val result = BookMySpaceRepository.requestPasswordReset(resetEmailInput)
                                    isLoading = false
                                    result.fold(
                                        onSuccess = { pending ->
                                            statusNotice = "Recovery code dispatched to ${pending.email} via Supabase Auth mailer!"
                                        },
                                        onFailure = { ex ->
                                            errorMessage = ex.message ?: "Failed to send password reset email."
                                        }
                                    )
                                },
                                enabled = !isLoading,
                                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("send_reset_email_button"),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                if (isLoading) {
                                    CircularProgressIndicator(modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
                                } else {
                                    Text("Send Password Reset Email", fontWeight = FontWeight.Bold)
                                }
                            }
                        } else {
                            // STEP 2: VERIFY TOKEN & SET NEW PASSWORD
                            Card(
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier.padding(10.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.Info, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Column {
                                        Text("DEV Password Reset Token:", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                        Text(
                                            "Recovery Code: ${pendingPasswordReset?.resetToken} (or test code 123456)",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            OutlinedTextField(
                                value = resetTokenInput,
                                onValueChange = { resetTokenInput = it; errorMessage = null },
                                label = { Text("6-Digit Recovery Token") },
                                placeholder = { Text("e.g. 123456") },
                                leadingIcon = { Icon(Icons.Default.Pin, contentDescription = null) },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("reset_token_input")
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            OutlinedTextField(
                                value = newPasswordInput,
                                onValueChange = { newPasswordInput = it; errorMessage = null },
                                label = { Text("New Password") },
                                leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null) },
                                trailingIcon = {
                                    IconButton(onClick = { isNewPasswordVisible = !isNewPasswordVisible }) {
                                        Icon(
                                            imageVector = if (isNewPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                            contentDescription = "Toggle New Password Visibility"
                                        )
                                    }
                                },
                                visualTransformation = if (isNewPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("new_password_input")
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            OutlinedTextField(
                                value = confirmNewPasswordInput,
                                onValueChange = { confirmNewPasswordInput = it; errorMessage = null },
                                label = { Text("Confirm New Password") },
                                leadingIcon = { Icon(Icons.Default.LockReset, contentDescription = null) },
                                visualTransformation = PasswordVisualTransformation(),
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("confirm_new_password_input")
                            )

                            if (errorMessage != null) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(errorMessage ?: "", color = MaterialTheme.colorScheme.error, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            Button(
                                onClick = {
                                    if (resetTokenInput.isBlank()) {
                                        errorMessage = "Please enter the recovery token."
                                        return@Button
                                    }
                                    if (newPasswordInput.isBlank()) {
                                        errorMessage = "Please enter a new password."
                                        return@Button
                                    }
                                    if (newPasswordInput != confirmNewPasswordInput) {
                                        errorMessage = "Passwords do not match."
                                        return@Button
                                    }

                                    isLoading = true
                                    errorMessage = null
                                    val result = BookMySpaceRepository.resetPasswordWithToken(
                                        emailInput = pendingPasswordReset?.email ?: resetEmailInput,
                                        tokenInput = resetTokenInput,
                                        newPasswordInput = newPasswordInput
                                    )
                                    isLoading = false
                                    result.fold(
                                        onSuccess = {
                                            statusNotice = "Password reset successfully! Please log in with your new password."
                                            isForgotPasswordMode = false
                                            email = pendingPasswordReset?.email ?: resetEmailInput
                                            password = newPasswordInput
                                        },
                                        onFailure = { ex ->
                                            errorMessage = ex.message ?: "Failed to reset password."
                                        }
                                    )
                                },
                                enabled = !isLoading,
                                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("confirm_reset_password_button"),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                if (isLoading) {
                                    CircularProgressIndicator(modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
                                } else {
                                    Text("Reset Password & Save", fontWeight = FontWeight.Bold)
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        TextButton(
                            onClick = {
                                BookMySpaceRepository.cancelPasswordReset()
                                isForgotPasswordMode = false
                                errorMessage = null
                            },
                            modifier = Modifier.testTag("cancel_forgot_password_button")
                        ) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Back to Login", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                        }
                    }
                }
            } else {
                // --- STANDARD SIGN IN / SIGN UP FORM ---
                Text(
                    text = if (isSignUpMode) "Join BookMySpace" else "Welcome to BookMySpace",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = if (isSignUpMode) "Create your customer account to start booking" else "Sign in to manage your bookings and venues",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(16.dp))

                // Mode Selector: Sign In vs Sign Up
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    SegmentedButton(
                        selected = !isSignUpMode,
                        onClick = {
                            isSignUpMode = false
                            errorMessage = null
                            statusNotice = null
                        },
                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
                    ) {
                        Text("Sign In")
                    }
                    SegmentedButton(
                        selected = isSignUpMode,
                        onClick = {
                            isSignUpMode = true
                            errorMessage = null
                            statusNotice = null
                        },
                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
                    ) {
                        Text("Create Account")
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Auth Method Selector: Email vs Mobile
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    FilterChip(
                        selected = authMethod == "EMAIL",
                        onClick = {
                            authMethod = "EMAIL"
                            errorMessage = null
                            statusNotice = null
                        },
                        label = { Text("Email Address") },
                        leadingIcon = { Icon(Icons.Default.Email, contentDescription = null, modifier = Modifier.size(16.dp)) },
                        modifier = Modifier.weight(1f)
                    )
                    FilterChip(
                        selected = authMethod == "MOBILE",
                        onClick = {
                            authMethod = "MOBILE"
                            errorMessage = null
                            statusNotice = "Mobile OTP provider requires configuration on DEV Supabase (Project: bookmyspace-dev, Ref: zykxneztahxbjduagutv). Status: BLOCKED."
                        },
                        label = { Text("Mobile Number") },
                        leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(16.dp)) },
                        modifier = Modifier.weight(1f)
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Error / Status Notice Banners
                if (errorMessage != null) {
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = MaterialTheme.colorScheme.onErrorContainer)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = errorMessage ?: "",
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }

                if (statusNotice != null) {
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.onTertiaryContainer)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = statusNotice ?: "",
                                color = MaterialTheme.colorScheme.onTertiaryContainer,
                                fontSize = 11.sp,
                                lineHeight = 15.sp
                            )
                        }
                    }
                }

                // FORM FIELDS
                if (authMethod == "EMAIL") {
                    if (isSignUpMode) {
                        OutlinedTextField(
                            value = fullName,
                            onValueChange = { fullName = it; errorMessage = null },
                            label = { Text("Full Name") },
                            leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().testTag("signup_name_input")
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                    }

                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it; errorMessage = null },
                        label = { Text("Email Address") },
                        placeholder = { Text("e.g. user@gmail.com") },
                        leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                        trailingIcon = if (email.isNotEmpty()) {
                            {
                                IconButton(onClick = { email = "" }) {
                                    Icon(Icons.Default.Clear, contentDescription = "Clear email")
                                }
                            }
                        } else null,
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().testTag("email_input")
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Start,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Person, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = if (isSignUpMode) "Supabase Auth sends a 6-digit confirmation email upon registration." else "Real-time email login signs in strictly as a Customer.",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Spacer(modifier = Modifier.height(10.dp))

                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it; errorMessage = null },
                        label = { Text("Password") },
                        leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null) },
                        trailingIcon = {
                            IconButton(onClick = { isPasswordVisible = !isPasswordVisible }) {
                                Icon(
                                    imageVector = if (isPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                    contentDescription = "Toggle Password Visibility"
                                )
                            }
                        },
                        visualTransformation = if (isPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().testTag("password_input")
                    )

                    if (!isSignUpMode) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            TextButton(
                                onClick = {
                                    isForgotPasswordMode = true
                                    resetEmailInput = email
                                    errorMessage = null
                                    statusNotice = null
                                },
                                modifier = Modifier.testTag("forgot_password_button")
                            ) {
                                Text(
                                    text = "Forgot Password?",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }

                    if (isSignUpMode) {
                        Spacer(modifier = Modifier.height(10.dp))
                        OutlinedTextField(
                            value = confirmPassword,
                            onValueChange = { confirmPassword = it; errorMessage = null },
                            label = { Text("Confirm Password") },
                            leadingIcon = { Icon(Icons.Default.LockReset, contentDescription = null) },
                            visualTransformation = PasswordVisualTransformation(),
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().testTag("confirm_password_input")
                        )
                    }
                } else {
                    // MOBILE FORM
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = countryCode,
                            onValueChange = { countryCode = it },
                            label = { Text("Code") },
                            singleLine = true,
                            modifier = Modifier.width(85.dp)
                        )
                        OutlinedTextField(
                            value = mobileNumber,
                            onValueChange = { mobileNumber = it },
                            label = { Text("Mobile Number") },
                            leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
                            singleLine = true,
                            modifier = Modifier.weight(1f).testTag("mobile_number_input")
                        )
                    }

                    if (isSignUpMode) {
                        Spacer(modifier = Modifier.height(10.dp))
                        OutlinedTextField(
                            value = fullName,
                            onValueChange = { fullName = it },
                            label = { Text("Full Name") },
                            leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }

                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = otpCode,
                        onValueChange = { otpCode = it },
                        label = { Text("OTP Code (6 digits)") },
                        leadingIcon = { Icon(Icons.Default.Pin, contentDescription = null) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().testTag("otp_input")
                    )
                }

                if (isSignUpMode) {
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Checkbox(
                            checked = acceptTerms,
                            onCheckedChange = { acceptTerms = it },
                            modifier = Modifier.testTag("accept_terms_checkbox")
                        )
                        Text("I accept the Terms of Service & Privacy Policy", fontSize = 12.sp)
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Button(
                    onClick = {
                        com.bookmyspace.bookmyspace.util.PerformanceTracer.traceBlock("registration_login_workflow") {
                            if (authMethod == "MOBILE") {
                                errorMessage = "Mobile OTP authentication status: BLOCKED. Provider SMS is not enabled on bookmyspace-dev backend. Please use Email login/signup."
                                return@traceBlock
                            }

                            if (isSignUpMode) {
                                if (fullName.isBlank()) {
                                    errorMessage = "Please enter your full name."
                                    return@traceBlock
                                }
                                if (password != confirmPassword) {
                                    errorMessage = "Passwords do not match."
                                    return@traceBlock
                                }
                                if (!acceptTerms) {
                                    errorMessage = "You must accept the terms to create an account."
                                    return@traceBlock
                                }

                                isLoading = true
                                errorMessage = null
                                val result = BookMySpaceRepository.registerUserWithEmailVerification(
                                    fullNameInput = fullName,
                                    emailInput = email,
                                    passwordInput = password
                                )
                                isLoading = false
                                result.fold(
                                    onSuccess = { pending ->
                                        statusNotice = "Verification code dispatched to ${pending.email} via Supabase Auth mailer!"
                                    },
                                    onFailure = { ex ->
                                        errorMessage = ex.message ?: "Registration failed."
                                    }
                                )
                            } else {
                                isLoading = true
                                errorMessage = null
                                val result = BookMySpaceRepository.loginWithEmailAndPassword(email, password)
                                isLoading = false
                                result.fold(
                                    onSuccess = { user -> onLoginSuccess(user.role) },
                                    onFailure = { ex -> errorMessage = ex.message ?: "Authentication failed" }
                                )
                            }
                        }
                    },
                    enabled = !isLoading,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .testTag("auth_submit_button"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp), color = MaterialTheme.colorScheme.onPrimary)
                    } else {
                        Text(
                            text = if (isSignUpMode) "Register with Email Verification" else "Sign In as Customer",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    HorizontalDivider(modifier = Modifier.weight(1f))
                    Text(
                        text = " OR ",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                    HorizontalDivider(modifier = Modifier.weight(1f))
                }

                Spacer(modifier = Modifier.height(14.dp))

                OutlinedButton(
                    onClick = {
                        com.bookmyspace.bookmyspace.util.PerformanceTracer.traceBlock("google_sign_in_workflow") {
                            isLoading = true
                            errorMessage = null
                            val result = BookMySpaceRepository.loginWithGoogle(emailHint = email)
                            isLoading = false
                            result.fold(
                                onSuccess = { user -> onLoginSuccess(user.role) },
                                onFailure = { ex -> errorMessage = ex.message ?: "Google sign-in failed" }
                            )
                        }
                    },
                    enabled = !isLoading,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .testTag("google_sign_in_button"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = MaterialTheme.colorScheme.surface
                    ),
                    border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
                ) {
                    Icon(
                        imageVector = Icons.Default.AccountCircle,
                        contentDescription = "Google Logo",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = if (isSignUpMode) "Sign Up with Google (Supabase Auth)" else "Continue with Google (Supabase Auth)",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(16.dp))

            Text("DEV Test Quick Logins", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.height(4.dp))
            Text("Click to log in as pre-verified DEV account:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.height(12.dp))

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedButton(
                    onClick = {
                        val result = BookMySpaceRepository.quickLogin(UserRole.USER)
                        result.getOrNull()?.let { user -> onLoginSuccess(user.role) }
                    },
                    modifier = Modifier.fillMaxWidth().testTag("quick_login_customer"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Person, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Column(horizontalAlignment = Alignment.Start, modifier = Modifier.weight(1f)) {
                        Text("Customer Test Login", fontWeight = FontWeight.Bold)
                        Text("customer.dev@bookmyspace.app", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                OutlinedButton(
                    onClick = {
                        val result = BookMySpaceRepository.quickLogin(UserRole.VENUE_OWNER)
                        result.getOrNull()?.let { user -> onLoginSuccess(user.role) }
                    },
                    modifier = Modifier.fillMaxWidth().testTag("quick_login_owner"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Storefront, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Column(horizontalAlignment = Alignment.Start, modifier = Modifier.weight(1f)) {
                        Text("Owner Test Login", fontWeight = FontWeight.Bold)
                        Text("owner.dev@bookmyspace.app", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                OutlinedButton(
                    onClick = {
                        val result = BookMySpaceRepository.quickLogin(UserRole.ADMIN)
                        result.getOrNull()?.let { user -> onLoginSuccess(user.role) }
                    },
                    modifier = Modifier.fillMaxWidth().testTag("quick_login_admin"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.AdminPanelSettings, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Column(horizontalAlignment = Alignment.Start, modifier = Modifier.weight(1f)) {
                        Text("Admin Test Login", fontWeight = FontWeight.Bold)
                        Text("admin.dev@bookmyspace.app", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrivacyPolicyScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Privacy Policy", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(20.dp)
        ) {
            item {
                Text("Privacy Policy for BookMySpace", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    "At BookMySpace, we take your privacy seriously. We collect essential information such as email address, booking history, and venue preferences to facilitate court and turf reservations. Your data is encrypted and never sold to third parties.",
                    lineHeight = 20.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TermsOfServiceScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Terms of Service", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(20.dp)
        ) {
            item {
                Text("Terms of Service", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    "By using BookMySpace, you agree to adhere to venue rules, respect time slots, and follow safety guidelines. Cancellations made at least 2 hours before slot start time are eligible for a full refund.",
                    lineHeight = 20.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

val PRESET_PROFILE_AVATARS = listOf(
    "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&auto=format&fit=crop&q=80"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditProfileModal(
    user: com.bookmyspace.bookmyspace.data.model.AuthUser,
    onDismiss: () -> Unit
) {
    var fullName by remember { mutableStateOf(user.fullName) }
    var avatarUrl by remember { mutableStateOf(user.avatarUrl) }
    var isCustomUrlMode by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var successMessage by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = { if (!isSaving) onDismiss() },
        title = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Edit Profile",
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp
                )
                IconButton(onClick = onDismiss, enabled = !isSaving) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Live Avatar Preview Circle
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary)
                        .clickable { isCustomUrlMode = !isCustomUrlMode },
                    contentAlignment = Alignment.Center
                ) {
                    if (avatarUrl.isNotBlank()) {
                        AsyncImage(
                            model = avatarUrl,
                            contentDescription = "Avatar preview",
                            modifier = Modifier
                                .fillMaxSize()
                                .clip(CircleShape),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Text(
                            text = fullName.take(1).ifBlank { "U" }.uppercase(),
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "Tap avatar or choose a preset below",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Full Name Input
                OutlinedTextField(
                    value = fullName,
                    onValueChange = {
                        fullName = it
                        errorMessage = null
                    },
                    label = { Text("Display Name") },
                    placeholder = { Text("Enter your full name") },
                    leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("profile_edit_name_input"),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Preset Avatars Picker
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Preset Avatars",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 13.sp
                    )
                    TextButton(
                        onClick = { isCustomUrlMode = !isCustomUrlMode }
                    ) {
                        Text(
                            text = if (isCustomUrlMode) "Hide URL" else "Custom URL",
                            fontSize = 12.sp
                        )
                    }
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    PRESET_PROFILE_AVATARS.take(4).forEach { url ->
                        val isSelected = avatarUrl == url
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isSelected) MaterialTheme.colorScheme.primaryContainer
                                    else MaterialTheme.colorScheme.surfaceVariant
                                )
                                .clickable { avatarUrl = url }
                                .padding(if (isSelected) 2.dp else 0.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            AsyncImage(
                                model = url,
                                contentDescription = "Preset avatar",
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(CircleShape),
                                contentScale = ContentScale.Crop
                            )
                        }
                    }
                }

                if (isCustomUrlMode) {
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = avatarUrl,
                        onValueChange = { avatarUrl = it },
                        label = { Text("Avatar Image URL") },
                        placeholder = { Text("https://example.com/photo.jpg") },
                        leadingIcon = { Icon(Icons.Default.Image, contentDescription = null) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("profile_edit_avatar_url_input"),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                }

                if (errorMessage != null) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = errorMessage!!,
                        color = MaterialTheme.colorScheme.error,
                        fontSize = 12.sp
                    )
                }

                if (successMessage != null) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = successMessage!!,
                        color = Color(0xFF2E7D32),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (fullName.trim().isEmpty()) {
                        errorMessage = "Display name cannot be empty"
                        return@Button
                    }
                    isSaving = true
                    val success = BookMySpaceRepository.updateProfile(
                        fullName = fullName,
                        avatarUrl = avatarUrl
                    )
                    isSaving = false
                    if (success) {
                        successMessage = "Profile updated directly in Supabase!"
                        onDismiss()
                    } else {
                        errorMessage = "Failed to update profile"
                    }
                },
                modifier = Modifier.testTag("profile_edit_save_button"),
                shape = RoundedCornerShape(10.dp),
                enabled = !isSaving
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                } else {
                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Save Changes")
                }
            }
        },
        dismissButton = {
            TextButton(
                onClick = onDismiss,
                enabled = !isSaving
            ) {
                Text("Cancel")
            }
        },
        shape = RoundedCornerShape(20.dp)
    )
}
