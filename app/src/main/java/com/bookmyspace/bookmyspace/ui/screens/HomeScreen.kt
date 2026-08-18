package com.bookmyspace.bookmyspace.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.CustomerSection
import com.bookmyspace.bookmyspace.data.model.CustomerSectionCatalog
import com.bookmyspace.bookmyspace.data.model.LocationHierarchy
import com.bookmyspace.bookmyspace.data.model.LocationSearchRadius
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchyHeaderBar
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchySelectorDialog
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.AmenityFilterOption
import com.bookmyspace.bookmyspace.ui.components.BookMySpaceLogo
import com.bookmyspace.bookmyspace.ui.components.EasyVoiceBookingBanner
import com.bookmyspace.bookmyspace.ui.components.EasyVoiceBookingDialog
import com.bookmyspace.bookmyspace.ui.components.LanguageSelectorChip
import com.bookmyspace.bookmyspace.ui.components.LanguageSelectorDialog
import com.bookmyspace.bookmyspace.ui.components.QuickBookCard
import com.bookmyspace.bookmyspace.ui.components.ResponsiveLayout
import com.bookmyspace.bookmyspace.ui.components.ResponsiveDimensions
import com.bookmyspace.bookmyspace.ui.components.responsiveGridItems
import com.bookmyspace.bookmyspace.ui.components.VenueFilterBottomSheet
import com.bookmyspace.bookmyspace.util.LocalizedStrings
import com.bookmyspace.bookmyspace.util.PerformanceTracer
import com.bookmyspace.bookmyspace.util.TraceCategory
import com.bookmyspace.bookmyspace.util.VenueImageResolver

data class QuickFilterChip(
    val id: String,
    val label: String,
    val emoji: String
)

/**
 * 4 Primary Main Sections of BookMySpace Customer Experience
 */
enum class MainHomeSection(
    val id: String,
    val title: String,
    val subtitle: String,
    val emoji: String,
    val imageUrl: String,
    val adminSectionKey: String,
    val categoryOptions: List<MainSectionCategoryOption>
) {
    FUNCTION_HALLS(
        id = "function_halls",
        title = "Function Halls",
        subtitle = "Marriage, Convention, Party, Community & Govt Halls",
        emoji = "🏛️",
        imageUrl = "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "venues_function_halls",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All Halls", "✨"),
            MainSectionCategoryOption("marriage_hall", "Marriage Hall", "💒", "Weddings & Receptions"),
            MainSectionCategoryOption("convention_center", "Convention Hall", "🏛️", "Summits & Conferences"),
            MainSectionCategoryOption("banquet_hall", "Party Hall / Banquet", "🍸", "Birthdays & Dinners"),
            MainSectionCategoryOption("community_hall", "Community Hall", "🤝", "Family & Society Meets"),
            MainSectionCategoryOption("govt_hall", "Government Hall", "🏢", "Official & Public Town Halls"),
            MainSectionCategoryOption("party_lawn", "Open Lawn Ground", "🌳", "Outdoor Weddings & Lawns")
        )
    ),
    LODGE_ROOMS(
        id = "lodge_rooms",
        title = "Lodge / Rooms",
        subtitle = "Hotels, Lodges, Guest Houses & Day Rooms",
        emoji = "🏨",
        imageUrl = "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "hotels_rooms",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All Stays", "✨"),
            MainSectionCategoryOption("hotel", "Hotel", "🏨", "Luxury & Star Stays"),
            MainSectionCategoryOption("lodge", "Lodge", "🛏️", "Budget & Short-stay Lodges"),
            MainSectionCategoryOption("guest_house", "Guest House", "🏡", "Quiet & Homely Guest Rooms"),
            MainSectionCategoryOption("hourly_room", "Hourly / Day Room", "⏱️", "Short Stay & Day Use"),
            MainSectionCategoryOption("resort", "Resort / Homestay", "🌴", "Getaways & Nature Stays")
        )
    ),
    PG_HOSTELS(
        id = "pg_hostels",
        title = "PG / Hostels",
        subtitle = "Gents PG, Ladies PG, Hostels & Co-living",
        emoji = "🏠",
        imageUrl = "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "pg_hostels",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All PG & Hostels", "✨"),
            MainSectionCategoryOption("gents_pg", "Gents PG", "👨", "Men's Stays with Food & WiFi"),
            MainSectionCategoryOption("ladies_pg", "Ladies PG", "👩", "Women's Safe Secure Stays"),
            MainSectionCategoryOption("student_hostel", "Student Hostel", "🎒", "College & Academy Hostels"),
            MainSectionCategoryOption("co_living", "Co-living Spaces", "🤝", "Modern Shared Living"),
            MainSectionCategoryOption("single_room", "Single Sharing Room", "🔑", "Private & Shared Rooms")
        )
    ),
    INSTITUTES_CLASSES(
        id = "institutes_classes",
        title = "Institutes / Classes",
        subtitle = "Coaching, Tuition, Computer, Dance, Music & Sports",
        emoji = "🎓",
        imageUrl = "https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800&auto=format&fit=crop&q=80",
        adminSectionKey = "institutes_classes",
        categoryOptions = listOf(
            MainSectionCategoryOption("all", "All Classes", "✨"),
            MainSectionCategoryOption("coaching", "Coaching & Tuition", "📚", "School, College & Prep"),
            MainSectionCategoryOption("computer_it", "Computer & IT Classes", "💻", "Coding, AI & Digital Skills"),
            MainSectionCategoryOption("dance_academy", "Dance Academy", "💃", "Classical, Western & Zumba"),
            MainSectionCategoryOption("music_class", "Music & Singing", "🎵", "Guitar, Keyboard & Vocals"),
            MainSectionCategoryOption("sports_academy", "Sports Academy & Turfs", "🏸", "Badminton, Cricket & Fitness")
        )
    )
}

data class MainSectionCategoryOption(
    val id: String,
    val label: String,
    val emoji: String,
    val description: String = ""
)

fun MainHomeSection.toCustomerSection(): CustomerSection {
    return CustomerSection.fromId(id) ?: CustomerSection.FUNCTION_HALLS
}

fun CustomerSection.toMainHomeSection(): MainHomeSection? {
    return MainHomeSection.values().find { it.id == id }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun HomeScreen(
    onNavigateToVenue: (String) -> Unit,
    onNavigateToSearch: (String?) -> Unit,
    onNavigateToEvents: () -> Unit,
    onNavigateToCourses: () -> Unit,
    onNavigateToNotifications: () -> Unit,
    onNavigateToInstitutes: () -> Unit = {},
    onNavigateToQrScanner: () -> Unit = {},
    onNavigateToLogin: () -> Unit = {},
    onNavigateToProfile: () -> Unit = {},
    onNavigateToMap: () -> Unit = {},
    initialSelectedSection: MainHomeSection? = null,
    sharedTransitionScope: SharedTransitionScope? = null,
    animatedVisibilityScope: AnimatedVisibilityScope? = null
) {
    val context = LocalContext.current
    val venues by BookMySpaceRepository.venues.collectAsState()
    val institutes by BookMySpaceRepository.institutes.collectAsState()
    val instituteClasses by BookMySpaceRepository.instituteClasses.collectAsState()
    val user by BookMySpaceRepository.authUser.collectAsState()
    val notifications by BookMySpaceRepository.notifications.collectAsState()
    val unreadNotifs by remember(notifications) {
        derivedStateOf { notifications.count { !it.isRead } }
    }

    val userLocationHierarchy by BookMySpaceRepository.userLocationHierarchy.collectAsState()
    val userLocationRadius by BookMySpaceRepository.userLocationRadius.collectAsState()
    val appSections by BookMySpaceRepository.appSections.collectAsState()
    val repoSection by BookMySpaceRepository.selectedCustomerSection.collectAsState()
    val repoCategorySlug by BookMySpaceRepository.selectedCustomerCategorySlug.collectAsState()

    // Display ONLY the enabled 4 main section cards (governed by Admin feature toggles)
    val availableSections = remember(appSections) {
        MainHomeSection.values().filter { section ->
            BookMySpaceRepository.isSectionEnabled(section.adminSectionKey)
        }
    }

    // Tests can seed a section via initialSelectedSection; otherwise repository is source of truth.
    LaunchedEffect(initialSelectedSection) {
        if (initialSelectedSection != null && repoSection == null) {
            BookMySpaceRepository.setSelectedCustomerSection(initialSelectedSection.toCustomerSection())
        }
    }

    val selectedMainSection = repoSection?.toMainHomeSection() ?: initialSelectedSection
    val selectedCategorySlug = if (selectedMainSection == null) "all" else repoCategorySlug

    var showLocationDialog by remember { mutableStateOf(false) }
    var showEasyVoiceBookingDialog by remember { mutableStateOf(false) }
    var showLanguageDialog by remember { mutableStateOf(false) }

    // Amenity and Advanced Filters State
    var selectedAmenityFilters by remember { mutableStateOf(setOf<String>()) }
    var showVenueFilterSheet by remember { mutableStateOf(false) }
    var filterMinPrice by remember { mutableFloatStateOf(0f) }
    var filterMaxPrice by remember { mutableFloatStateOf(500000f) }
    var filterMinRating by remember { mutableFloatStateOf(0f) }

    val homeAmenityFilterOptions = remember(selectedMainSection) {
        val section = selectedMainSection?.toCustomerSection() ?: return@remember emptyList()
        CustomerSectionCatalog.amenityFilters(section).map { spec ->
            AmenityFilterOption(spec.id, spec.label, spec.emoji, spec.keywords)
        }
    }

    val filteredInstitutes = remember(institutes, selectedMainSection, selectedCategorySlug) {
        if (selectedMainSection != MainHomeSection.INSTITUTES_CLASSES) emptyList()
        else institutes.filter { CustomerSectionCatalog.matchesInstitute(it, selectedCategorySlug) }
    }

    // Filter venues for currently selected main section and category
    val filteredVenues = remember(
        venues,
        selectedMainSection,
        selectedCategorySlug,
        selectedAmenityFilters,
        filterMinPrice,
        filterMaxPrice,
        filterMinRating,
        userLocationHierarchy,
        homeAmenityFilterOptions
    ) {
        if (selectedMainSection == null) return@remember emptyList<Venue>()

        PerformanceTracer.traceSection("FilterHomeScreenVenues", TraceCategory.DATA_FETCH) {
            val catalogSection = selectedMainSection.toCustomerSection()
            val list = venues.map { v ->
                val vLat = v.locationHierarchy?.latitude ?: v.latitude
                val vLng = v.locationHierarchy?.longitude ?: v.longitude
                val calculatedDist = if (vLat != 0.0 && vLng != 0.0 && userLocationHierarchy.latitude != 0.0) {
                    IndiaLocationMasterData.calculateDistanceKm(userLocationHierarchy.latitude, userLocationHierarchy.longitude, vLat, vLng)
                } else v.distanceKm

                v.copy(distanceKm = calculatedDist)
            }.filter { v ->
                if (!CustomerSectionCatalog.matchesVenue(v, catalogSection, selectedCategorySlug)) {
                    return@filter false
                }

                val name = v.name.lowercase()
                val desc = v.description.lowercase()

                val matchesAmenities = if (selectedAmenityFilters.isEmpty()) {
                    true
                } else {
                    selectedAmenityFilters.all { amenityId ->
                        val option = homeAmenityFilterOptions.find { it.id == amenityId }
                        if (option == null) true
                        else {
                            val facList = v.facilities.map { it.facility.lowercase() }
                            val food = v.foodOptions.lowercase()
                            val rules = v.rules.lowercase()
                            val combinedFacilitiesText = "$desc $food $rules $name " + facList.joinToString(" ")
                            val hasParking = (amenityId == "parking" && (v.parkingCapacity > 0 || combinedFacilitiesText.contains("parking") || combinedFacilitiesText.contains("valet")))
                            val hasRooms = (amenityId == "rooms" && (v.hotelDetails != null || v.facilities.any { it.facility.contains("Room", ignoreCase = true) || it.facility.contains("Suite", ignoreCase = true) }))

                            hasParking || hasRooms || option.keywords.any { kw ->
                                v.facilities.any { f -> f.facility.contains(kw, ignoreCase = true) && f.isAvailable } ||
                                combinedFacilitiesText.contains(kw)
                            }
                        }
                    }
                }

                val matchesPrice = v.pricingBaseAmount in filterMinPrice..filterMaxPrice
                val matchesRating = filterMinRating == 0f || v.avgRating >= filterMinRating

                matchesAmenities && matchesPrice && matchesRating
            }

            list.sortedWith(
                compareBy<Venue> { v ->
                    val isExactArea = userLocationHierarchy.areaId != null && v.locationHierarchy?.areaId == userLocationHierarchy.areaId
                    val isSameCity = v.locationHierarchy?.cityTownId == userLocationHierarchy.cityTownId || v.city.equals(userLocationHierarchy.cityTownName, ignoreCase = true)
                    val isSameDistrict = v.locationHierarchy?.districtId == userLocationHierarchy.districtId
                    val isSameState = v.locationHierarchy?.stateId == userLocationHierarchy.stateId

                    when {
                        isExactArea -> 0
                        isSameCity -> 1
                        isSameDistrict -> 2
                        isSameState -> 3
                        else -> 4
                    }
                }.thenBy { it.distanceKm }
            )
        }
    }

    if (showLocationDialog) {
        LocationHierarchySelectorDialog(
            currentLocation = userLocationHierarchy,
            currentRadius = userLocationRadius,
            onLocationSelected = { loc, radius ->
                BookMySpaceRepository.setUserLocationHierarchy(loc, radius)
                showLocationDialog = false
            },
            onDismiss = { showLocationDialog = false }
        )
    }

    if (showEasyVoiceBookingDialog) {
        EasyVoiceBookingDialog(
            onDismiss = { showEasyVoiceBookingDialog = false },
            onNavigateToVenue = onNavigateToVenue
        )
    }

    if (showLanguageDialog) {
        LanguageSelectorDialog(
            onDismiss = { showLanguageDialog = false }
        )
    }

    if (showVenueFilterSheet) {
        VenueFilterBottomSheet(
            initialMinPrice = filterMinPrice,
            initialMaxPrice = filterMaxPrice,
            initialMinRating = filterMinRating,
            initialSelectedAmenities = selectedAmenityFilters,
            maxPriceLimit = 250000f,
            matchingVenuesCount = filteredVenues.size,
            onDismissRequest = { showVenueFilterSheet = false },
            onApplyFilters = { minP, maxP, minR, amenities ->
                filterMinPrice = minP
                filterMaxPrice = maxP
                filterMinRating = minR
                selectedAmenityFilters = amenities
                showVenueFilterSheet = false
            },
            onResetFilters = {
                filterMinPrice = 0f
                filterMaxPrice = 500000f
                filterMinRating = 0f
                selectedAmenityFilters = emptySet()
                showVenueFilterSheet = false
            }
        )
    }

    ResponsiveLayout(
        modifier = Modifier.testTag("home_responsive_container")
    ) { responsiveInfo ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .testTag("home_screen"),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            // =====================================================================
            // TOP APP BAR (Shared across First Screen & Section Views)
            // =====================================================================
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = responsiveInfo.horizontalPadding, vertical = 12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        BookMySpaceLogo()

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            LanguageSelectorChip(onClick = { showLanguageDialog = true })

                            if (user == null) {
                                FilledTonalButton(
                                    onClick = onNavigateToLogin,
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                    shape = RoundedCornerShape(20.dp),
                                    modifier = Modifier
                                        .defaultMinSize(minHeight = 48.dp)
                                        .testTag("header_login_button")
                                ) {
                                    Icon(Icons.Default.Login, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Sign In", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                                }
                            } else {
                                Surface(
                                    onClick = onNavigateToProfile,
                                    shape = CircleShape,
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                    modifier = Modifier
                                        .size(48.dp)
                                        .testTag("header_user_avatar")
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Text(
                                            text = user?.fullName?.take(1)?.uppercase() ?: "U",
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                                            fontSize = 16.sp
                                        )
                                    }
                                }
                            }

                            IconButton(
                                onClick = onNavigateToQrScanner,
                                modifier = Modifier
                                    .size(48.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.surfaceVariant)
                                    .testTag("home_topbar_qr_scanner_btn")
                            ) {
                                Icon(
                                    imageVector = Icons.Default.QrCodeScanner,
                                    contentDescription = "QR Check-In",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(22.dp)
                                )
                            }

                            BadgedBox(
                                badge = {
                                    if (unreadNotifs > 0) {
                                        Badge { Text("$unreadNotifs") }
                                    }
                                }
                            ) {
                                IconButton(
                                    onClick = onNavigateToNotifications,
                                    modifier = Modifier
                                        .size(48.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.surfaceVariant)
                                        .testTag("home_topbar_notifications_btn")
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Notifications,
                                        contentDescription = "Notifications",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(22.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // =====================================================================
            // 🌟 FIRST SCREEN: EXACTLY 4 MAIN SECTIONS ONLY (RESPONSIVE GRID)
            // =====================================================================
            if (selectedMainSection == null) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = responsiveInfo.horizontalPadding)
                    ) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Book Your Space",
                            fontSize = if (responsiveInfo.isTabletOrWide) 30.sp else 26.sp,
                            fontWeight = FontWeight.Black,
                            color = MaterialTheme.colorScheme.onBackground,
                            letterSpacing = (-0.5).sp
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Select what you are looking for to get started:",
                            fontSize = if (responsiveInfo.isTabletOrWide) 15.sp else 14.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            lineHeight = 20.sp
                        )
                        Spacer(modifier = Modifier.height(20.dp))
                    }
                }

                responsiveGridItems(
                    items = availableSections,
                    columns = responsiveInfo.categoryGridColumns,
                    key = { it.id },
                    horizontalSpacing = responsiveInfo.gridSpacing,
                    verticalSpacing = responsiveInfo.gridSpacing,
                    contentPadding = PaddingValues(horizontal = responsiveInfo.horizontalPadding)
                ) { section, _ ->
                    MainSectionBigHeroCard(
                        section = section,
                        onClick = {
                            BookMySpaceRepository.setSelectedCustomerSection(section.toCustomerSection())
                        },
                        isTabletOrWide = responsiveInfo.isTabletOrWide,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Subtle Location info footer at the bottom of first screen
                item {
                    Spacer(modifier = Modifier.height(20.dp))
                    Surface(
                        onClick = { showLocationDialog = true },
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = responsiveInfo.horizontalPadding)
                            .testTag("home_first_screen_location_chip")
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("📍", fontSize = 18.sp)
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text(
                                        text = "Current City: ${userLocationHierarchy.shortLabel}",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "Tap to change search area (${userLocationRadius.displayName})",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            Icon(
                                imageVector = Icons.Default.EditLocation,
                                contentDescription = "Change Location",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            } else {
            // =====================================================================
            // 🚀 SECTION DRILL-DOWN: Category Index -> Location -> AI Search -> Results
            // =====================================================================
            val activeSection = selectedMainSection!!

            // Section Header Bar with Back button
            item {
                Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        OutlinedButton(
                            onClick = {
                                BookMySpaceRepository.clearSelectedCustomerSection()
                            },
                            shape = RoundedCornerShape(16.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                            modifier = Modifier
                                .defaultMinSize(minHeight = 48.dp)
                                .testTag("btn_back_to_main_sections")
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back",
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("All Spaces", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        }

                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(activeSection.emoji, fontSize = 16.sp)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = activeSection.title,
                                    fontWeight = FontWeight.ExtraBold,
                                    fontSize = 13.sp,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    Text(
                        text = "${activeSection.emoji} ${activeSection.title}",
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Black,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Text(
                        text = activeSection.subtitle,
                        fontSize = 12.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Location Header Bar
                    LocationHierarchyHeaderBar(
                        currentLocation = userLocationHierarchy,
                        selectedRadius = userLocationRadius,
                        onClick = { showLocationDialog = true }
                    )

                    Spacer(modifier = Modifier.height(12.dp))
                }
            }

            // 1. Relevant Index / Sub-Categories (Horizontal row of cards)
            item {
                Column(modifier = Modifier.padding(top = 4.dp)) {
                    Text(
                        text = "Choose Category",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(horizontal = 20.dp)
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 20.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.testTag("section_category_options_row")
                    ) {
                        items(activeSection.categoryOptions, key = { it.id }) { cat ->
                            val isSelected = selectedCategorySlug == cat.id
                            FilterChip(
                                selected = isSelected,
                                onClick = { BookMySpaceRepository.setSelectedCustomerCategory(cat.id) },
                                label = {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.padding(vertical = 6.dp)
                                    ) {
                                        Text(cat.emoji, fontSize = 16.sp)
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = cat.label,
                                            fontSize = 13.sp,
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                                        )
                                    }
                                },
                                leadingIcon = if (isSelected) {
                                    {
                                        Icon(
                                            imageVector = Icons.Default.Check,
                                            contentDescription = "Selected",
                                            modifier = Modifier.size(14.dp)
                                        )
                                    }
                                } else null,
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
                                    selectedLeadingIconColor = MaterialTheme.colorScheme.onPrimary
                                ),
                                shape = RoundedCornerShape(16.dp),
                                modifier = Modifier
                                    .defaultMinSize(minHeight = 48.dp)
                                    .minimumInteractiveComponentSize()
                                    .testTag("section_category_chip_${cat.id}")
                            )
                        }
                    }
                }
            }

            // 2. AI Search & Voice Booking & 1-Tap Booking Inside Section
            item {
                Spacer(modifier = Modifier.height(14.dp))
                Column(modifier = Modifier.padding(horizontal = 20.dp)) {
                    // Search Bar Box
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                BookMySpaceRepository.setSelectedCustomerCategory(selectedCategorySlug)
                                onNavigateToSearch(if (selectedCategorySlug == "all") activeSection.id else selectedCategorySlug)
                            }
                            .testTag("home_search_bar_box"),
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                        shadowElevation = 0.5.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Search,
                                    contentDescription = "Search",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = "Search ${activeSection.title} in ${userLocationHierarchy.shortLabel}...",
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontSize = 13.5.sp,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.primaryContainer,
                                modifier = Modifier.size(32.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.Default.Tune,
                                        contentDescription = "Filter",
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // 🎙️ Bol-ke-Book Voice-Search Banner
                    EasyVoiceBookingBanner(
                        onClick = { showEasyVoiceBookingDialog = true },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    // ⚡ Quick Book Preferences Card (1-Tap Mode)
                    QuickBookCard(
                        onNavigateToVenue = onNavigateToVenue,
                        onAiHelpClick = { showEasyVoiceBookingDialog = true },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            // 3. Amenity Filter Chips Row & Filter Action
            item {
                Spacer(modifier = Modifier.height(14.dp))
                Column(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Filters & Amenities",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            if (selectedAmenityFilters.isNotEmpty()) {
                                Spacer(modifier = Modifier.width(6.dp))
                                Surface(
                                    shape = CircleShape,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(20.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Text(
                                            text = "${selectedAmenityFilters.size}",
                                            color = Color.White,
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }
                            }
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (selectedAmenityFilters.isNotEmpty() || filterMinRating > 0f) {
                                TextButton(
                                    onClick = {
                                        selectedAmenityFilters = emptySet()
                                        filterMinRating = 0f
                                        filterMinPrice = 0f
                                        filterMaxPrice = 500000f
                                    },
                                    contentPadding = PaddingValues(horizontal = 8.dp)
                                ) {
                                    Text("Reset", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                            }

                            FilledTonalIconButton(
                                onClick = { showVenueFilterSheet = true },
                                modifier = Modifier
                                    .size(36.dp)
                                    .testTag("home_open_filter_bottom_sheet_btn")
                            ) {
                                Icon(
                                    imageVector = Icons.Default.FilterList,
                                    contentDescription = "Open Filters",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 20.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.testTag("home_amenity_filter_chips_row")
                    ) {
                        items(homeAmenityFilterOptions, key = { it.id }) { option ->
                            val isSelected = selectedAmenityFilters.contains(option.id)
                            FilterChip(
                                selected = isSelected,
                                onClick = {
                                    selectedAmenityFilters = if (isSelected) {
                                        selectedAmenityFilters - option.id
                                    } else {
                                        selectedAmenityFilters + option.id
                                    }
                                },
                                label = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(option.iconEmoji, fontSize = 13.sp)
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(option.label, fontSize = 12.sp)
                                    }
                                },
                                leadingIcon = if (isSelected) {
                                    {
                                        Icon(
                                            imageVector = Icons.Default.Check,
                                            contentDescription = "Selected",
                                            modifier = Modifier.size(14.dp)
                                        )
                                    }
                                } else null,
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
                                    selectedLeadingIconColor = MaterialTheme.colorScheme.onPrimary
                                ),
                                shape = RoundedCornerShape(16.dp),
                                modifier = Modifier
                                    .defaultMinSize(minHeight = 44.dp)
                                    .minimumInteractiveComponentSize()
                                    .testTag("amenity_filter_chip_${option.id}")
                            )
                        }
                    }
                }
            }

            // 4. Institutes / Classes Module Special Section
            if (activeSection == MainHomeSection.INSTITUTES_CLASSES && filteredInstitutes.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Featured Institutes & Academies",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        TextButton(
                            onClick = onNavigateToInstitutes,
                            contentPadding = PaddingValues(horizontal = 6.dp)
                        ) {
                            Text("View All (${filteredInstitutes.size}) →", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                    Spacer(modifier = Modifier.height(6.dp))

                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 20.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(filteredInstitutes, key = { it.id }) { inst ->
                            Surface(
                                onClick = onNavigateToInstitutes,
                                shape = RoundedCornerShape(16.dp),
                                color = MaterialTheme.colorScheme.surface,
                                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                                shadowElevation = 1.dp,
                                modifier = Modifier.width(240.dp)
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    AsyncImage(
                                        model = inst.logoUrl.ifBlank { inst.imageUrls.firstOrNull() },
                                        contentDescription = inst.name,
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(110.dp)
                                            .clip(RoundedCornerShape(12.dp))
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(
                                        text = inst.name,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 13.5.sp,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = inst.address + ", " + inst.city,
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            text = "${inst.facultyMembers.size} Certified Faculty",
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.primary,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                        Text(
                                            text = "Explore →",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5. Results List: Venues / Spaces Matching Current Section & Filters
            item {
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Available Spaces (${filteredVenues.size})",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Text(
                        text = "Sorted by Distance",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            if (filteredVenues.isEmpty()) {
                item {
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 16.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text("🔍", fontSize = 32.sp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "No spaces found with current filters",
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Try resetting filters or expanding search radius from ${userLocationRadius.displayName}.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Button(
                                onClick = {
                                    BookMySpaceRepository.setSelectedCustomerCategory("all")
                                    selectedAmenityFilters = emptySet()
                                    filterMinRating = 0f
                                    filterMinPrice = 0f
                                    filterMaxPrice = 500000f
                                },
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text("Show All in ${activeSection.title}")
                            }
                        }
                    }
                }
            } else {
                responsiveGridItems(
                    items = filteredVenues,
                    columns = responsiveInfo.resultsGridColumns,
                    key = { it.id },
                    horizontalSpacing = responsiveInfo.gridSpacing,
                    verticalSpacing = 12.dp,
                    contentPadding = PaddingValues(horizontal = responsiveInfo.horizontalPadding)
                ) { venue, _ ->
                    SectionVenueResultCard(
                        venue = venue,
                        onClick = { onNavigateToVenue(venue.id) },
                        onCallClick = {
                            val phone = venue.contactPhone.ifBlank { "+919876543210" }
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                            try { context.startActivity(intent) } catch (e: Exception) { e.printStackTrace() }
                        },
                        onWhatsAppClick = {
                            val phone = venue.contactPhone.filter { it.isDigit() }.ifBlank { "919876543210" }
                            val url = "https://wa.me/$phone?text=Hi, I am interested in booking ${venue.name} on BookMySpace."
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            try { context.startActivity(intent) } catch (e: Exception) { e.printStackTrace() }
                        },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}
}

/**
 * Large, eye-catching, extremely simple Hero Card for the 4 Main Sections on the first screen.
 * Adapts responsively on phone single-column vs tablet grid layouts.
 */
@Composable
fun MainSectionBigHeroCard(
    section: MainHomeSection,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isTabletOrWide: Boolean = false
) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(if (isTabletOrWide) 24.dp else 22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = if (isTabletOrWide) 130.dp else 115.dp)
            .testTag("main_section_card_${section.id}")
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(if (isTabletOrWide) 140.dp else 125.dp)
        ) {
            // Background Image
            AsyncImage(
                model = section.imageUrl,
                contentDescription = section.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )

            // High-contrast gradient overlay to ensure text readability in any lighting
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(
                                Color.Black.copy(alpha = 0.90f),
                                Color.Black.copy(alpha = 0.74f),
                                Color.Black.copy(alpha = 0.35f)
                            )
                        )
                    )
            )

            // Card Content
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = if (isTabletOrWide) 20.dp else 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    // Prominent Emoji Badge
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = Color.White.copy(alpha = 0.22f),
                        modifier = Modifier.size(if (isTabletOrWide) 60.dp else 56.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = section.emoji,
                                fontSize = if (isTabletOrWide) 30.sp else 28.sp
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(if (isTabletOrWide) 18.dp else 16.dp))

                    Column {
                        Text(
                            text = section.title,
                            fontSize = if (isTabletOrWide) 20.sp else 19.sp,
                            fontWeight = FontWeight.Black,
                            color = Color.White,
                            letterSpacing = (-0.3).sp
                        )
                        Spacer(modifier = Modifier.height(3.dp))
                        Text(
                            text = section.subtitle,
                            fontSize = if (isTabletOrWide) 13.sp else 12.sp,
                            color = Color.White.copy(alpha = 0.85f),
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            lineHeight = 16.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.width(10.dp))

                // Large Touch Target Circular Arrow Button
                Surface(
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(if (isTabletOrWide) 48.dp else 44.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = "Explore ${section.title}",
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.size(if (isTabletOrWide) 22.dp else 20.dp)
                        )
                    }
                }
            }
        }
    }
}

/**
 * Result Card for the Section Detail list with direct Book, Call, and WhatsApp actions.
 */
@Composable
fun SectionVenueResultCard(
    venue: Venue,
    onClick: () -> Unit,
    onCallClick: () -> Unit,
    onWhatsAppClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val coverUrl = remember(venue) { VenueImageResolver.resolveCoverImage(venue) }

    Card(
        onClick = onClick,
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("section_venue_card_${venue.id}")
    ) {
        Column {
            // Cover Image Banner with Overlays
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(130.dp)
            ) {
                AsyncImage(
                    model = coverUrl,
                    contentDescription = venue.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                // Gradient
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.35f),
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.65f)
                                )
                            )
                        )
                )

                // Category pill on top left
                venue.category?.let { cat ->
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.95f),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier
                            .padding(8.dp)
                            .align(Alignment.TopStart)
                    ) {
                        Text(
                            text = cat.name,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    }
                }

                // Rating badge on bottom left
                Surface(
                    color = Color.Black.copy(alpha = 0.7f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .padding(8.dp)
                        .align(Alignment.BottomStart)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = null,
                            tint = Color(0xFFFFB300),
                            modifier = Modifier.size(13.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = String.format(java.util.Locale.US, "%.1f", venue.avgRating),
                            color = Color.White,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                // Distance Badge on bottom right
                Surface(
                    color = Color.Black.copy(alpha = 0.7f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .padding(8.dp)
                        .align(Alignment.BottomEnd)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.NearMe,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(11.dp)
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = "${String.format(java.util.Locale.US, "%.1f", venue.distanceKm)} km away",
                            color = Color.White,
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            // Body Details
            Column(modifier = Modifier.padding(14.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Top
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = venue.name,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.LocationOn,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = venue.city.ifBlank { venue.addressLine1 },
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "₹${venue.pricingBaseAmount.toInt()}",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Black,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = "starts from",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Key Facilities pills
                if (venue.facilities.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        venue.facilities.take(3).forEach { fac ->
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
                            ) {
                                Text(
                                    text = "• ${fac.facility}",
                                    fontSize = 10.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                Spacer(modifier = Modifier.height(10.dp))

                // Action Buttons: Details, Call, WhatsApp
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        onClick = onClick,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .weight(1f)
                            .height(42.dp)
                            .testTag("book_space_btn_${venue.id}")
                    ) {
                        Text("Book Now", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }

                    OutlinedIconButton(
                        onClick = onCallClick,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .size(42.dp)
                            .testTag("call_space_btn_${venue.id}")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Phone,
                            contentDescription = "Call Venue",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        )
                    }

                    FilledTonalIconButton(
                        onClick = onWhatsAppClick,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .size(42.dp)
                            .testTag("whatsapp_space_btn_${venue.id}")
                    ) {
                        Text("💬", fontSize = 16.sp)
                    }
                }
            }
        }
    }
}


