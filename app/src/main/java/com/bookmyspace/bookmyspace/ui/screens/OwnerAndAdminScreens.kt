package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddAPhoto
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.*
import com.bookmyspace.bookmyspace.ui.components.GoogleMapLocationPicker
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.ContactSettings
import com.bookmyspace.bookmyspace.data.model.CustomerSection
import com.bookmyspace.bookmyspace.data.model.CustomerSectionCatalog
import com.bookmyspace.bookmyspace.data.model.ListingTargetCategory
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.DynamicConfigurableFieldsForm

import com.bookmyspace.bookmyspace.ui.components.OwnerWeeklyCalendarComponent
import com.bookmyspace.bookmyspace.ui.components.VenueOptimizerDashboard
import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerDashboardScreen(
    onCreateVenue: () -> Unit,
    onEditVenue: (String) -> Unit = {},
    onPreviewVenue: (String) -> Unit = {}
) {
    val venues by BookMySpaceRepository.venues.collectAsState()
    val bookings by BookMySpaceRepository.bookings.collectAsState()
    val maintenanceBlocks by BookMySpaceRepository.maintenanceBlocks.collectAsState()
    val totalEarnings = bookings.filter { it.isPaid }.sumOf { it.totalAmount }

    var selectedTab by remember { mutableIntStateOf(0) } // 0: Venue Optimizer, 1: Weekly Calendar & Maintenance, 2: Listed Properties Overview

    Scaffold(
        topBar = { TopAppBar(title = { Text("Venue Owner Portal", fontWeight = FontWeight.Bold) }) },
        floatingActionButton = {
            val isQuickBookingOn by BookMySpaceRepository.isQuickBookingModeEnabled.collectAsState()
            val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FloatingActionButton(
                    onClick = {
                        haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                        BookMySpaceRepository.setQuickBookingMode(!isQuickBookingOn)
                    },
                    containerColor = if (isQuickBookingOn) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                    contentColor = if (isQuickBookingOn) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSecondary,
                    modifier = Modifier.testTag("floating_booking_mode_toggle")
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = if (isQuickBookingOn) "⚡ 1-Tap Mode: ON" else "📋 Standard Mode: ON",
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp
                        )
                    }
                }
                ExtendedFloatingActionButton(
                    onClick = onCreateVenue,
                    icon = { Icon(Icons.Default.Add, contentDescription = null) },
                    text = { Text("Add New Venue") },
                    modifier = Modifier.testTag("add_venue_fab")
                )
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            ScrollableTabRow(
                selectedTabIndex = selectedTab,
                modifier = Modifier.fillMaxWidth(),
                edgePadding = 8.dp
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("⚡ Venue Optimizer", fontWeight = FontWeight.Bold, fontSize = 13.sp) },
                    modifier = Modifier.testTag("tab_owner_venue_optimizer")
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("📅 Weekly Grid", fontWeight = FontWeight.Bold, fontSize = 13.sp) },
                    modifier = Modifier.testTag("tab_owner_weekly_grid")
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = { Text("🏢 Listed Properties", fontWeight = FontWeight.Bold, fontSize = 13.sp) },
                    modifier = Modifier.testTag("tab_owner_properties")
                )
            }

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                if (selectedTab == 0) {
                    item {
                        VenueOptimizerDashboard(
                            venues = venues
                        )
                    }
                } else if (selectedTab == 1) {
                    item {
                        OwnerWeeklyCalendarComponent(
                            venues = venues,
                            bookings = bookings,
                            maintenanceBlocks = maintenanceBlocks
                        )
                    }
                } else {

                    item {
                        val isQuickBookingOn by BookMySpaceRepository.isQuickBookingModeEnabled.collectAsState()
                        Card(
                            modifier = Modifier.fillMaxWidth().testTag("admin_booking_mode_card"),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "Global Booking Flow Mode",
                                            fontWeight = FontWeight.ExtraBold,
                                            fontSize = 15.sp,
                                            color = MaterialTheme.colorScheme.onTertiaryContainer
                                        )
                                        Text(
                                            text = if (isQuickBookingOn) "ON: 1-Tap Quick Booking Flow" else "OFF: Normal Multi-Step Flow",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp,
                                            color = MaterialTheme.colorScheme.tertiary
                                        )
                                    }
                                    Switch(
                                        checked = isQuickBookingOn,
                                        onCheckedChange = { BookMySpaceRepository.setQuickBookingMode(it) },
                                        modifier = Modifier.testTag("admin_quick_booking_toggle_switch")
                                    )
                                }
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = "Toggling this switch updates the booking behavior app-wide: ON launches single-tab instant booking; OFF enforces step-by-step verification.",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onTertiaryContainer.copy(alpha = 0.8f)
                                )
                            }
                        }
                    }

                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Card(
                                modifier = Modifier.weight(1f),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Text("Total Earnings", fontSize = 11.sp)
                                    Text("₹${totalEarnings.toInt()}", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                            Card(
                                modifier = Modifier.weight(1f),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Text("Managed Venues", fontSize = 11.sp)
                                    Text("${venues.size}", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }

                    item {
                        Text("Your Listed Venues", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }

                    items(venues) { venue ->
                        var showContactSettingsDialog by remember { mutableStateOf(false) }
                        var showDeleteConfirm by remember { mutableStateOf(false) }
                        val listingSection = CustomerSectionCatalog.sectionForVenue(venue)
                        val isInstitute = listingSection == CustomerSection.INSTITUTES_CLASSES

                        if (showDeleteConfirm) {
                            AlertDialog(
                                onDismissRequest = { showDeleteConfirm = false },
                                title = { Text("Delete listing?") },
                                text = { Text("Remove ${venue.name} from your listings.") },
                                confirmButton = {
                                    TextButton(
                                        onClick = {
                                            BookMySpaceRepository.deleteOwnerVenue(venue.id)
                                            showDeleteConfirm = false
                                        },
                                        modifier = Modifier.testTag("owner_delete_confirm_${venue.id}")
                                    ) { Text("Delete") }
                                },
                                dismissButton = {
                                    TextButton(onClick = { showDeleteConfirm = false }) { Text("Cancel") }
                                }
                            )
                        }

                        if (showContactSettingsDialog) {
                            AdminVenueContactSettingsDialog(
                                venue = venue,
                                onDismiss = { showContactSettingsDialog = false }
                            )
                        }

                        Card(
                            modifier = Modifier.fillMaxWidth().testTag("owner_listed_venue_${venue.id}"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(venue.name, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                        Text(
                                            listOfNotNull(
                                                listingSection?.let { "${it.emoji} ${it.title}" },
                                                if (isInstitute) "Fee from ₹${venue.pricingBaseAmount.toInt()}"
                                                else "Base Price: ₹${venue.pricingBaseAmount.toInt()}"
                                            ).joinToString(" · "),
                                            fontSize = 12.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    Column(horizontalAlignment = Alignment.End) {
                                        Surface(
                                            color = if (venue.isActive) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                                            shape = RoundedCornerShape(8.dp)
                                        ) {
                                            Text(
                                                if (venue.isActive) "Published" else "Draft",
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Bold
                                            )
                                        }
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Surface(
                                            color = if (venue.isVerified) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                                            shape = RoundedCornerShape(8.dp)
                                        ) {
                                            Text(
                                                if (venue.isVerified) "Verified" else "Pending Review",
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Bold
                                            )
                                        }
                                    }
                                }

                                if (isInstitute) {
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(
                                        "Advertising listing only — customers cannot book hall slots.",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.tertiary
                                    )
                                }

                                Spacer(modifier = Modifier.height(10.dp))
                                HorizontalDivider()
                                Spacer(modifier = Modifier.height(8.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text("Contact Mode:", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        val cs = venue.contactSettings
                                        val activeOptions = mutableListOf<String>()
                                        if (cs.showCall) activeOptions.add("Call")
                                        if (cs.showWhatsapp) activeOptions.add("WhatsApp")
                                        if (cs.showChat) activeOptions.add("Chat")
                                        if (cs.showOwnerContact) activeOptions.add("Owner Phone")
                                        if (cs.contactBookMySpace) activeOptions.add("BookMySpace Desk")

                                        Text(
                                            text = if (activeOptions.isEmpty()) "All Direct Contact OFF (Default)" else activeOptions.joinToString(", "),
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }

                                    OutlinedButton(
                                        onClick = { showContactSettingsDialog = true },
                                        shape = RoundedCornerShape(8.dp),
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                        modifier = Modifier.testTag("venue_contact_settings_btn_${venue.id}")
                                    ) {
                                        Text("Contact Settings", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                    }
                                }

                                Spacer(modifier = Modifier.height(8.dp))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    OutlinedButton(
                                        onClick = { onEditVenue(venue.id) },
                                        modifier = Modifier.weight(1f).testTag("owner_edit_${venue.id}"),
                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                    ) {
                                        Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Edit", fontSize = 11.sp)
                                    }
                                    OutlinedButton(
                                        onClick = { onPreviewVenue(venue.id) },
                                        modifier = Modifier.weight(1f).testTag("owner_preview_${venue.id}"),
                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                    ) {
                                        Icon(Icons.Default.Visibility, contentDescription = null, modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Preview", fontSize = 11.sp)
                                    }
                                    Button(
                                        onClick = { BookMySpaceRepository.setVenuePublished(venue.id, !venue.isActive) },
                                        modifier = Modifier.weight(1f).testTag("owner_publish_${venue.id}"),
                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                    ) {
                                        Text(if (venue.isActive) "Unpublish" else "Publish", fontSize = 11.sp)
                                    }
                                }
                                TextButton(
                                    onClick = { showDeleteConfirm = true },
                                    modifier = Modifier.testTag("owner_delete_${venue.id}")
                                ) {
                                    Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(14.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Delete listing", fontSize = 11.sp, color = MaterialTheme.colorScheme.error)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateVenueScreen(
    onVenueCreated: () -> Unit,
    onBack: () -> Unit,
    existingVenueId: String? = null,
    onPreview: (String) -> Unit = {}
) {
    val existing = remember(existingVenueId) {
        existingVenueId?.let { id -> BookMySpaceRepository.venues.value.find { it.id == id } }
    }
    val initialSection = remember(existing) {
        existing?.let { CustomerSectionCatalog.sectionForVenue(it) } ?: CustomerSection.FUNCTION_HALLS
    }
    var selectedSection by remember { mutableStateOf(initialSection) }
    var selectedCatalogCategory by remember {
        mutableStateOf(
            existing?.let { venue ->
                CustomerSectionCatalog.ownerCategories(initialSection).firstOrNull { cat ->
                    CustomerSectionCatalog.matchesVenue(venue, initialSection, cat.id)
                }?.id ?: CustomerSectionCatalog.ownerCategories(initialSection).first().id
            } ?: CustomerSectionCatalog.ownerCategories(CustomerSection.FUNCTION_HALLS).first().id
        )
    }
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var description by remember { mutableStateOf(existing?.description ?: "") }
    var address by remember { mutableStateOf(existing?.addressLine1 ?: "") }
    var city by remember { mutableStateOf(existing?.city ?: "Hyderabad") }
    var priceStr by remember { mutableStateOf(existing?.pricingBaseAmount?.toInt()?.toString() ?: "25000") }
    var capacityStr by remember { mutableStateOf(existing?.capacity?.toString() ?: "50") }
    var latitude by remember { mutableDoubleStateOf(existing?.latitude ?: 17.3850) }
    var longitude by remember { mutableDoubleStateOf(existing?.longitude ?: 78.4866) }
    var publishListing by remember { mutableStateOf(existing?.isActive ?: false) }
    var customVenueFieldValues by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    val ownerCategories = CustomerSectionCatalog.ownerCategories(selectedSection)
    val dynamicTargetCategory = selectedSection.listingTarget
    val isInstitute = !selectedSection.isBookable

    // Image Upload State
    var imageUrlInput by remember { mutableStateOf("") }
    var imageList by remember {
        mutableStateOf<List<String>>(existing?.images?.map { it.url } ?: emptyList())
    }
    var coverIndex by remember {
        mutableIntStateOf(existing?.images?.indexOfFirst { it.isCover }?.coerceAtLeast(0) ?: 0)
    }
    var storageNotice by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val photoPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(6)
    ) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        val remaining = 6 - imageList.size
        if (remaining <= 0) {
            storageNotice = "PHOTO LIMIT: Maximum 6 photos limit reached for this venue property."
            return@rememberLauncherForActivityResult
        }
        val stored = uris.take(remaining).mapNotNull { uri ->
            BookMySpaceRepository.persistPickedVenuePhoto(context, uri)
        }
        if (stored.isEmpty()) {
            storageNotice = "PHOTO ERROR: Could not save the selected gallery images."
            return@rememberLauncherForActivityResult
        }
        imageList = imageList + stored
        storageNotice = "PHOTO UPLOADED (${imageList.size}/6): Saved from your gallery (JPG, PNG, WEBP)."
    }
    var selectedAmenities by remember {
        mutableStateOf(
            CustomerSectionCatalog.amenityFilters(initialSection)
                .filter { spec ->
                    existing?.facilities?.any { fac ->
                        spec.keywords.any { keyword -> fac.facility.contains(keyword, ignoreCase = true) }
                    } == true
                }
                .map { it.id }
                .toSet()
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (existing != null) "Edit listing" else "Create listing",
                        fontWeight = FontWeight.Bold
                    )
                },
                actions = {
                    if (existing != null) {
                        IconButton(onClick = { onPreview(existing.id) }) {
                            Icon(Icons.Default.Visibility, contentDescription = "Preview")
                        }
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(if (isInstitute) "Institute / class name" else "Listing name") },
                    modifier = Modifier.fillMaxWidth().testTag("venue_name_input")
                )
            }
            item {
                Text("Section", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(CustomerSection.entries) { section ->
                        FilterChip(
                            selected = selectedSection == section,
                            onClick = {
                                selectedSection = section
                                selectedCatalogCategory = CustomerSectionCatalog.ownerCategories(section).first().id
                                selectedAmenities = emptySet()
                            },
                            label = { Text("${section.emoji} ${section.title}") },
                            modifier = Modifier.testTag("owner_section_${section.id}")
                        )
                    }
                }
                Spacer(modifier = Modifier.height(10.dp))
                Text("Category", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(ownerCategories) { cat ->
                        FilterChip(
                            selected = selectedCatalogCategory == cat.id,
                            onClick = { selectedCatalogCategory = cat.id },
                            label = { Text("${cat.emoji} ${cat.label}") },
                            modifier = Modifier.testTag("owner_category_${cat.id}")
                        )
                    }
                }
            }
            if (isInstitute) {
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(
                            "Institutes / Classes are advertising listings only. Customers can call, WhatsApp or open the map — they cannot book hall slots.",
                            modifier = Modifier.padding(12.dp),
                            fontSize = 12.sp
                        )
                    }
                }
            }
            item {
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Description & Highlights") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
            }
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = address,
                        onValueChange = { address = it },
                        label = { Text("Address / Area") },
                        modifier = Modifier.weight(1f)
                    )
                    OutlinedTextField(
                        value = city,
                        onValueChange = { city = it },
                        label = { Text("City") },
                        modifier = Modifier.width(120.dp)
                    )
                }
            }
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = capacityStr,
                        onValueChange = { capacityStr = it },
                        label = {
                            Text(
                                when (selectedSection) {
                                    CustomerSection.INSTITUTES_CLASSES -> "Batch size"
                                    CustomerSection.LODGE_ROOMS -> "Rooms / occupancy"
                                    CustomerSection.PG_HOSTELS -> "Beds / occupancy"
                                    else -> "Capacity"
                                }
                            )
                        },
                        modifier = Modifier.weight(1f).testTag("owner_listing_capacity")
                    )
                    OutlinedTextField(
                        value = priceStr,
                        onValueChange = { priceStr = it },
                        label = { Text(if (isInstitute) "Fee from (₹)" else "Base Price (₹)") },
                        modifier = Modifier.weight(1f).testTag("owner_listing_price")
                    )
                }
            }

            item {
                Text("Available fields", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(6.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(CustomerSectionCatalog.amenityFilters(selectedSection)) { spec ->
                        FilterChip(
                            selected = spec.id in selectedAmenities,
                            onClick = {
                                selectedAmenities = if (spec.id in selectedAmenities) {
                                    selectedAmenities - spec.id
                                } else {
                                    selectedAmenities + spec.id
                                }
                            },
                            label = { Text("${spec.emoji} ${spec.label}") }
                        )
                    }
                }
            }

            // REAL OPENSTREETMAP LOCATION PICKER
            item {
                com.bookmyspace.bookmyspace.ui.components.RealLocationPickerMap(
                    initialLat = latitude,
                    initialLng = longitude,
                    initialAddress = address,
                    onLocationSelected = { lat, lng, locAddress ->
                        latitude = lat
                        longitude = lng
                        if (locAddress.isNotBlank()) address = locAddress
                    }
                )
            }

            // VENUE IMAGES & STORAGE SECTION
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Text("Venue Photos & Cover Image (${imageList.size}/6 Max)", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(
                            "Choose up to 6 photos from your gallery (JPG, PNG, WEBP). Select 1 as Cover Photo.",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(10.dp))

                        Button(
                            onClick = {
                                if (imageList.size >= 6) {
                                    storageNotice = "PHOTO LIMIT: Maximum 6 photos limit reached for this venue property."
                                    return@Button
                                }
                                photoPicker.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                )
                            },
                            enabled = imageList.size < 6,
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.testTag("owner_photo_pick")
                        ) {
                            Icon(Icons.Default.AddAPhoto, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Choose photos")
                        }
                        Spacer(modifier = Modifier.height(8.dp))

                        // Optional URL fallback
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = imageUrlInput,
                                onValueChange = { imageUrlInput = it },
                                label = { Text("Or paste image URL") },
                                leadingIcon = { Icon(Icons.Default.CloudUpload, contentDescription = null) },
                                modifier = Modifier.weight(1f),
                                singleLine = true,
                                enabled = imageList.size < 6
                            )
                            Button(
                                onClick = {
                                    if (imageList.size >= 6) {
                                        storageNotice = "PHOTO LIMIT: Maximum 6 photos limit reached for this venue property."
                                        return@Button
                                    }
                                    if (imageUrlInput.isNotBlank()) {
                                        imageList = imageList + imageUrlInput.trim()
                                        imageUrlInput = ""
                                        storageNotice = "PHOTO UPLOADED (${imageList.size}/6): Image URL added to gallery."
                                    }
                                },
                                enabled = imageList.size < 6 && imageUrlInput.isNotBlank(),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text("Add")
                            }
                        }

                        if (storageNotice != null) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Card(
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Row(modifier = Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.onTertiaryContainer, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(storageNotice ?: "", fontSize = 10.sp, color = MaterialTheme.colorScheme.onTertiaryContainer, lineHeight = 14.sp)
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Image Thumbnails & Cover Selection
                        if (imageList.isNotEmpty()) {
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                items(imageList.size) { idx ->
                                    val url = imageList[idx]
                                    val isCover = idx == coverIndex
                                    Box(
                                        modifier = Modifier
                                            .size(90.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .border(
                                                width = if (isCover) 2.dp else 1.dp,
                                                color = if (isCover) MaterialTheme.colorScheme.primary else Color.LightGray,
                                                shape = RoundedCornerShape(8.dp)
                                            )
                                            .background(MaterialTheme.colorScheme.primaryContainer)
                                    ) {
                                        AsyncImage(
                                            model = url,
                                            contentDescription = "Photo ${idx + 1}",
                                            contentScale = ContentScale.Crop,
                                            modifier = Modifier.fillMaxSize()
                                        )

                                        // Cover Badge / Toggle
                                        IconButton(
                                            onClick = { coverIndex = idx },
                                            modifier = Modifier
                                                .align(Alignment.TopStart)
                                                .padding(2.dp)
                                                .size(24.dp)
                                                .background(
                                                    if (isCover) MaterialTheme.colorScheme.primary else Color.Black.copy(alpha = 0.6f),
                                                    CircleShape
                                                )
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Star,
                                                contentDescription = "Set as Cover",
                                                tint = Color.White,
                                                modifier = Modifier.size(14.dp)
                                            )
                                        }

                                        // Delete Image Button
                                        IconButton(
                                            onClick = {
                                                val mutable = imageList.toMutableList()
                                                mutable.removeAt(idx)
                                                imageList = mutable
                                                if (coverIndex >= mutable.size && mutable.isNotEmpty()) {
                                                    coverIndex = 0
                                                }
                                            },
                                            modifier = Modifier
                                                .align(Alignment.TopEnd)
                                                .padding(2.dp)
                                                .size(24.dp)
                                                .background(Color.Red.copy(alpha = 0.8f), CircleShape)
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Close,
                                                contentDescription = "Remove Photo",
                                                tint = Color.White,
                                                modifier = Modifier.size(14.dp)
                                            )
                                        }

                                        if (isCover) {
                                            Surface(
                                                color = MaterialTheme.colorScheme.primary,
                                                modifier = Modifier
                                                    .align(Alignment.BottomCenter)
                                                    .fillMaxWidth()
                                            ) {
                                                Text(
                                                    "COVER",
                                                    fontSize = 9.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = Color.White,
                                                    modifier = Modifier.padding(vertical = 1.dp),
                                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                                )
                                            }
                                        }

                                        Row(
                                            modifier = Modifier
                                                .align(Alignment.BottomStart)
                                                .padding(bottom = if (isCover) 16.dp else 2.dp)
                                        ) {
                                            IconButton(
                                                onClick = {
                                                    if (idx > 0) {
                                                        val mutable = imageList.toMutableList()
                                                        val item = mutable.removeAt(idx)
                                                        mutable.add(idx - 1, item)
                                                        imageList = mutable
                                                        coverIndex = when {
                                                            coverIndex == idx -> idx - 1
                                                            coverIndex == idx - 1 -> idx
                                                            else -> coverIndex
                                                        }
                                                    }
                                                },
                                                modifier = Modifier.size(22.dp)
                                            ) {
                                                Icon(Icons.Default.KeyboardArrowLeft, contentDescription = "Move left", tint = Color.White, modifier = Modifier.size(16.dp))
                                            }
                                            IconButton(
                                                onClick = {
                                                    if (idx < imageList.lastIndex) {
                                                        val mutable = imageList.toMutableList()
                                                        val item = mutable.removeAt(idx)
                                                        mutable.add(idx + 1, item)
                                                        imageList = mutable
                                                        coverIndex = when {
                                                            coverIndex == idx -> idx + 1
                                                            coverIndex == idx + 1 -> idx
                                                            else -> coverIndex
                                                        }
                                                    }
                                                },
                                                modifier = Modifier.size(22.dp)
                                            ) {
                                                Icon(Icons.Default.KeyboardArrowRight, contentDescription = "Move right", tint = Color.White, modifier = Modifier.size(16.dp))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            item {
                DynamicConfigurableFieldsForm(
                    targetCategory = dynamicTargetCategory,
                    values = customVenueFieldValues,
                    onValuesChange = { customVenueFieldValues = it },
                    isOwner = true
                )
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Switch(
                        checked = publishListing,
                        onCheckedChange = { publishListing = it },
                        modifier = Modifier.testTag("owner_listing_publish_switch")
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        if (isInstitute) "Published as an advertising listing (Call / WhatsApp only)"
                        else "Published — visible to customers in this section",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            item {
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    onClick = {
                        if (name.isNotBlank()) {
                            val orderedUrls = if (imageList.isNotEmpty()) {
                                val coverUrl = imageList.getOrNull(coverIndex) ?: imageList[0]
                                listOf(coverUrl) + imageList.filterIndexed { index, _ -> index != coverIndex }
                            } else emptyList()
                            val amenityLabels = CustomerSectionCatalog.amenityFilters(selectedSection)
                                .filter { it.id in selectedAmenities }
                                .map { it.label }
                            val categoryLabel = ownerCategories.firstOrNull { it.id == selectedCatalogCategory }?.label
                            val facilities = listOfNotNull(categoryLabel, selectedSection.title) + amenityLabels
                            val safeSlug = CustomerSectionCatalog.resolveOwnerCategorySlug(
                                BookMySpaceRepository.categories,
                                selectedSection,
                                selectedCatalogCategory
                            )

                            val saved = if (existing != null) {
                                BookMySpaceRepository.updateOwnerVenue(
                                    venueId = existing.id,
                                    name = name,
                                    categorySlug = safeSlug,
                                    description = description,
                                    address = address,
                                    city = city,
                                    price = priceStr.toDoubleOrNull() ?: 25000.0,
                                    imageUrls = orderedUrls,
                                    latitude = latitude,
                                    longitude = longitude,
                                    capacity = capacityStr.toIntOrNull() ?: 50,
                                    isActive = publishListing,
                                    facilities = facilities
                                )
                            } else {
                                BookMySpaceRepository.createOwnerVenue(
                                    name = name,
                                    categorySlug = safeSlug,
                                    description = description,
                                    address = address,
                                    city = city,
                                    price = priceStr.toDoubleOrNull() ?: 25000.0,
                                    imageUrls = orderedUrls,
                                    latitude = latitude,
                                    longitude = longitude,
                                    capacity = capacityStr.toIntOrNull() ?: 50,
                                    isActive = publishListing,
                                    facilities = facilities
                                )
                            }

                            if (customVenueFieldValues.isNotEmpty()) {
                                BookMySpaceRepository.saveCustomValuesForListing(saved.id, customVenueFieldValues)
                            }

                            onVenueCreated()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .testTag("submit_venue_button"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(
                        if (existing != null) "Save listing"
                        else if (publishListing) "Create & publish"
                        else "Save draft",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminAuditScreen() {
    val logs by BookMySpaceRepository.auditLogs.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("Admin Audit Log", fontWeight = FontWeight.Bold) }) }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(logs) { log ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(log.action, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary, fontSize = 13.sp)
                            Text(log.timestamp, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(log.details, fontSize = 12.sp)
                        Text("User: ${log.userEmail}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportScreen() {
    val tickets by BookMySpaceRepository.supportTickets.collectAsState()
    var subject by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }

    Scaffold(
        topBar = { TopAppBar(title = { Text("Help & Support Tickets", fontWeight = FontWeight.Bold) }) }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Text("Create New Support Ticket", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = subject,
                    onValueChange = { subject = it },
                    label = { Text("Subject / Booking Issue") },
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Details") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
                Spacer(modifier = Modifier.height(8.dp))
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.CenterEnd
                ) {
                    Button(
                        onClick = {
                            if (subject.isNotBlank()) {
                                BookMySpaceRepository.createSupportTicket(subject, description, "General")
                                subject = ""
                                description = ""
                            }
                        }
                    ) {
                        Text("Submit Ticket")
                    }
                }
            }

            item {
                Text("Your Support Tickets", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }

            items(tickets) { ticket ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(ticket.subject, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(6.dp)) {
                                Text(ticket.status, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(ticket.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
fun AdminVenueContactSettingsDialog(
    venue: Venue,
    onDismiss: () -> Unit
) {
    val user by BookMySpaceRepository.authUser.collectAsState()
    val isAdmin = user?.role == UserRole.ADMIN

    var showCall by remember { mutableStateOf(venue.contactSettings.showCall) }
    var showWhatsapp by remember { mutableStateOf(venue.contactSettings.showWhatsapp) }
    var showChat by remember { mutableStateOf(venue.contactSettings.showChat) }
    var showOwnerContact by remember { mutableStateOf(venue.contactSettings.showOwnerContact) }
    var contactBookMySpace by remember { mutableStateOf(venue.contactSettings.contactBookMySpace) }
    var allowPostBooking by remember { mutableStateOf(venue.contactSettings.allowPostBookingDirectContact) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text("Venue Contact Settings", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text(
                    text = "${venue.name} (Admin Controlled)",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (!isAdmin) {
                    Surface(
                        color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "🔒 Contact settings can ONLY be updated by BookMySpace Admin. Owners cannot override these settings.",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            modifier = Modifier.padding(10.dp)
                        )
                    }
                } else {
                    Text(
                        text = "Control how customers communicate with venue owners vs BookMySpace support.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                HorizontalDivider()

                ContactSettingRow("Show Call Option", showCall, isAdmin) { showCall = it }
                ContactSettingRow("Show WhatsApp Option", showWhatsapp, isAdmin) { showWhatsapp = it }
                ContactSettingRow("Show Chat Option", showChat, isAdmin) { showChat = it }
                ContactSettingRow("Show Owner Contact Details", showOwnerContact, isAdmin) { showOwnerContact = it }
                ContactSettingRow("Contact BookMySpace Support", contactBookMySpace, isAdmin) { contactBookMySpace = it }
                ContactSettingRow("Allow Post-Booking Direct Contact", allowPostBooking, isAdmin) { allowPostBooking = it }
            }
        },
        confirmButton = {
            if (isAdmin) {
                Button(
                    onClick = {
                        val newSettings = ContactSettings(
                            showCall = showCall,
                            showWhatsapp = showWhatsapp,
                            showChat = showChat,
                            showOwnerContact = showOwnerContact,
                            contactBookMySpace = contactBookMySpace,
                            allowPostBookingDirectContact = allowPostBooking
                        )
                        BookMySpaceRepository.updateVenueContactSettings(venue.id, newSettings)
                        onDismiss()
                    },
                    modifier = Modifier.testTag("save_contact_settings_button")
                ) {
                    Text("Save Settings")
                }
            } else {
                TextButton(onClick = onDismiss) {
                    Text("Close")
                }
            }
        },
        dismissButton = {
            if (isAdmin) {
                TextButton(onClick = onDismiss) {
                    Text("Cancel")
                }
            }
        }
    )
}

@Composable
private fun ContactSettingRow(
    label: String,
    checked: Boolean,
    enabled: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.Medium)
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled
        )
    }
}
