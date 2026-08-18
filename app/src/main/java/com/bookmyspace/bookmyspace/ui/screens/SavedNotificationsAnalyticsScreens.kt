package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.service.FCMNotificationManager
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.VenueCard
import com.bookmyspace.bookmyspace.ui.components.VenueOptimizerDashboard

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun SavedScreen(
    onNavigateToVenue: (String) -> Unit,
    sharedTransitionScope: SharedTransitionScope? = null,
    animatedVisibilityScope: AnimatedVisibilityScope? = null
) {
    val venues by BookMySpaceRepository.venues.collectAsState()
    val savedVenues = venues.filter { it.isSaved }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            com.bookmyspace.bookmyspace.ui.components.BookMySpaceLogo()
        }

        Text(
            text = "Saved Venues (${savedVenues.size})",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
        )

        if (savedVenues.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(20.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🔖", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(12.dp))
                    Text("No saved venues yet", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Text("Bookmark your favorite courts and turfs for quick access!", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(savedVenues, key = { it.id }) { venue ->
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onBack: () -> Unit,
    onNavigateToBookings: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val notifications by BookMySpaceRepository.notifications.collectAsState()
    val fcmToken by BookMySpaceRepository.fcmToken.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Notifications", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    TextButton(onClick = { BookMySpaceRepository.markAllNotificationsRead() }) {
                        Text("Mark all read")
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // FCM Push Trigger Status Banner
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("fcm_reminder_status_card"),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.8f)
                    )
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("⏰", fontSize = 22.sp)
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text("FCM 1-Hour Pre-Slot Push Alerts", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                    Text("Automated triggers active for all bookings", fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f))
                                }
                            }
                            Surface(
                                color = MaterialTheme.colorScheme.primary,
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text("ACTIVE ⚡", modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "FCM push reminders are scheduled 1 hour before every booked slot start time. Present your QR code pass at venue check-in.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.9f)
                        )

                        Spacer(modifier = Modifier.height(12.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Token: ${fcmToken.take(18)}...",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f)
                            )
                            Button(
                                onClick = {
                                    FCMNotificationManager.triggerTest1HourFCMAlert(context)
                                },
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.testTag("trigger_test_fcm_reminder_btn")
                            ) {
                                Text("Test 1-Hr FCM Alert", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            items(notifications) { notif ->
                Card(
                    onClick = {
                        if (notif.type == "booking" && onNavigateToBookings != null) {
                            onNavigateToBookings()
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (!notif.isRead) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f) else MaterialTheme.colorScheme.surface
                    )
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = when (notif.type) {
                                    "booking" -> "🎟️"
                                    "welcome" -> "🎉"
                                    "auth" -> "🔑"
                                    else -> "🔔"
                                },
                                fontSize = 18.sp
                            )
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(notif.title, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text(notif.timestamp, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(notif.message, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            if (notif.type == "booking") {
                                Spacer(modifier = Modifier.height(4.dp))
                                Text("Tap to view booking pass →", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
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
fun AnalyticsScreen(onBack: () -> Unit) {
    val bookings by BookMySpaceRepository.bookings.collectAsState()
    val firebaseEvents by BookMySpaceRepository.firebaseEvents.collectAsState()

    var selectedTab by remember { mutableIntStateOf(0) }
    var selectedCategoryFilter by remember { mutableStateOf("All Categories") }
    var appliedRecommendationCount by remember { mutableIntStateOf(0) }

    var customEventName by remember { mutableStateOf("begin_checkout") }
    var eventParamKey by remember { mutableStateOf("venue_id") }
    var eventParamValue by remember { mutableStateOf("v_101") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Firebase Owner Insights & Trends", fontWeight = FontWeight.Bold) },
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
                .padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Firebase Status Banner
            item {
                Surface(
                    color = Color(0xFF1E88E5), // Firebase Blue
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("🔥", fontSize = 22.sp)
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text("Firebase Analytics SDK Engine", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 16.sp)
                                    Text("Real-time telemetry • App ID: fa_app_819230491023", fontSize = 10.sp, color = Color.White.copy(alpha = 0.8f))
                                }
                            }
                            Surface(
                                color = Color(0xFF00E676),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text("ACTIVE ⚡", modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.Black)
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column {
                                Text("TRACKED SESSIONS", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f), fontWeight = FontWeight.Bold)
                                Text("1,420", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            }
                            Column {
                                Text("CONVERSION INDEX", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f), fontWeight = FontWeight.Bold)
                                Text("37.7%", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            }
                            Column {
                                Text("LOGGED EVENTS", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f), fontWeight = FontWeight.Bold)
                                Text("${firebaseEvents.size}", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            }
                        }
                    }
                }
            }

            // Navigation Tabs
            item {
                ScrollableTabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                    indicator = { tabPositions ->
                        TabRowDefaults.Indicator(
                            modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTab])
                        )
                    },
                    edgePadding = 8.dp
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("⚡ Venue Optimizer", fontWeight = FontWeight.Bold, fontSize = 12.sp) }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text("Booking Trends", fontWeight = FontWeight.Bold, fontSize = 12.sp) }
                    )
                    Tab(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        text = { Text("Funnel Analytics", fontWeight = FontWeight.Bold, fontSize = 12.sp) }
                    )
                    Tab(
                        selected = selectedTab == 3,
                        onClick = { selectedTab = 3 },
                        text = { Text("Event Stream", fontWeight = FontWeight.Bold, fontSize = 12.sp) }
                    )
                }
            }

            if (selectedTab == 0) {
                item {
                    val venues by BookMySpaceRepository.venues.collectAsState()
                    VenueOptimizerDashboard(venues = venues)
                }
            } else if (selectedTab == 1) {
                // --- TAB 1: OWNER BOOKING TRENDS & INSIGHTS ---

                // Category Filter Chips
                item {
                    Column {
                        Text("Filter Trends by Venue Category", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(6.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            listOf("All Categories", "Sports & Turf", "Banquet Hall", "Co-Working").forEach { cat ->
                                FilterChip(
                                    selected = selectedCategoryFilter == cat,
                                    onClick = { selectedCategoryFilter = cat },
                                    label = { Text(cat, fontSize = 11.sp) }
                                )
                            }
                        }
                    }
                }

                // 1. Peak Booking Hours Breakdown Card
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text("⏰ Peak Booking Hours Distribution", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                    Text("Based on Firebase Analytics time slot selection events", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Surface(
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                    shape = RoundedCornerShape(8.dp)
                                ) {
                                    Text("5 PM - 9 PM Peak 🔥", modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            val peakHours = listOf(
                                Triple("06:00 - 09:00 (Early Morning)", 0.12f, "142 bookings"),
                                Triple("09:00 - 13:00 (Morning & Midday)", 0.18f, "210 bookings"),
                                Triple("13:00 - 17:00 (Afternoon)", 0.22f, "268 bookings"),
                                Triple("17:00 - 21:00 (Peak Evening 🔥)", 0.38f, "456 bookings"),
                                Triple("21:00 - 00:00 (Night Slots)", 0.10f, "124 bookings")
                            )

                            peakHours.forEach { (slotLabel, ratio, countText) ->
                                val isPeak = ratio >= 0.30f
                                Column(modifier = Modifier.padding(vertical = 5.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(slotLabel, fontSize = 11.sp, fontWeight = if (isPeak) FontWeight.Bold else FontWeight.Medium)
                                        Text("${(ratio * 100).toInt()}% ($countText)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = if (isPeak) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    LinearProgressIndicator(
                                        progress = { ratio },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(8.dp)
                                            .clip(RoundedCornerShape(4.dp)),
                                        color = if (isPeak) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary.copy(alpha = 0.7f),
                                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            Surface(
                                color = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.4f),
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier.padding(10.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("💡", fontSize = 16.sp)
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        "Owner Insight: 38% of total bookings occur in the 5 PM - 9 PM evening slot. Enabling dynamic peak pricing (+15%) boosts revenue yield without lowering booking volume.",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onTertiaryContainer
                                    )
                                }
                            }
                        }
                    }
                }

                // 2. Most-Booked Venue Types / Categories
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("🏟️ Most-Booked Venue Types", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text("Market share and average slot values across platform listings", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                            Spacer(modifier = Modifier.height(14.dp))

                            val venueCategories = listOf(
                                Quadruple("Sports & Turf Arenas 🏏", 0.42f, "Avg ₹2,400 / slot", "+18% MoM"),
                                Quadruple("Banquet & Party Halls 🎉", 0.28f, "Avg ₹28,500 / event", "+24% MoM"),
                                Quadruple("Co-Working & Meeting Hubs 💻", 0.18f, "Avg ₹1,200 / hr", "+12% MoM"),
                                Quadruple("Auditoriums & Studios 🎭", 0.12f, "Avg ₹18,000 / day", "+8% MoM")
                            )

                            venueCategories.forEach { (catName, share, avgPrice, growth) ->
                                Surface(
                                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 4.dp)
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Text(catName, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                            Text("${(share * 100).toInt()}% Share ($growth)", fontWeight = FontWeight.Bold, fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
                                        }
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(avgPrice, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Spacer(modifier = Modifier.height(6.dp))
                                        LinearProgressIndicator(
                                            progress = { share },
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .height(6.dp)
                                                .clip(RoundedCornerShape(3.dp))
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Owner Listing Optimization Recommendations
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("🎯 Smart Recommendations for Listing Owners", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                if (appliedRecommendationCount > 0) {
                                    Surface(
                                        color = Color(0xFF00E676),
                                        shape = RoundedCornerShape(10.dp)
                                    ) {
                                        Text("$appliedRecommendationCount APPLIED", modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp), fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.Black)
                                    }
                                }
                            }
                            Text("Data-driven suggestions powered by Firebase Analytics telemetry", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                            Spacer(modifier = Modifier.height(12.dp))

                            val tips = listOf(
                                Triple("⚡ Enable Instant Time-Slot Booking", "Listings with instant booking enabled convert 34% faster and appear higher in user search results.", "+34% Conversion"),
                                Triple("📸 Add 5+ High-Res Photo Gallery", "Firebase analytics shows 78% of users inspect at least 4 venue images before clicking 'Lock & Pay'.", "+22% Inquiries"),
                                Triple("🏷️ Offer Off-Peak Weekday Discount", "Offering a 10% discount on Tuesday & Wednesday mornings increases idle asset utilization by 28%.", "+28% Occupancy")
                            )

                            tips.forEach { (title, desc, impact) ->
                                var isApplied by remember { mutableStateOf(false) }
                                Surface(
                                    color = if (isApplied) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 4.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.padding(12.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Text(title, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                                Spacer(modifier = Modifier.width(6.dp))
                                                Surface(
                                                    color = MaterialTheme.colorScheme.primary,
                                                    shape = RoundedCornerShape(6.dp)
                                                ) {
                                                    Text(impact, modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp), fontSize = 9.sp, color = MaterialTheme.colorScheme.onPrimary, fontWeight = FontWeight.Bold)
                                                }
                                            }
                                            Spacer(modifier = Modifier.height(4.dp))
                                            Text(desc, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Button(
                                            onClick = {
                                                isApplied = !isApplied
                                                if (isApplied) appliedRecommendationCount++ else appliedRecommendationCount--
                                                BookMySpaceRepository.logAnalyticsEvent("owner_recommendation_applied", mapOf("title" to title), "owner_insights")
                                            },
                                            shape = RoundedCornerShape(8.dp),
                                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                        ) {
                                            Text(if (isApplied) "Applied ✓" else "Apply", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if (selectedTab == 2) {
                // --- TAB 2: CONVERSION FUNNEL ---
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("Venue Booking Flow Conversion Funnel", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text("Tracking user progression from discovery to paid confirmation", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                            Spacer(modifier = Modifier.height(14.dp))

                            val funnelSteps = listOf(
                                Triple("1. Venue Discovery", 1240, 1.0f),
                                Triple("2. Slot & Date Selection", 840, 0.677f),
                                Triple("3. Slot Lock & Checkout", 520, 0.419f),
                                Triple("4. Razorpay Paid Success", 468, 0.377f)
                            )

                            funnelSteps.forEach { (label, count, pct) ->
                                Column(modifier = Modifier.padding(vertical = 6.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                        Text("$count users (${(pct * 100).toInt()}%)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    LinearProgressIndicator(
                                        progress = { pct },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(8.dp)
                                            .clip(RoundedCornerShape(4.dp))
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                // --- TAB 2: LIVE FIREBASE STREAM & DISPATCHER ---
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.background)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("Dispatch Custom Firebase Event", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Spacer(modifier = Modifier.height(8.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                OutlinedTextField(
                                    value = customEventName,
                                    onValueChange = { customEventName = it },
                                    label = { Text("Event Name", fontSize = 10.sp) },
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = eventParamKey,
                                    onValueChange = { eventParamKey = it },
                                    label = { Text("Param Key", fontSize = 10.sp) },
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = eventParamValue,
                                    onValueChange = { eventParamValue = it },
                                    label = { Text("Value", fontSize = 10.sp) },
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Button(
                                onClick = {
                                    if (customEventName.isNotBlank()) {
                                        BookMySpaceRepository.logAnalyticsEvent(
                                            eventName = customEventName.trim(),
                                            params = mapOf(eventParamKey.trim() to eventParamValue.trim()),
                                            category = "custom"
                                        )
                                    }
                                },
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("Log Event to Firebase Stream 🚀", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                        }
                    }
                }

                item {
                    Text("Live Analytics Stream (${firebaseEvents.size} events)", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }

                items(firebaseEvents) { event ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                color = when (event.category) {
                                    "booking_flow" -> MaterialTheme.colorScheme.primaryContainer
                                    "auth" -> MaterialTheme.colorScheme.secondaryContainer
                                    else -> MaterialTheme.colorScheme.tertiaryContainer
                                },
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text(
                                    text = event.category.uppercase(),
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(event.name, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Text("Params: ${event.params}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Text(event.timestamp, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        }
    }
}

private data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)

