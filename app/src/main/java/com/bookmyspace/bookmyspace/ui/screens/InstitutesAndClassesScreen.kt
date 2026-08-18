package com.bookmyspace.bookmyspace.ui.screens

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.DynamicListingFieldsDisplay
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchyHeaderBar
import com.bookmyspace.bookmyspace.ui.components.LocationHierarchySelectorDialog

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InstitutesAndClassesScreen(
    onNavigateBack: () -> Unit,
    onNavigateToOwnerDashboard: () -> Unit
) {
    val context = LocalContext.current
    val classes by BookMySpaceRepository.instituteClasses.collectAsState()
    val institutes by BookMySpaceRepository.institutes.collectAsState()
    val authUser by BookMySpaceRepository.authUser.collectAsState()

    val userLocationHierarchy by BookMySpaceRepository.userLocationHierarchy.collectAsState()
    val userLocationRadius by BookMySpaceRepository.userLocationRadius.collectAsState()
    var showLocationDialog by remember { mutableStateOf(false) }

    var searchQuery by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("All") }
    var selectedMode by remember { mutableStateOf<ClassDeliveryMode?>(null) }
    var selectedTab by remember { mutableIntStateOf(0) } // 0: Classes, 1: Institutes

    var selectedClassForDetail by remember { mutableStateOf<InstituteClass?>(null) }
    var selectedInstituteForDetail by remember { mutableStateOf<InstituteProfile?>(null) }

    val categories = listOf("All", "Sports & Fitness", "Music & Arts", "Tech & Coding", "Dance", "Academics")

    // Filtered lists with location awareness
    val filteredClasses = remember(classes, searchQuery, selectedCategory, selectedMode, userLocationHierarchy) {
        val list = BookMySpaceRepository.searchClasses(searchQuery, selectedCategory, selectedMode)
        list.sortedWith(
            compareBy<InstituteClass> { c ->
                val matchesLocation = c.location.contains(userLocationHierarchy.cityTownName, ignoreCase = true) ||
                        c.location.contains(userLocationHierarchy.districtName, ignoreCase = true) ||
                        c.location.contains(userLocationHierarchy.stateName, ignoreCase = true)
                if (matchesLocation) 0 else 1
            }
        )
    }

    val filteredInstitutes = remember(institutes, searchQuery, selectedCategory, userLocationHierarchy) {
        val list = BookMySpaceRepository.getPublishedInstitutes().filter { inst ->
            val matchesQuery = searchQuery.isBlank() ||
                    inst.name.contains(searchQuery, ignoreCase = true) ||
                    inst.address.contains(searchQuery, ignoreCase = true) ||
                    inst.city.contains(searchQuery, ignoreCase = true) ||
                    inst.categories.any { it.contains(searchQuery, ignoreCase = true) } ||
                    inst.facultyMembers.any { it.name.contains(searchQuery, ignoreCase = true) }

            val matchesCategory = selectedCategory == "All" ||
                    inst.categories.any { it.contains(selectedCategory, ignoreCase = true) }

            matchesQuery && matchesCategory
        }

        list.sortedWith(
            compareBy<InstituteProfile> { inst ->
                val matchesExactCity = inst.city.equals(userLocationHierarchy.cityTownName, ignoreCase = true)
                val matchesState = inst.state.equals(userLocationHierarchy.stateName, ignoreCase = true)
                when {
                    matchesExactCity -> 0
                    matchesState -> 1
                    else -> 2
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Institutes & Classes", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text("Find top academies, coaching & certified batches", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("institutes_back_btn")
                    ) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    FilledTonalButton(
                        onClick = onNavigateToOwnerDashboard,
                        modifier = Modifier
                            .padding(end = 8.dp)
                            .testTag("institute_owner_portal_top_btn"),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Icon(Icons.Default.Storefront, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Owner Portal", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Owner Promotion Banner
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .clickable { onNavigateToOwnerDashboard() }
                    .testTag("institute_owner_banner_cta"),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.School, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(20.dp))
                        }
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Are you an Academy or Institute Owner?", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = MaterialTheme.colorScheme.onPrimaryContainer)
                        Text("List your institute, faculty & batches with 1-tap leads", fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.85f))
                    }
                    Icon(Icons.Default.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimaryContainer)
                }
            }

            // Location Hierarchy Bar
            LocationHierarchyHeaderBar(
                currentLocation = userLocationHierarchy,
                selectedRadius = userLocationRadius,
                onClick = { showLocationDialog = true },
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 2.dp)
            )

            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .testTag("institute_classes_search_input"),
                placeholder = { Text("Search classes, academies, coaches, subjects...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Icon(Icons.Default.Close, contentDescription = "Clear search")
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )

            // Category Chips
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp)
                    .testTag("institute_category_chips_row"),
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(categories) { category ->
                    val isSelected = selectedCategory == category
                    FilterChip(
                        selected = isSelected,
                        onClick = { selectedCategory = category },
                        label = { Text(category, fontSize = 12.sp) },
                        leadingIcon = if (isSelected) {
                            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                        } else null,
                        modifier = Modifier.testTag("category_chip_${category.lowercase().replace(" ", "_").replace("&", "and")}")
                    )
                }
            }

            // Delivery Mode Chips (when Classes tab is active)
            if (selectedTab == 0) {
                LazyRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 2.dp)
                        .testTag("institute_mode_chips_row"),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    item {
                        FilterChip(
                            selected = selectedMode == null,
                            onClick = { selectedMode = null },
                            label = { Text("All Modes", fontSize = 11.sp) },
                            modifier = Modifier.testTag("mode_chip_all")
                        )
                    }
                    items(ClassDeliveryMode.values()) { mode ->
                        val isSelected = selectedMode == mode
                        FilterChip(
                            selected = isSelected,
                            onClick = { selectedMode = if (isSelected) null else mode },
                            label = { Text(mode.shortBadge, fontSize = 11.sp) },
                            leadingIcon = {
                                Icon(
                                    when (mode) {
                                        ClassDeliveryMode.OFFLINE -> Icons.Default.LocationOn
                                        ClassDeliveryMode.ONLINE -> Icons.Default.Laptop
                                        ClassDeliveryMode.HYBRID -> Icons.Default.Devices
                                    },
                                    contentDescription = null,
                                    modifier = Modifier.size(13.dp)
                                )
                            },
                            modifier = Modifier.testTag("mode_chip_${mode.name.lowercase()}")
                        )
                    }
                }
            }

            // Tabs: Classes vs Institutes
            TabRow(
                selectedTabIndex = selectedTab,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp)
                    .testTag("institute_main_tabs")
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Classes & Batches (${filteredClasses.size})", fontWeight = FontWeight.SemiBold) },
                    icon = { Icon(Icons.Default.EventNote, contentDescription = null, modifier = Modifier.size(18.dp)) },
                    modifier = Modifier.testTag("tab_classes_batches")
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("Institutes & Academies (${filteredInstitutes.size})", fontWeight = FontWeight.SemiBold) },
                    icon = { Icon(Icons.Default.Apartment, contentDescription = null, modifier = Modifier.size(18.dp)) },
                    modifier = Modifier.testTag("tab_institutes_academies")
                )
            }

            // Main Content Area
            if (selectedTab == 0) {
                // Classes List
                if (filteredClasses.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Default.SearchOff, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.height(12.dp))
                            Text("No classes found", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text("Try adjusting your search or category filters.", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .testTag("classes_list_view"),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        items(filteredClasses, key = { it.id }) { classItem ->
                            ClassCardItem(
                                classItem = classItem,
                                onCardClick = { selectedClassForDetail = classItem },
                                onCall = { initiatePhoneCall(context, classItem.contactPhone) },
                                onWhatsApp = { initiateWhatsApp(context, classItem.contactWhatsapp, "Hi! I am inquiring about '${classItem.title}' at ${classItem.instituteName} listed on BookMySpace.") },
                                onDirections = { openMaps(context, classItem.location) }
                            )
                        }
                    }
                }
            } else {
                // Institutes List
                if (filteredInstitutes.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Default.Storefront, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.height(12.dp))
                            Text("No institutes found", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text("Try clearing your search query or filters.", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .testTag("institutes_list_view"),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        items(filteredInstitutes, key = { it.id }) { inst ->
                            val instClasses = BookMySpaceRepository.getClassesForInstitute(inst.id)
                            InstituteCardItem(
                                institute = inst,
                                classesCount = instClasses.size,
                                onCardClick = { selectedInstituteForDetail = inst },
                                onCall = { initiatePhoneCall(context, inst.phone) },
                                onWhatsApp = { initiateWhatsApp(context, inst.whatsapp, "Hello ${inst.name}! I found your institute on BookMySpace and would like to learn more about your classes.") },
                                onDirections = { openMaps(context, "${inst.address}, ${inst.city}") }
                            )
                        }
                    }
                }
            }
        }
    }

    // Class Detail Dialog / BottomSheet
    selectedClassForDetail?.let { classItem ->
        ClassDetailDialog(
            classItem = classItem,
            onDismiss = { selectedClassForDetail = null },
            onCall = { initiatePhoneCall(context, classItem.contactPhone) },
            onWhatsApp = { initiateWhatsApp(context, classItem.contactWhatsapp, "Hi! I am inquiring about '${classItem.title}' on BookMySpace.") },
            onDirections = { openMaps(context, classItem.location) }
        )
    }

    // Institute Detail Dialog / BottomSheet
    selectedInstituteForDetail?.let { inst ->
        InstituteDetailDialog(
            institute = inst,
            onDismiss = { selectedInstituteForDetail = null },
            onCall = { initiatePhoneCall(context, inst.phone) },
            onWhatsApp = { initiateWhatsApp(context, inst.whatsapp, "Hi ${inst.name}! I am contacting you from BookMySpace.") },
            onDirections = { openMaps(context, "${inst.address}, ${inst.city}") },
            onClassClick = { classItem ->
                selectedInstituteForDetail = null
                selectedClassForDetail = classItem
            }
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

/**
 * Class Card for Student Discovery
 */
@Composable
fun ClassCardItem(
    classItem: InstituteClass,
    onCardClick: () -> Unit,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onDirections: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCardClick() }
            .testTag("class_card_${classItem.id}"),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column {
            // Optional Header Image
            if (classItem.imageUrls.isNotEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                ) {
                    AsyncImage(
                        model = classItem.imageUrls.first(),
                        contentDescription = classItem.title,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                    Surface(
                        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
                        shape = RoundedCornerShape(bottomStart = 12.dp),
                        modifier = Modifier.align(Alignment.TopEnd)
                    ) {
                        Text(
                            text = classItem.category,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            Column(modifier = Modifier.padding(16.dp)) {
                // Category badge if no image
                if (classItem.imageUrls.isEmpty()) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(6.dp),
                        modifier = Modifier.padding(bottom = 6.dp)
                    ) {
                        Text(
                            text = classItem.category,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    }
                }

                // Title & Mode Badge
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = classItem.title,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        modifier = Modifier.weight(1f),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Surface(
                        color = when (classItem.deliveryMode) {
                            ClassDeliveryMode.OFFLINE -> MaterialTheme.colorScheme.secondaryContainer
                            ClassDeliveryMode.ONLINE -> MaterialTheme.colorScheme.tertiaryContainer
                            ClassDeliveryMode.HYBRID -> MaterialTheme.colorScheme.primaryContainer
                        },
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = classItem.deliveryMode.shortBadge,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        )
                    }
                }

                // Institute & Faculty Name
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "🏛️ ${classItem.instituteName}",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary
                )
                if (classItem.facultyName.isNotBlank()) {
                    Text(
                        text = "👨‍🏫 Faculty: ${classItem.facultyName}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                // Days & Timings
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.width(4.dp))
                            val daysStr = if (classItem.daysOfWeek.isNotEmpty()) classItem.daysOfWeek.joinToString(", ") else "Flexible Schedule"
                            Text(daysStr, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                        }
                        Text(
                            "${classItem.startTime} - ${classItem.endTime}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                // Location info
                if (classItem.location.isNotBlank()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.LocationOn, contentDescription = null, modifier = Modifier.size(13.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(classItem.location, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }

                // Fee and Action Buttons Row
                Spacer(modifier = Modifier.height(12.dp))
                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(4.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Fee", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            if (classItem.feeAmount <= 0.0) "FREE" else "₹${classItem.feeAmount.toInt()} / ${classItem.feeBillingCycle}",
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 14.sp,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }

                    // 1-Tap CTA Buttons
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        if (classItem.contactPhone.isNotBlank()) {
                            FilledTonalIconButton(
                                onClick = onCall,
                                modifier = Modifier
                                    .size(36.dp)
                                    .testTag("class_call_btn_${classItem.id}")
                            ) {
                                Icon(Icons.Default.Phone, contentDescription = "Call", modifier = Modifier.size(16.dp))
                            }
                        }
                        if (classItem.contactWhatsapp.isNotBlank()) {
                            FilledTonalIconButton(
                                onClick = onWhatsApp,
                                modifier = Modifier
                                    .size(36.dp)
                                    .testTag("class_whatsapp_btn_${classItem.id}"),
                                colors = IconButtonDefaults.filledTonalIconButtonColors(
                                    containerColor = Color(0xFF25D366).copy(alpha = 0.15f),
                                    contentColor = Color(0xFF1E7E34)
                                )
                            ) {
                                Icon(Icons.Default.Chat, contentDescription = "WhatsApp", modifier = Modifier.size(16.dp))
                            }
                        }
                        if (classItem.location.isNotBlank()) {
                            FilledTonalIconButton(
                                onClick = onDirections,
                                modifier = Modifier
                                    .size(36.dp)
                                    .testTag("class_maps_btn_${classItem.id}")
                            ) {
                                Icon(Icons.Default.Directions, contentDescription = "Directions", modifier = Modifier.size(16.dp))
                            }
                        }
                        Button(
                            onClick = onCardClick,
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                            modifier = Modifier
                                .height(36.dp)
                                .testTag("class_view_details_btn_${classItem.id}")
                        ) {
                            Text("Details", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }
    }
}

/**
 * Institute Card for Student Discovery
 */
@Composable
fun InstituteCardItem(
    institute: InstituteProfile,
    classesCount: Int,
    onCardClick: () -> Unit,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onDirections: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCardClick() }
            .testTag("institute_card_${institute.id}"),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Logo
                if (institute.logoUrl.isNotBlank()) {
                    AsyncImage(
                        model = institute.logoUrl,
                        contentDescription = institute.name,
                        modifier = Modifier
                            .size(54.dp)
                            .clip(RoundedCornerShape(12.dp)),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Surface(
                        modifier = Modifier.size(54.dp),
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.School, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                }

                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            institute.name,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp,
                            modifier = Modifier.weight(1f, fill = false),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (institute.isVerified) {
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(Icons.Default.Verified, contentDescription = "Verified Academy", tint = Color(0xFF1976D2), modifier = Modifier.size(16.dp))
                        }
                    }
                    Text(
                        "${institute.address}, ${institute.city}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        "👨‍🏫 ${institute.facultyMembers.size} Faculty • 📚 $classesCount Classes Offered",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.secondary
                    )
                }
            }

            // Description snippet
            if (institute.description.isNotBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    institute.description,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Categories
            if (institute.categories.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    institute.categories.take(3).forEach { cat ->
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            shape = RoundedCornerShape(6.dp)
                        ) {
                            Text(cat, fontSize = 10.sp, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp))
                        }
                    }
                }
            }

            // Actions Row
            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(4.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Direct Contact:", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)

                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (institute.phone.isNotBlank()) {
                        FilledTonalIconButton(
                            onClick = onCall,
                            modifier = Modifier
                                .size(36.dp)
                                .testTag("institute_call_btn_${institute.id}")
                        ) {
                            Icon(Icons.Default.Phone, contentDescription = "Call", modifier = Modifier.size(16.dp))
                        }
                    }
                    if (institute.whatsapp.isNotBlank()) {
                        FilledTonalIconButton(
                            onClick = onWhatsApp,
                            modifier = Modifier
                                .size(36.dp)
                                .testTag("institute_whatsapp_btn_${institute.id}"),
                            colors = IconButtonDefaults.filledTonalIconButtonColors(
                                containerColor = Color(0xFF25D366).copy(alpha = 0.15f),
                                contentColor = Color(0xFF1E7E34)
                            )
                        ) {
                            Icon(Icons.Default.Chat, contentDescription = "WhatsApp", modifier = Modifier.size(16.dp))
                        }
                    }
                    FilledTonalIconButton(
                        onClick = onDirections,
                        modifier = Modifier
                            .size(36.dp)
                            .testTag("institute_maps_btn_${institute.id}")
                    ) {
                        Icon(Icons.Default.Directions, contentDescription = "Directions", modifier = Modifier.size(16.dp))
                    }
                    Button(
                        onClick = onCardClick,
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        modifier = Modifier
                            .height(36.dp)
                            .testTag("institute_view_profile_btn_${institute.id}")
                    ) {
                        Text("View Academy", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

/**
 * Class Detail Modal
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClassDetailDialog(
    classItem: InstituteClass,
    onDismiss: () -> Unit,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onDirections: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("class_detail_dialog"),
        title = {
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(classItem.title, fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }
                Text("🏛️ ${classItem.instituteName}", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
            }
        },
        text = {
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Photos
                if (classItem.imageUrls.isNotEmpty()) {
                    item {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(classItem.imageUrls) { imgUrl ->
                                AsyncImage(
                                    model = imgUrl,
                                    contentDescription = null,
                                    modifier = Modifier
                                        .size(160.dp, 100.dp)
                                        .clip(RoundedCornerShape(10.dp)),
                                    contentScale = ContentScale.Crop
                                )
                            }
                        }
                    }
                }

                // Badges Row
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Surface(
                            color = MaterialTheme.colorScheme.primaryContainer,
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(classItem.category, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                        }
                        Surface(
                            color = MaterialTheme.colorScheme.secondaryContainer,
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(classItem.deliveryMode.label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                        }
                    }
                }

                // Description
                if (classItem.description.isNotBlank()) {
                    item {
                        Text("About this Batch:", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Text(classItem.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                // Schedule Details
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text("Schedule & Timing", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Spacer(modifier = Modifier.height(4.dp))
                            val daysStr = if (classItem.daysOfWeek.isNotEmpty()) classItem.daysOfWeek.joinToString(", ") else "Flexible Days"
                            Text("🗓️ Days: $daysStr", fontSize = 12.sp)
                            Text("⏰ Time: ${classItem.startTime} to ${classItem.endTime}", fontSize = 12.sp)
                            if (classItem.durationText.isNotBlank()) {
                                Text("⏳ Duration: ${classItem.durationText}", fontSize = 12.sp)
                            }
                        }
                    }
                }

                // Faculty Profile
                if (classItem.facultyName.isNotBlank()) {
                    item {
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Surface(
                                    modifier = Modifier.size(40.dp),
                                    shape = CircleShape,
                                    color = MaterialTheme.colorScheme.primaryContainer
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Icon(Icons.Default.Person, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    }
                                }
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text("Lead Faculty / Coach", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(classItem.facultyName, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                }
                            }
                        }
                    }
                }

                // Fee Box
                item {
                    Surface(
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Batch Fee:", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            Text(
                                if (classItem.feeAmount <= 0.0) "FREE" else "₹${classItem.feeAmount.toInt()} / ${classItem.feeBillingCycle}",
                                fontWeight = FontWeight.ExtraBold,
                                fontSize = 16.sp,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }

                // Location
                if (classItem.location.isNotBlank()) {
                    item {
                        Text("📍 Location: ${classItem.location}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                // Dynamic Configurable Class Attributes
                item {
                    val customValues = remember(classItem.id) { BookMySpaceRepository.getCustomValuesForListing(classItem.id) }
                    DynamicListingFieldsDisplay(
                        targetCategory = ListingTargetCategory.CLASS,
                        values = customValues
                    )
                }
            }
        },
        confirmButton = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                if (classItem.contactPhone.isNotBlank()) {
                    Button(
                        onClick = onCall,
                        modifier = Modifier.testTag("class_detail_call_action_btn")
                    ) {
                        Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Call Now")
                    }
                }
                if (classItem.contactWhatsapp.isNotBlank()) {
                    Button(
                        onClick = onWhatsApp,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF25D366)),
                        modifier = Modifier.testTag("class_detail_whatsapp_action_btn")
                    ) {
                        Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("WhatsApp")
                    }
                }
                if (classItem.location.isNotBlank()) {
                    OutlinedButton(
                        onClick = onDirections,
                        modifier = Modifier.testTag("class_detail_maps_action_btn")
                    ) {
                        Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Map")
                    }
                }
            }
        }
    )
}

/**
 * Institute Detail Modal
 */
@Composable
fun InstituteDetailDialog(
    institute: InstituteProfile,
    onDismiss: () -> Unit,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onDirections: () -> Unit,
    onClassClick: (InstituteClass) -> Unit
) {
    val classes = remember(institute.id) {
        BookMySpaceRepository.getClassesForInstitute(institute.id).filter { it.isPublished }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("institute_detail_dialog"),
        title = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                    Text(institute.name, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                    if (institute.isVerified) {
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(Icons.Default.Verified, contentDescription = "Verified", tint = Color(0xFF1976D2), modifier = Modifier.size(16.dp))
                    }
                }
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }
        },
        text = {
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Photos gallery
                if (institute.imageUrls.isNotEmpty()) {
                    item {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(institute.imageUrls) { imgUrl ->
                                AsyncImage(
                                    model = imgUrl,
                                    contentDescription = null,
                                    modifier = Modifier
                                        .size(180.dp, 110.dp)
                                        .clip(RoundedCornerShape(10.dp)),
                                    contentScale = ContentScale.Crop
                                )
                            }
                        }
                    }
                }

                // Address & City
                item {
                    Text("📍 Address: ${institute.address}, ${institute.city}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }

                // Description
                if (institute.description.isNotBlank()) {
                    item {
                        Text("About the Academy:", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Text(institute.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                // Faculty Roster
                if (institute.facultyMembers.isNotEmpty()) {
                    item {
                        Text("Faculty & Coaches (${institute.facultyMembers.size}):", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }
                    items(institute.facultyMembers) { fac ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Column(modifier = Modifier.padding(10.dp)) {
                                Text("👨‍🏫 ${fac.name}", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                if (fac.qualification.isNotBlank()) {
                                    Text(fac.qualification, fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
                                }
                                if (fac.subjectOrSpecialization.isNotBlank()) {
                                    Text("Specialization: ${fac.subjectOrSpecialization} (${fac.experienceYears} yrs exp)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                }

                // Available Classes
                item {
                    Text("Active Batches & Classes (${classes.size}):", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
                items(classes) { cls ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onClassClick(cls) },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(cls.title, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                Text("${cls.daysOfWeek.joinToString(", ")} • ${cls.startTime}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Text(
                                "₹${cls.feeAmount.toInt()}",
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.primary,
                                fontSize = 13.sp
                            )
                        }
                    }
                }

                // Dynamic Configurable Institute Attributes
                item {
                    val customValues = remember(institute.id) { BookMySpaceRepository.getCustomValuesForListing(institute.id) }
                    DynamicListingFieldsDisplay(
                        targetCategory = ListingTargetCategory.INSTITUTE,
                        values = customValues
                    )
                }
            }
        },
        confirmButton = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                if (institute.phone.isNotBlank()) {
                    Button(
                        onClick = onCall,
                        modifier = Modifier.testTag("inst_detail_call_action_btn")
                    ) {
                        Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Call")
                    }
                }
                if (institute.whatsapp.isNotBlank()) {
                    Button(
                        onClick = onWhatsApp,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF25D366)),
                        modifier = Modifier.testTag("inst_detail_whatsapp_action_btn")
                    ) {
                        Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("WhatsApp")
                    }
                }
                OutlinedButton(
                    onClick = onDirections,
                    modifier = Modifier.testTag("inst_detail_maps_action_btn")
                ) {
                    Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Directions")
                }
            }
        }
    )
}

// 1-Tap Intent Helpers
fun initiatePhoneCall(context: Context, phone: String) {
    if (phone.isBlank()) {
        Toast.makeText(context, "Phone number unavailable", Toast.LENGTH_SHORT).show()
        return
    }
    try {
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${phone.replace(" ", "")}"))
        context.startActivity(intent)
    } catch (e: Exception) {
        Toast.makeText(context, "Calling $phone", Toast.LENGTH_SHORT).show()
    }
}

fun initiateWhatsApp(context: Context, whatsappNumber: String, message: String) {
    if (whatsappNumber.isBlank()) {
        Toast.makeText(context, "WhatsApp number unavailable", Toast.LENGTH_SHORT).show()
        return
    }
    try {
        val cleanNumber = whatsappNumber.replace("+", "").replace(" ", "").replace("-", "")
        val uri = Uri.parse("https://api.whatsapp.com/send?phone=$cleanNumber&text=${Uri.encode(message)}")
        val intent = Intent(Intent.ACTION_VIEW, uri)
        context.startActivity(intent)
    } catch (e: Exception) {
        Toast.makeText(context, "Opening WhatsApp for $whatsappNumber", Toast.LENGTH_SHORT).show()
    }
}

fun openMaps(context: Context, locationQuery: String) {
    if (locationQuery.isBlank()) {
        Toast.makeText(context, "Location unavailable", Toast.LENGTH_SHORT).show()
        return
    }
    try {
        val uri = Uri.parse("geo:0,0?q=${Uri.encode(locationQuery)}")
        val intent = Intent(Intent.ACTION_VIEW, uri)
        context.startActivity(intent)
    } catch (e: Exception) {
        Toast.makeText(context, "Opening Maps for $locationQuery", Toast.LENGTH_SHORT).show()
    }
}
