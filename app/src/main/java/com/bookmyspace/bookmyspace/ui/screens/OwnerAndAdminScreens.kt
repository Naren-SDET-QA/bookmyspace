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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddAPhoto
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.*
import com.bookmyspace.bookmyspace.ui.components.GoogleMapLocationPicker
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.ContactSettings
import com.bookmyspace.bookmyspace.data.model.ListingTargetCategory
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.DynamicConfigurableFieldsForm

import com.bookmyspace.bookmyspace.ui.components.OwnerWeeklyCalendarComponent
import com.bookmyspace.bookmyspace.ui.components.VenueOptimizerDashboard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerDashboardScreen(
    onCreateVenue: () -> Unit
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

                        if (showContactSettingsDialog) {
                            AdminVenueContactSettingsDialog(
                                venue = venue,
                                onDismiss = { showContactSettingsDialog = false }
                            )
                        }

                        Card(
                            modifier = Modifier.fillMaxWidth(),
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
                                        Text("Base Price: ₹${venue.pricingBaseAmount.toInt()}/hr", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
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
    onBack: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    var selectedCategorySlug by remember { mutableStateOf("function_hall") }
    var description by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("Hyderabad") }
    var priceStr by remember { mutableStateOf("25000") }
    var customVenueFieldValues by remember { mutableStateOf<Map<String, String>>(emptyMap()) }

    val dynamicTargetCategory = remember(selectedCategorySlug) {
        when (selectedCategorySlug) {
            "pg_hostel", "hostel" -> ListingTargetCategory.PG_HOSTEL
            "function_hall" -> ListingTargetCategory.FUNCTION_HALL
            "classroom", "meeting_room" -> ListingTargetCategory.ROOM
            else -> ListingTargetCategory.VENUE
        }
    }

    // Image Upload State
    var imageUrlInput by remember { mutableStateOf("") }
    var imageList by remember { mutableStateOf(listOf("https://images.unsplash.com/photo-1519167758481-83f550bb49b3")) }
    var coverIndex by remember { mutableIntStateOf(0) }
    var storageNotice by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = { TopAppBar(title = { Text("List New Venue / Property", fontWeight = FontWeight.Bold) }) }
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
                    label = { Text("Venue Name") },
                    modifier = Modifier.fillMaxWidth().testTag("venue_name_input")
                )
            }
            item {
                Text("Category / Property Type", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(BookMySpaceRepository.getEnabledCategories()) { cat ->
                        FilterChip(
                            selected = selectedCategorySlug == cat.slug,
                            onClick = { selectedCategorySlug = cat.slug },
                            label = { Text(cat.name) }
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
                OutlinedTextField(
                    value = priceStr,
                    onValueChange = { priceStr = it },
                    label = { Text("Base Price (₹)") },
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // REAL OPENSTREETMAP LOCATION PICKER
            item {
                com.bookmyspace.bookmyspace.ui.components.RealLocationPickerMap(
                    initialLat = 17.3850,
                    initialLng = 78.4866,
                    initialAddress = address,
                    onLocationSelected = { lat, lng, locAddress ->
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
                            "Owner photo upload: allow 5–6 photos max (supports JPG, PNG, WEBP formats). Select 1 as Cover Photo.",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(10.dp))

                        // Photo Input & Upload Trigger
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedTextField(
                                value = imageUrlInput,
                                onValueChange = { imageUrlInput = it },
                                label = { Text("Image URL or Storage Path") },
                                leadingIcon = { Icon(Icons.Default.AddAPhoto, contentDescription = null) },
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
                                        storageNotice = "PHOTO UPLOADED (${imageList.size}/6): Image added to gallery. Common formats (JPG, PNG, WEBP) supported."
                                    } else {
                                        // Demo preset
                                        val presets = listOf(
                                            "https://images.unsplash.com/photo-1511578314322-379afb476865",
                                            "https://images.unsplash.com/photo-1555396273-367ea4eb4db5",
                                            "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af",
                                            "https://images.unsplash.com/photo-1505691938895-1758d7feb511",
                                            "https://images.unsplash.com/photo-1519167758481-83f550bb49b3",
                                            "https://images.unsplash.com/photo-1566073771259-6a8506099945"
                                        )
                                        val nextPreset = presets.getOrNull(imageList.size) ?: presets.last()
                                        imageList = imageList + nextPreset
                                        storageNotice = "PHOTO UPLOADED (${imageList.size}/6): High-res JPG image added to venue gallery."
                                    }
                                },
                                enabled = imageList.size < 6,
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Icon(Icons.Default.CloudUpload, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(4.dp))
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
                                        Column(
                                            modifier = Modifier
                                                .fillMaxSize()
                                                .padding(6.dp),
                                            verticalArrangement = Arrangement.Center,
                                            horizontalAlignment = Alignment.CenterHorizontally
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.AddAPhoto,
                                                contentDescription = null,
                                                tint = MaterialTheme.colorScheme.primary,
                                                modifier = Modifier.size(22.dp)
                                            )
                                            Spacer(modifier = Modifier.height(2.dp))
                                            Text(
                                                text = "Photo #${idx + 1}",
                                                fontSize = 9.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = MaterialTheme.colorScheme.onPrimaryContainer
                                            )
                                        }

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
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    onClick = {
                        if (name.isNotBlank()) {
                            // Reorder images so cover image is first
                            val orderedUrls = if (imageList.isNotEmpty()) {
                                val coverUrl = imageList.getOrNull(coverIndex) ?: imageList[0]
                                listOf(coverUrl) + imageList.filterIndexed { index, _ -> index != coverIndex }
                            } else emptyList()

                            val newVenue = BookMySpaceRepository.createOwnerVenue(
                                name = name,
                                categorySlug = selectedCategorySlug,
                                description = description,
                                address = address,
                                city = city,
                                price = priceStr.toDoubleOrNull() ?: 25000.0,
                                imageUrls = orderedUrls
                            )

                            if (customVenueFieldValues.isNotEmpty()) {
                                BookMySpaceRepository.saveCustomValuesForListing(newVenue.id, customVenueFieldValues)
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
                    Text("Submit Venue for Approval", fontWeight = FontWeight.Bold, fontSize = 16.sp)
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
