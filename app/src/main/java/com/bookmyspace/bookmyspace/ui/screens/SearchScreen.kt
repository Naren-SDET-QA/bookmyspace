package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import com.bookmyspace.bookmyspace.data.model.LocationHierarchy
import com.bookmyspace.bookmyspace.data.model.LocationSearchRadius
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchySelectorDialog
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchyHeaderBar
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.model.VenueSortBy
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.BookMySpaceLogo
import com.bookmyspace.bookmyspace.ui.components.VenueFilterBottomSheet
import com.bookmyspace.bookmyspace.ui.components.EasyVoiceBookingDialog
import com.bookmyspace.bookmyspace.ui.components.RealMapViewComponent
import com.bookmyspace.bookmyspace.ui.components.VenueCard
import com.bookmyspace.bookmyspace.ui.components.VenueListSkeleton
import com.bookmyspace.bookmyspace.ui.components.VenueMapSkeleton
import kotlinx.coroutines.launch

data class AmenityFilterOption(
    val id: String,
    val label: String,
    val icon: ImageVector,
    val keywords: List<String>
)

val defaultAmenityOptions = listOf(
    AmenityFilterOption("parking", "Car Parking & Valet", Icons.Default.DirectionsCar, listOf("parking", "valet", "car")),
    AmenityFilterOption("wifi", "Wi-Fi / Internet", Icons.Default.Wifi, listOf("wifi", "wi-fi", "internet", "fiber")),
    AmenityFilterOption("changing_rooms", "Changing Rooms & Showers", Icons.Default.MeetingRoom, listOf("changing", "shower", "washroom", "restroom", "dressing", "locker", "bath")),
    AmenityFilterOption("ac", "Air Conditioning", Icons.Default.AcUnit, listOf("ac", "air conditioning", "centralized ac", "cooling")),
    AmenityFilterOption("catering", "In-house Catering & Food", Icons.Default.Restaurant, listOf("catering", "kitchen", "food", "dining", "meal", "buffet")),
    AmenityFilterOption("stage_sound", "Stage & Audio/LED", Icons.Default.VolumeUp, listOf("stage", "sound", "led screen", "audio", "dj")),
    AmenityFilterOption("power_backup", "100% Power Backup", Icons.Default.Bolt, listOf("power backup", "generator", "electricity")),
    AmenityFilterOption("rooms", "Guest AC Rooms", Icons.Default.Bed, listOf("room", "suite", "bridal", "stay", "deluxe")),
    AmenityFilterOption("pool", "Swimming Pool", Icons.Default.Pool, listOf("pool", "swimming")),
    AmenityFilterOption("lawn", "Lawn / Outdoor", Icons.Default.Park, listOf("lawn", "outdoor", "garden", "terrace")),
    AmenityFilterOption("elevator", "Elevator & Access", Icons.Default.Elevator, listOf("elevator", "lift", "wheelchair")),
    AmenityFilterOption("alcohol", "Alcohol License", Icons.Default.LocalBar, listOf("alcohol", "bar", "license")),
    AmenityFilterOption("security", "Security & CCTV", Icons.Default.Shield, listOf("security", "cctv", "gate"))
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class, ExperimentalSharedTransitionApi::class)
@Composable
fun SearchScreen(
    initialCategorySlug: String? = null,
    onNavigateToVenue: (String) -> Unit,
    sharedTransitionScope: SharedTransitionScope? = null,
    animatedVisibilityScope: AnimatedVisibilityScope? = null
) {
    val venues by BookMySpaceRepository.venues.collectAsState()
    val isSimpleMode by BookMySpaceRepository.isSimpleMode.collectAsState()
    val appSections by BookMySpaceRepository.appSections.collectAsState()
    val recentSearches by BookMySpaceRepository.recentSearches.collectAsState()
    val recentlyViewedVenueIds by BookMySpaceRepository.recentlyViewedVenueIds.collectAsState()
    val recentlyViewedVenues = remember(recentlyViewedVenueIds, venues) {
        recentlyViewedVenueIds.mapNotNull { id -> venues.find { it.id == id } }
    }
    var searchQuery by remember { mutableStateOf("") }
    
    // Determine initial property type and category slug from incoming section parameter
    val computedInitialType = remember(initialCategorySlug) {
        when (initialCategorySlug?.lowercase()) {
            "hotel_stay", "hotels_rooms", "hotel" -> "HOTEL"
            "pg_hostel", "pg_hostels", "pg" -> "PG"
            "function_hall", "banquet_hall", "marriage_hall", "party_lawn", "convention_center", "venues_function_halls", "meeting_room", "coworking_other" -> "VENUE"
            else -> "ALL"
        }
    }
    val computedInitialCategory = remember(initialCategorySlug) {
        when (initialCategorySlug?.lowercase()) {
            "hotels_rooms" -> "hotel_stay"
            "pg_hostels" -> "pg_hostel"
            "venues_function_halls" -> "function_hall"
            "coworking_other" -> "meeting_room"
            else -> initialCategorySlug
        }
    }

    // Filter Drawer States
    var selectedPropertyType by remember { mutableStateOf(computedInitialType) } // "ALL", "VENUE", "PG", "HOTEL"
    var selectedCategorySlug by remember { mutableStateOf(computedInitialCategory) }
    var selectedPgType by remember { mutableStateOf<String?>(null) }
    var selectedSharingType by remember { mutableStateOf<String?>(null) }
    var selectedStarRating by remember { mutableStateOf<Int?>(null) }
    var selectedHotelRoomType by remember { mutableStateOf<String?>(null) }

    val userLocationHierarchy by BookMySpaceRepository.userLocationHierarchy.collectAsState()
    val userLocationRadius by BookMySpaceRepository.userLocationRadius.collectAsState()
    var showLocationDialog by remember { mutableStateOf(false) }

    // Price Range Filter State
    var minPrice by remember { mutableFloatStateOf(0f) }
    var maxPrice by remember { mutableFloatStateOf(500000f) }

    // Rating & Distance Filter States
    var minRatingThreshold by remember { mutableFloatStateOf(0f) }
    var maxDistanceRadius by remember { mutableFloatStateOf(50f) } // 50f means Any Distance
    var useLocationServices by remember { mutableStateOf(true) }

    // Capacity Filter State
    var minCapacity by remember { mutableIntStateOf(0) }
    var maxCapacity by remember { mutableIntStateOf(3000) }

    // Amenities Filter State
    var selectedAmenities by remember { mutableStateOf(setOf<String>()) }

    // Sort order & View toggle
    var selectedSort by remember { mutableStateOf(VenueSortBy.RELEVANCE) }
    var isMapView by remember { mutableStateOf(false) }
    var selectedMapVenueId by remember { mutableStateOf<String?>(null) }

    var showFilterSheet by remember { mutableStateOf(false) }
    var showEasyVoiceBookingDialog by remember { mutableStateOf(false) }

    val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val activeFilterCount by remember {
        derivedStateOf {
            var count = 0
            if (selectedPropertyType != "ALL") count++
            if (selectedCategorySlug != null) count++
            if (minPrice > 0f || maxPrice < 500000f) count++
            if (minCapacity > 0 || maxCapacity < 3000) count++
            if (selectedAmenities.isNotEmpty()) count += selectedAmenities.size
            if (selectedPgType != null) count++
            if (selectedSharingType != null) count++
            if (selectedStarRating != null) count++
            if (selectedHotelRoomType != null) count++
            if (minRatingThreshold > 0f) count++
            if (maxDistanceRadius < 50f) count++
            if (!useLocationServices) count++
            count
        }
    }

    val isVenuesSectionEnabled = remember(appSections) { BookMySpaceRepository.isSectionEnabled("venues_halls") }
    val isHotelsSectionEnabled = remember(appSections) { BookMySpaceRepository.isSectionEnabled("hotels_rooms") }
    val isPgSectionEnabled = remember(appSections) { BookMySpaceRepository.isSectionEnabled("pg_hostels") }

    val filteredVenues = remember(venues, searchQuery, selectedPropertyType, selectedCategorySlug, minPrice, maxPrice, minRatingThreshold, maxDistanceRadius, useLocationServices, minCapacity, maxCapacity, selectedAmenities, selectedPgType, selectedSharingType, selectedStarRating, selectedHotelRoomType, selectedSort, userLocationHierarchy, userLocationRadius, appSections) {
        val list = venues.map { v ->
            val vLat = v.locationHierarchy?.latitude ?: v.latitude
            val vLng = v.locationHierarchy?.longitude ?: v.longitude
            val calculatedDist = if (vLat != 0.0 && vLng != 0.0 && userLocationHierarchy.latitude != 0.0) {
                IndiaLocationMasterData.calculateDistanceKm(userLocationHierarchy.latitude, userLocationHierarchy.longitude, vLat, vLng)
            } else v.distanceKm
            v.copy(distanceKm = calculatedDist)
        }.filter { v ->
                // Section Toggle Filter
                val catSlug = v.category?.slug ?: "venue"
                if (!BookMySpaceRepository.isCategoryEnabled(catSlug)) {
                    return@filter false
                }

                // Search Query Matching
                val matchesQuery = searchQuery.isBlank() ||
                    v.name.contains(searchQuery, ignoreCase = true) ||
                    v.city.contains(searchQuery, ignoreCase = true) ||
                    v.addressLine1.contains(searchQuery, ignoreCase = true) ||
                    (v.locationHierarchy?.districtName?.contains(searchQuery, ignoreCase = true) == true) ||
                    (v.locationHierarchy?.mandalName?.contains(searchQuery, ignoreCase = true) == true) ||
                    (v.locationHierarchy?.areaName?.contains(searchQuery, ignoreCase = true) == true) ||
                    (v.category?.name?.contains(searchQuery, ignoreCase = true) == true) ||
                    (v.pgDetails?.pgType?.contains(searchQuery, ignoreCase = true) == true)

                // Property Type Matching
                val matchesPropType = when (selectedPropertyType) {
                    "VENUE" -> v.pgDetails == null && v.hotelDetails == null
                    "PG" -> v.pgDetails != null || v.category?.slug == "pg_hostel"
                    "HOTEL" -> v.hotelDetails != null || v.category?.slug == "hotel_stay"
                    else -> true
                }

                // Category Matching
                val matchesCategory = selectedCategorySlug == null || v.category?.slug == selectedCategorySlug

                // Price Range Filter
                val matchesPrice = v.pricingBaseAmount >= minPrice && v.pricingBaseAmount <= maxPrice

                // Rating Threshold Filter
                val matchesRating = minRatingThreshold == 0f || v.avgRating >= minRatingThreshold

                // Distance Radius Filter
                val matchesDistance = !useLocationServices || maxDistanceRadius >= 50f || v.distanceKm <= maxDistanceRadius

                // Capacity Filter
                val matchesCapacity = v.maxGuests >= minCapacity && (maxCapacity >= 3000 || v.minGuests <= maxCapacity)

                // Amenities Filter
                val matchesAmenities = selectedAmenities.isEmpty() || selectedAmenities.all { amenityId ->
                    val option = defaultAmenityOptions.find { it.id == amenityId }
                    if (option == null) true
                    else {
                        option.keywords.any { kw ->
                            v.facilities.any { f -> f.facility.contains(kw, ignoreCase = true) && f.isAvailable } ||
                                v.description.contains(kw, ignoreCase = true) ||
                                v.foodOptions.contains(kw, ignoreCase = true) ||
                                v.rules.contains(kw, ignoreCase = true) ||
                                v.name.contains(kw, ignoreCase = true)
                        }
                    }
                }

                // PG Specific Filters
                val matchesPgType = selectedPgType == null || (v.pgDetails != null && v.pgDetails!!.pgType.contains(selectedPgType!!, ignoreCase = true))
                val matchesSharing = selectedSharingType == null || (v.pgDetails != null && v.pgDetails!!.sharingOptions.any { opt -> opt.typeName.contains(selectedSharingType!!, ignoreCase = true) })

                // Hotel Specific Filters
                val matchesStarRating = selectedStarRating == null || (v.hotelDetails != null && v.hotelDetails!!.starRating >= selectedStarRating!!)
                val matchesHotelRoom = selectedHotelRoomType == null || (v.hotelDetails != null && v.hotelDetails!!.roomTypes.any { rt -> rt.contains(selectedHotelRoomType!!, ignoreCase = true) })

                matchesQuery && matchesPropType && matchesCategory && matchesPrice &&
                    matchesRating && matchesDistance && matchesCapacity && matchesAmenities &&
                    matchesPgType && matchesSharing && matchesStarRating && matchesHotelRoom
            }

            when (selectedSort) {
                VenueSortBy.PRICE_LOW_HIGH -> list.sortedBy { it.pricingBaseAmount }
                VenueSortBy.PRICE_HIGH_LOW -> list.sortedByDescending { it.pricingBaseAmount }
                VenueSortBy.RATING -> list.sortedByDescending { it.avgRating }
                VenueSortBy.DISTANCE -> list.sortedBy { it.distanceKm }
                VenueSortBy.RELEVANCE -> {
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
        }

    fun resetAllFilters() {
        selectedPropertyType = "ALL"
        selectedCategorySlug = null
        selectedPgType = null
        selectedSharingType = null
        selectedStarRating = null
        selectedHotelRoomType = null
        minPrice = 0f
        maxPrice = 500000f
        minRatingThreshold = 0f
        maxDistanceRadius = 50f
        useLocationServices = true
        minCapacity = 0
        maxCapacity = 3000
        selectedAmenities = emptySet()
        selectedSort = VenueSortBy.RELEVANCE
    }

    // Filter Drawer Content Composable
    @Composable
    fun FilterDrawerContent(
        onCloseDrawer: () -> Unit
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight()
                .width(360.dp)
                .background(MaterialTheme.colorScheme.surface)
                .testTag("filter_drawer_container")
        ) {
            // Header
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.secondary)
                        )
                    )
                    .padding(horizontal = 20.dp, vertical = 18.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            shape = CircleShape,
                            color = Color.White.copy(alpha = 0.2f),
                            modifier = Modifier.size(36.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Default.FilterList,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "Filter Venues",
                                fontWeight = FontWeight.Bold,
                                fontSize = 18.sp,
                                color = Color.White
                            )
                            if (activeFilterCount > 0) {
                                Text(
                                    text = "$activeFilterCount active filters",
                                    fontSize = 11.sp,
                                    color = Color.White.copy(alpha = 0.8f)
                                )
                            }
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (activeFilterCount > 0) {
                            TextButton(
                                onClick = { resetAllFilters() },
                                modifier = Modifier.testTag("reset_filter_drawer_btn")
                            ) {
                                Text("Reset", color = Color(0xFFFECACA), fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                        }
                        IconButton(
                            onClick = onCloseDrawer,
                            modifier = Modifier.testTag("close_filter_drawer_btn")
                        ) {
                            Icon(Icons.Default.Close, contentDescription = "Close Drawer", tint = Color.White)
                        }
                    }
                }
            }

            // Scrollable Content
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp)
            ) {
                // 1. PROPERTY TYPE
                Text(text = "🏢 Property Type", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    listOf(
                        "ALL" to "All",
                        "VENUE" to "Venues",
                        "PG" to "PG / Co-living",
                        "HOTEL" to "Hotels"
                    ).forEach { (typeKey, typeLabel) ->
                        FilterChip(
                            selected = selectedPropertyType == typeKey,
                            onClick = { selectedPropertyType = typeKey },
                            label = { Text(typeLabel, fontSize = 11.sp, fontWeight = if (selectedPropertyType == typeKey) FontWeight.Bold else FontWeight.Normal) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(16.dp))

                // 2. LOCATION SERVICES & DISTANCE RADIUS FILTER
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.MyLocation, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Column {
                            Text(text = "Location & Distance Radius", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(
                                text = if (useLocationServices) "GPS Active • Radius ${if (maxDistanceRadius >= 50f) "Any Distance" else "${maxDistanceRadius.toInt()} km"}" else "GPS Distance Filter Off",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    Switch(
                        checked = useLocationServices,
                        onCheckedChange = { useLocationServices = it },
                        modifier = Modifier.testTag("location_services_switch")
                    )
                }

                if (useLocationServices) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Surface(
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.GpsFixed, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Device Location: 17.3850° N, 78.4866° E (Core City)",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Max Distance Radius:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.primaryContainer
                        ) {
                            Text(
                                text = if (maxDistanceRadius >= 50f) "Any Distance" else "Within ${maxDistanceRadius.toInt()} km",
                                fontWeight = FontWeight.ExtraBold,
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                            )
                        }
                    }
                    Slider(
                        value = maxDistanceRadius,
                        onValueChange = { maxDistanceRadius = it },
                        valueRange = 1f..50f,
                        steps = 48,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("distance_radius_slider")
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        listOf(2f to "2 km", 5f to "5 km", 10f to "10 km", 25f to "25 km", 50f to "50+ km").forEach { (rad, label) ->
                            FilterChip(
                                selected = maxDistanceRadius == rad,
                                onClick = { maxDistanceRadius = rad },
                                label = { Text(label, fontSize = 10.sp) },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(16.dp))

                // 3. RATING THRESHOLD FILTER
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFEAB308), modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(text = "Minimum Guest Rating", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                    if (minRatingThreshold > 0f) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = Color(0xFFFEF08A)
                        ) {
                            Text(
                                text = "%.1f+ ★ Rating".format(minRatingThreshold),
                                fontWeight = FontWeight.ExtraBold,
                                fontSize = 11.sp,
                                color = Color(0xFF854D0E),
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    listOf(0f to "Any Rating", 3.5f to "3.5+ ★", 4.0f to "4.0+ ★", 4.5f to "4.5+ ★").forEach { (thresh, label) ->
                        FilterChip(
                            selected = minRatingThreshold == thresh,
                            onClick = { minRatingThreshold = thresh },
                            label = { Text(label, fontSize = 11.sp, fontWeight = if (minRatingThreshold == thresh) FontWeight.Bold else FontWeight.Normal) },
                            leadingIcon = {
                                if (thresh > 0f) {
                                    Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFEAB308), modifier = Modifier.size(14.dp))
                                }
                            },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("rating_chip_${thresh.toInt()}")
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(16.dp))

                // 4. PRICE RANGE FILTER
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.AttachMoney, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(text = "Price Range", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Text(
                            text = "₹%,d – ₹%,d".format(minPrice.toInt(), maxPrice.toInt()),
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))
                RangeSlider(
                    value = minPrice..maxPrice,
                    onValueChange = { range ->
                        minPrice = range.start
                        maxPrice = range.endInclusive
                    },
                    valueRange = 0f..500000f,
                    steps = 19,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("drawer_price_range_slider")
                )

                // Price Presets
                Text("Quick Price Presets:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    item {
                        FilterChip(
                            selected = minPrice == 0f && maxPrice == 25000f,
                            onClick = { minPrice = 0f; maxPrice = 25000f },
                            label = { Text("Under ₹25k", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minPrice == 25000f && maxPrice == 100000f,
                            onClick = { minPrice = 25000f; maxPrice = 100000f },
                            label = { Text("₹25k – ₹1L", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minPrice == 100000f && maxPrice == 250000f,
                            onClick = { minPrice = 100000f; maxPrice = 250000f },
                            label = { Text("₹1L – ₹2.5L", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minPrice == 250000f && maxPrice == 500000f,
                            onClick = { minPrice = 250000f; maxPrice = 500000f },
                            label = { Text("₹2.5L+", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minPrice == 0f && maxPrice == 500000f,
                            onClick = { minPrice = 0f; maxPrice = 500000f },
                            label = { Text("Any Price", fontSize = 10.sp) }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(16.dp))

                // 3. GUEST CAPACITY FILTER
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Group, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(text = "Guest Capacity", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = MaterialTheme.colorScheme.secondaryContainer
                    ) {
                        Text(
                            text = "%d – %s Guests".format(minCapacity, if (maxCapacity >= 3000) "3,000+" else maxCapacity.toString()),
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))
                RangeSlider(
                    value = minCapacity.toFloat()..maxCapacity.toFloat(),
                    onValueChange = { range ->
                        minCapacity = range.start.toInt()
                        maxCapacity = range.endInclusive.toInt()
                    },
                    valueRange = 0f..3000f,
                    steps = 29,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("capacity_range_slider")
                )

                // Capacity Presets
                Text("Quick Capacity Presets:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    item {
                        FilterChip(
                            selected = minCapacity == 0 && maxCapacity == 100,
                            onClick = { minCapacity = 0; maxCapacity = 100 },
                            label = { Text("Up to 100", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minCapacity == 100 && maxCapacity == 500,
                            onClick = { minCapacity = 100; maxCapacity = 500 },
                            label = { Text("100 – 500", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minCapacity == 500 && maxCapacity == 1000,
                            onClick = { minCapacity = 500; maxCapacity = 1000 },
                            label = { Text("500 – 1,000", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minCapacity == 1000 && maxCapacity == 3000,
                            onClick = { minCapacity = 1000; maxCapacity = 3000 },
                            label = { Text("1,000+ Guests", fontSize = 10.sp) }
                        )
                    }
                    item {
                        FilterChip(
                            selected = minCapacity == 0 && maxCapacity == 3000,
                            onClick = { minCapacity = 0; maxCapacity = 3000 },
                            label = { Text("Any Capacity", fontSize = 10.sp) }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(16.dp))

                // 4. AMENITIES & FACILITIES FILTER
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "✨ Amenities & Features", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    if (selectedAmenities.isNotEmpty()) {
                        TextButton(onClick = { selectedAmenities = emptySet() }) {
                            Text("Clear (${selectedAmenities.size})", fontSize = 11.sp, color = MaterialTheme.colorScheme.error)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))

                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("amenities_chip_group")
                ) {
                    defaultAmenityOptions.forEach { amenity ->
                        val isSelected = selectedAmenities.contains(amenity.id)
                        FilterChip(
                            selected = isSelected,
                            onClick = {
                                selectedAmenities = if (isSelected) {
                                    selectedAmenities - amenity.id
                                } else {
                                    selectedAmenities + amenity.id
                                }
                            },
                            label = { Text(amenity.label, fontSize = 11.sp) },
                            leadingIcon = {
                                Icon(
                                    imageVector = if (isSelected) Icons.Default.Check else amenity.icon,
                                    contentDescription = null,
                                    modifier = Modifier.size(14.dp)
                                )
                            },
                            modifier = Modifier.testTag("drawer_amenity_chip_${amenity.id}")
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(16.dp))

                // 5. PG & HOTEL OPTIONS (Conditional)
                if (selectedPropertyType == "PG" || selectedPropertyType == "ALL") {
                    Text(text = "🛏️ PG & Co-Living Options", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(text = "Occupancy / Tenant Gender:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("Gents", "Ladies", "Co-living").forEach { pgOpt ->
                            FilterChip(
                                selected = selectedPgType == pgOpt,
                                onClick = { selectedPgType = if (selectedPgType == pgOpt) null else pgOpt },
                                label = { Text(pgOpt, fontSize = 11.sp) }
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(text = "Room Sharing Option:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("Single" to "Single Room", "Twin" to "Twin Sharing", "Triple" to "Triple Sharing").forEach { (key, label) ->
                            FilterChip(
                                selected = selectedSharingType == key,
                                onClick = { selectedSharingType = if (selectedSharingType == key) null else key },
                                label = { Text(label, fontSize = 11.sp) }
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                }

                if (selectedPropertyType == "HOTEL" || selectedPropertyType == "ALL") {
                    Text(text = "⭐ Hotel Star Rating & Stay Options", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(3 to "3★ Standard", 4 to "4★ Luxury", 5 to "5★ Premium").forEach { (stars, label) ->
                            FilterChip(
                                selected = selectedStarRating == stars,
                                onClick = { selectedStarRating = if (selectedStarRating == stars) null else stars },
                                label = { Text(label, fontSize = 11.sp) }
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                }

                // 6. SORT ORDER
                Text(text = "🔄 Sort Spaces By", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(6.dp))
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    listOf(
                        VenueSortBy.RELEVANCE to "Popularity & Relevance",
                        VenueSortBy.PRICE_LOW_HIGH to "Price: Low to High",
                        VenueSortBy.PRICE_HIGH_LOW to "Price: High to Low",
                        VenueSortBy.RATING to "Highest Guest Rating",
                        VenueSortBy.DISTANCE to "Distance: Nearest First"
                    ).forEach { (sortKey, sortLabel) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedSort = sortKey }
                                .padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = selectedSort == sortKey,
                                onClick = { selectedSort = sortKey }
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(text = sortLabel, fontSize = 12.sp, fontWeight = if (selectedSort == sortKey) FontWeight.Bold else FontWeight.Normal)
                        }
                    }
                }
            }

            HorizontalDivider()

            // Footer Apply Button
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Button(
                    onClick = onCloseDrawer,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .testTag("apply_filter_drawer_btn"),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Apply Filters (${filteredVenues.size} Spaces Found)",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }
            }
        }
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        gesturesEnabled = drawerState.isOpen,
        drawerContent = {
            ModalDrawerSheet {
                FilterDrawerContent(
                    onCloseDrawer = {
                        scope.launch { drawerState.close() }
                        showFilterSheet = false
                    }
                )
            }
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .testTag("search_screen")
        ) {
            // App Header Logo
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                BookMySpaceLogo()
            }

            // Search Input Bar & Filter Drawer Trigger Button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("search_input_field"),
                    placeholder = { Text("Search venue, PG, hotel...") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    trailingIcon = {
                        if (searchQuery.isNotEmpty()) {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Default.Clear, contentDescription = "Clear")
                            }
                        }
                    },
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = {
                        if (searchQuery.isNotBlank()) {
                            BookMySpaceRepository.saveSearchQuery(searchQuery, selectedCategorySlug ?: "All")
                        }
                    }),
                    singleLine = true,
                    shape = RoundedCornerShape(16.dp)
                )

                IconButton(
                    onClick = { showEasyVoiceBookingDialog = true },
                    modifier = Modifier
                        .testTag("easy_voice_search_button")
                        .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(16.dp))
                ) {
                    Icon(
                        imageVector = Icons.Default.Mic,
                        contentDescription = "Voice Booking",
                        tint = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }

                if (!isSimpleMode) {
                    BadgedBox(
                        badge = {
                            if (activeFilterCount > 0) {
                                Badge { Text("$activeFilterCount") }
                            }
                        }
                    ) {
                        FilledTonalIconButton(
                            onClick = {
                                showFilterSheet = true
                            },
                            modifier = Modifier.testTag("filter_bottom_sheet_button"),
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Icon(Icons.Default.FilterList, contentDescription = "Open Filter Bottom Sheet")
                        }
                    }
                }
            }

            // Location Hierarchy Breadcrumb Bar
            LocationHierarchyHeaderBar(
                currentLocation = userLocationHierarchy,
                selectedRadius = userLocationRadius,
                onClick = { showLocationDialog = true },
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 2.dp)
            )

            // Room Database Persistent Recent Searches Section
            if (recentSearches.isNotEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 4.dp)
                        .testTag("recent_searches_container")
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.History,
                                contentDescription = "Recent Searches History",
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Recent Searches",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        TextButton(
                            onClick = { BookMySpaceRepository.clearAllSearchQueries() },
                            contentPadding = PaddingValues(0.dp),
                            modifier = Modifier
                                .height(24.dp)
                                .testTag("clear_all_recent_searches_button")
                        ) {
                            Text("Clear All", fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
                        }
                    }

                    Spacer(modifier = Modifier.height(4.dp))

                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        contentPadding = PaddingValues(vertical = 2.dp),
                        modifier = Modifier.testTag("recent_searches_chip_row")
                    ) {
                        items(recentSearches, key = { it.query }) { item ->
                            FilterChip(
                                selected = searchQuery.equals(item.query, ignoreCase = true),
                                onClick = {
                                    searchQuery = item.query
                                    BookMySpaceRepository.saveSearchQuery(item.query, item.categoryFilter)
                                },
                                label = {
                                    Text(item.query, fontSize = 12.sp)
                                },
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.Default.History,
                                        contentDescription = null,
                                        modifier = Modifier.size(14.dp)
                                    )
                                },
                                trailingIcon = {
                                    IconButton(
                                        onClick = { BookMySpaceRepository.deleteSearchQuery(item.query) },
                                        modifier = Modifier.size(18.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Close,
                                            contentDescription = "Delete Search",
                                            modifier = Modifier.size(12.dp)
                                        )
                                    }
                                },
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.testTag("recent_search_chip_${item.query}")
                            )
                        }
                    }

                    if (searchQuery.isBlank() && recentlyViewedVenues.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Previously Looked At Venues",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "(${recentlyViewedVenues.size})",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                            )
                        }
                        Spacer(modifier = Modifier.height(6.dp))
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            contentPadding = PaddingValues(vertical = 2.dp),
                            modifier = Modifier.testTag("search_recently_viewed_venues_row")
                        ) {
                            items(recentlyViewedVenues, key = { it.id }) { v ->
                                RecentlyViewedVenueCard(
                                    venue = v,
                                    onClick = { onNavigateToVenue(v.id) },
                                    onRemove = { BookMySpaceRepository.removeRecentlyViewedVenue(v.id) }
                                )
                            }
                        }
                    }
                }
            }

            if (isSimpleMode) {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 2.dp),
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.secondaryContainer
                ) {
                    Text(
                        text = "👵 Simple Mode Active: Search by voice or type venue name. Complex filters hidden for clarity.",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        modifier = Modifier.padding(10.dp)
                    )
                }
            }

            if (showEasyVoiceBookingDialog) {
                EasyVoiceBookingDialog(
                    onDismiss = { showEasyVoiceBookingDialog = false },
                    onNavigateToVenue = onNavigateToVenue
                )
            }

            if (!isSimpleMode) {
                // Section Context Indicator Banner if a specific section/type is selected
                if (selectedPropertyType != "ALL" || selectedCategorySlug != null) {
                    val sectionLabel = when {
                        selectedPropertyType == "HOTEL" || selectedCategorySlug == "hotel_stay" -> "🏨 Hotels & Rooms"
                        selectedPropertyType == "PG" || selectedCategorySlug == "pg_hostel" -> "🏡 PG & Hostels"
                        selectedCategorySlug == "meeting_room" -> "💼 Coworking & Workspaces"
                        selectedPropertyType == "VENUE" || selectedCategorySlug == "function_hall" -> "🏛️ Function Halls & Banquets"
                        else -> "🔍 Filtered Spaces"
                    }

                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 2.dp)
                            .testTag("search_section_context_banner"),
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f))
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = sectionLabel,
                                    fontWeight = FontWeight.ExtraBold,
                                    fontSize = 13.sp,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "in ${userLocationHierarchy.shortLabel}",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            TextButton(
                                onClick = {
                                    selectedPropertyType = "ALL"
                                    selectedCategorySlug = null
                                },
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp)
                            ) {
                                Text("View All", fontSize = 11.5.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }

                // Horizontal Quick Filter Chips Row
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.testTag("horizontal_quick_filter_chips_row")
                ) {
                    item {
                        FilterChip(
                            selected = selectedPropertyType == "ALL" && selectedCategorySlug == null,
                            onClick = {
                                selectedPropertyType = "ALL"
                                selectedCategorySlug = null
                            },
                            label = { Text("All Types") }
                        )
                    }
                    if (isVenuesSectionEnabled) {
                        item {
                            FilterChip(
                                selected = selectedPropertyType == "VENUE" || selectedCategorySlug == "function_hall",
                                onClick = {
                                    if (selectedPropertyType == "VENUE") {
                                        selectedPropertyType = "ALL"
                                        selectedCategorySlug = null
                                    } else {
                                        selectedPropertyType = "VENUE"
                                        selectedCategorySlug = "function_hall"
                                    }
                                },
                                label = { Text("🏛️ Venues") }
                            )
                        }
                    }
                    if (isPgSectionEnabled) {
                        item {
                            FilterChip(
                                selected = selectedPropertyType == "PG" || selectedCategorySlug == "pg_hostel",
                                onClick = {
                                    if (selectedPropertyType == "PG") {
                                        selectedPropertyType = "ALL"
                                        selectedCategorySlug = null
                                    } else {
                                        selectedPropertyType = "PG"
                                        selectedCategorySlug = "pg_hostel"
                                    }
                                },
                                label = { Text("🏡 PG / Hostels") }
                            )
                        }
                    }
                    if (isHotelsSectionEnabled) {
                        item {
                            FilterChip(
                                selected = selectedPropertyType == "HOTEL" || selectedCategorySlug == "hotel_stay",
                                onClick = {
                                    if (selectedPropertyType == "HOTEL") {
                                        selectedPropertyType = "ALL"
                                        selectedCategorySlug = null
                                    } else {
                                        selectedPropertyType = "HOTEL"
                                        selectedCategorySlug = "hotel_stay"
                                    }
                                },
                                label = { Text("🏨 Hotels") }
                            )
                        }
                    }

                    // Section-Specific Contextual Filter Chips
                    if (selectedPropertyType == "PG" || selectedCategorySlug == "pg_hostel") {
                        // PG specific filters
                        listOf("Men's", "Women's", "Co-Ed").forEach { pgType ->
                            item {
                                FilterChip(
                                    selected = selectedPgType == pgType,
                                    onClick = { selectedPgType = if (selectedPgType == pgType) null else pgType },
                                    label = { Text(pgType) }
                                )
                            }
                        }
                        listOf("Single", "2-Share", "3-Share").forEach { sharing ->
                            item {
                                FilterChip(
                                    selected = selectedSharingType == sharing,
                                    onClick = { selectedSharingType = if (selectedSharingType == sharing) null else sharing },
                                    label = { Text("🛏️ $sharing") }
                                )
                            }
                        }
                        item {
                            FilterChip(
                                selected = selectedAmenities.contains("food") || selectedAmenities.contains("mess"),
                                onClick = {
                                    selectedAmenities = if (selectedAmenities.contains("food")) {
                                        selectedAmenities - "food" - "mess"
                                    } else {
                                        selectedAmenities + "food"
                                    }
                                },
                                label = { Text("🍛 Mess Food") }
                            )
                        }
                    } else if (selectedPropertyType == "HOTEL" || selectedCategorySlug == "hotel_stay") {
                        // Hotel specific filters
                        listOf(3, 4, 5).forEach { star ->
                            item {
                                FilterChip(
                                    selected = selectedStarRating == star,
                                    onClick = { selectedStarRating = if (selectedStarRating == star) null else star },
                                    label = { Text("⭐ $star★") }
                                )
                            }
                        }
                        listOf("Standard", "Deluxe", "Suite").forEach { roomType ->
                            item {
                                FilterChip(
                                    selected = selectedHotelRoomType == roomType,
                                    onClick = { selectedHotelRoomType = if (selectedHotelRoomType == roomType) null else roomType },
                                    label = { Text("🛏️ $roomType") }
                                )
                            }
                        }
                        item {
                            FilterChip(
                                selected = selectedAmenities.contains("breakfast"),
                                onClick = {
                                    selectedAmenities = if (selectedAmenities.contains("breakfast")) {
                                        selectedAmenities - "breakfast"
                                    } else {
                                        selectedAmenities + "breakfast"
                                    }
                                },
                                label = { Text("🍳 Free Breakfast") }
                            )
                        }
                    } else if (selectedPropertyType == "VENUE" || selectedCategorySlug == "function_hall") {
                        // Function hall specific filters
                        item {
                            FilterChip(
                                selected = minCapacity >= 200,
                                onClick = {
                                    minCapacity = if (minCapacity >= 200) 0 else 200
                                },
                                label = { Text("👥 200+ Guests") }
                            )
                        }
                        item {
                            FilterChip(
                                selected = minCapacity >= 500,
                                onClick = {
                                    minCapacity = if (minCapacity >= 500) 0 else 500
                                },
                                label = { Text("👥 500+ Guests") }
                            )
                        }
                        item {
                            FilterChip(
                                selected = selectedAmenities.contains("ac"),
                                onClick = {
                                    selectedAmenities = if (selectedAmenities.contains("ac")) selectedAmenities - "ac" else selectedAmenities + "ac"
                                },
                                label = { Text("❄️ AC Hall") }
                            )
                        }
                        item {
                            FilterChip(
                                selected = selectedAmenities.contains("parking"),
                                onClick = {
                                    selectedAmenities = if (selectedAmenities.contains("parking")) selectedAmenities - "parking" else selectedAmenities + "parking"
                                },
                                label = { Text("🚗 Parking") }
                            )
                        }
                    }

                    // General price, rating, distance chips
                    item {
                        FilterChip(
                            selected = minPrice > 0f || maxPrice < 500000f,
                            onClick = { showFilterSheet = true },
                            label = {
                                Text(
                                    text = if (minPrice > 0f || maxPrice < 500000f)
                                        "💰 ₹%,d – ₹%,d".format(minPrice.toInt(), maxPrice.toInt())
                                    else "💰 Price Range",
                                    fontSize = 12.sp
                                )
                            },
                            trailingIcon = { Icon(Icons.Default.ArrowDropDown, contentDescription = null, modifier = Modifier.size(16.dp)) },
                            modifier = Modifier.testTag("quick_chip_price_range")
                        )
                    }
                    item {
                        FilterChip(
                            selected = minRatingThreshold > 0f,
                            onClick = {
                                minRatingThreshold = when (minRatingThreshold) {
                                    0f -> 4.0f
                                    4.0f -> 4.5f
                                    4.5f -> 0f
                                    else -> 0f
                                }
                            },
                            label = {
                                Text(
                                    text = if (minRatingThreshold > 0f) "⭐ %.1f+ Rating".format(minRatingThreshold) else "⭐ Rating",
                                    fontSize = 12.sp
                                )
                            },
                            leadingIcon = {
                                Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFEAB308), modifier = Modifier.size(14.dp))
                            },
                            modifier = Modifier.testTag("quick_chip_rating_threshold")
                        )
                    }
                    item {
                        FilterChip(
                            selected = maxDistanceRadius < 50f && useLocationServices,
                            onClick = { showFilterSheet = true },
                            label = {
                                Text(
                                    text = if (useLocationServices && maxDistanceRadius < 50f)
                                        "📍 Within ${maxDistanceRadius.toInt()} km"
                                    else "📍 Distance",
                                    fontSize = 12.sp
                                )
                            },
                            leadingIcon = {
                                Icon(Icons.Default.MyLocation, contentDescription = null, modifier = Modifier.size(14.dp))
                            },
                            modifier = Modifier.testTag("quick_chip_distance_radius")
                        )
                    }
                    item {
                        AssistChip(
                            onClick = { showFilterSheet = true },
                            label = {
                                Text(
                                    text = if (activeFilterCount > 0) "⚙️ Filters ($activeFilterCount)" else "⚙️ Filters",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            },
                            leadingIcon = { Icon(Icons.Default.Tune, contentDescription = null, modifier = Modifier.size(14.dp)) },
                            modifier = Modifier.testTag("advanced_filter_bottom_sheet_chip")
                        )
                    }
                    if (activeFilterCount > 0) {
                        item {
                            AssistChip(
                                onClick = { resetAllFilters() },
                                label = { Text("Reset All", fontSize = 11.sp, color = MaterialTheme.colorScheme.error) },
                                leadingIcon = { Icon(Icons.Default.Clear, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.error) },
                                modifier = Modifier.testTag("reset_all_quick_filters_chip")
                            )
                        }
                    }
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${filteredVenues.size} Spaces & Properties Available",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // View Mode Toggle (List vs Map)
                SingleChoiceSegmentedButtonRow {
                    SegmentedButton(
                        selected = !isMapView,
                        onClick = { isMapView = false },
                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.List, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("List", fontSize = 11.sp)
                        }
                    }
                    SegmentedButton(
                        selected = isMapView,
                        onClick = {
                            isMapView = true
                            if (selectedMapVenueId == null && filteredVenues.isNotEmpty()) {
                                selectedMapVenueId = filteredVenues[0].id
                            }
                        },
                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Map", fontSize = 11.sp)
                        }
                    }
                }
            }

            // Map or List View Mode Display with Skeleton Animations
            if (venues.isEmpty()) {
                if (isMapView) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        VenueMapSkeleton(modifier = Modifier.fillMaxSize())
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 20.dp, vertical = 8.dp)
                    ) {
                        VenueListSkeleton(count = 4)
                    }
                }
            } else if (isMapView) {
                val selectedVenue = filteredVenues.firstOrNull { it.id == selectedMapVenueId } ?: filteredVenues.firstOrNull()

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    RealMapViewComponent(
                        venues = filteredVenues,
                        selectedVenueId = selectedVenue?.id,
                        onVenueSelect = { selectedMapVenueId = it.id },
                        onNavigateToVenueDetails = { onNavigateToVenue(it) },
                        modifier = Modifier.fillMaxSize()
                    )
                }
            } else if (filteredVenues.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(20.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("🔍", fontSize = 48.sp)
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("No spaces match your filter criteria", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Try adjusting price range, capacity, or selected amenities", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { resetAllFilters() }) {
                            Text("Reset All Filters")
                        }
                    }
                }
            } else {
                BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                    val gridColumns = when {
                        maxWidth < 600.dp -> GridCells.Fixed(1)
                        maxWidth < 960.dp -> GridCells.Adaptive(minSize = 300.dp)
                        else -> GridCells.Adaptive(minSize = 340.dp)
                    }
                    val horizontalSpacing = if (maxWidth >= 600.dp) 16.dp else 12.dp

                    LazyVerticalGrid(
                        columns = gridColumns,
                        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp),
                        horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(items = filteredVenues, key = { it.id }) { venue ->
                            VenueCard(
                                venue = venue,
                                onClick = { onNavigateToVenue(venue.id) },
                                onFavoriteToggle = { BookMySpaceRepository.toggleSaved(venue.id) },
                                sharedTransitionScope = sharedTransitionScope,
                                animatedVisibilityScope = animatedVisibilityScope
                            )
                        }
                    }
                }
            }
        }

        // Bottom Sheet Venue Filter
        if (showFilterSheet && !drawerState.isOpen) {
            VenueFilterBottomSheet(
                initialMinPrice = minPrice,
                initialMaxPrice = maxPrice,
                initialMinRating = minRatingThreshold,
                initialSelectedAmenities = selectedAmenities,
                maxPriceLimit = 500000f,
                totalVenuesCount = venues.size,
                matchingVenuesCount = filteredVenues.size,
                onDismissRequest = { showFilterSheet = false },
                onApplyFilters = { newMinPrice, newMaxPrice, newMinRating, newSelectedAmenities ->
                    minPrice = newMinPrice
                    maxPrice = newMaxPrice
                    minRatingThreshold = newMinRating
                    selectedAmenities = newSelectedAmenities
                },
                onResetFilters = { resetAllFilters() }
            )
        }

        if (showLocationDialog) {
            LocationHierarchySelectorDialog(
                currentLocation = userLocationHierarchy,
                currentRadius = userLocationRadius,
                onLocationSelected = { loc, rad ->
                    BookMySpaceRepository.setUserLocationHierarchy(loc, rad)
                    showLocationDialog = false
                },
                onDismiss = { showLocationDialog = false }
            )
        }
    }
}

@Composable
fun RecentlyViewedVenueCard(
    venue: Venue,
    onClick: () -> Unit,
    onRemove: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
        modifier = modifier
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.History,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = venue.name,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1
            )
            Spacer(modifier = Modifier.width(6.dp))
            IconButton(
                onClick = onRemove,
                modifier = Modifier.size(16.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Remove",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(12.dp)
                )
            }
        }
    }
}

