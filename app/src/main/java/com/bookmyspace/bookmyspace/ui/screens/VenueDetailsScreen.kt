package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Chat
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.GoogleMapInteractiveView
import com.bookmyspace.bookmyspace.ui.components.PeakHoursLineChartComponent
import com.bookmyspace.bookmyspace.ui.components.RatingBadge
import com.bookmyspace.bookmyspace.ui.components.VoiceReadoutButton
import com.bookmyspace.bookmyspace.ui.components.VenueImageCarousel
import com.bookmyspace.bookmyspace.ui.components.DynamicListingFieldsDisplay
import com.bookmyspace.bookmyspace.data.model.CustomerSection
import com.bookmyspace.bookmyspace.data.model.CustomerSectionCatalog
import com.bookmyspace.bookmyspace.data.model.ListingTargetCategory
import com.bookmyspace.bookmyspace.util.PgRentCalculator

@OptIn(ExperimentalMaterial3Api::class, ExperimentalSharedTransitionApi::class, ExperimentalLayoutApi::class)
@Composable
fun VenueDetailsScreen(
    venueId: String,
    onBack: () -> Unit,
    onBookSlot: (String) -> Unit,
    sharedTransitionScope: SharedTransitionScope? = null,
    animatedVisibilityScope: AnimatedVisibilityScope? = null
) {
    val venues by BookMySpaceRepository.venues.collectAsState()
    val venue = venues.firstOrNull { it.id == venueId } ?: venues.first()
    val reviews by BookMySpaceRepository.reviews.collectAsState()
    val venueReviews by remember(reviews, venue.id) {
        derivedStateOf { reviews.filter { it.venueId == venue.id } }
    }
    val bookings by BookMySpaceRepository.bookings.collectAsState()
    val user by BookMySpaceRepository.authUser.collectAsState()
    val isQuickBookingModeEnabled by BookMySpaceRepository.isQuickBookingModeEnabled.collectAsState()

    val userHasConfirmedBooking = remember(bookings, venue.id) {
        bookings.any { it.venueId == venue.id && (it.status == BookingStatus.CONFIRMED || it.isPaid) }
    }

    var newComment by remember { mutableStateOf("") }
    var userRating by remember { mutableStateOf(5) }
    var selectedStarFilter by remember { mutableStateOf<Int?>(null) }
    var selectedReviewTags by remember { mutableStateOf(setOf<String>()) }
    val availableReviewTags = listOf("Clean Courts", "Great Lighting", "Easy Parking", "Helpful Staff", "Good Value", "Well Maintained", "Quality Turf", "Top Equipment")

    val userVenueBookings = remember(bookings, venue.id) {
        bookings.filter { it.venueId == venue.id && (it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.COMPLETED || it.status == BookingStatus.HELD || it.isPaid) }
    }
    val hasBookedThisVenue = userVenueBookings.isNotEmpty()

    var selectedSharingIndex by remember { mutableStateOf(0) }
    var stayTenureMonths by remember { mutableStateOf(1) }

    var showInAppEnquiryDialog by remember { mutableStateOf(false) }
    var enquiryMessage by remember { mutableStateOf("") }
    var enquirySentSuccess by remember { mutableStateOf(false) }

    var showQuickBookDialog by remember { mutableStateOf(false) }
    var quickBookDateIndex by remember { mutableStateOf(0) }
    var quickBookSlot by remember { mutableStateOf<TimeSlot?>(venue.timeSlots.firstOrNull()) }
    var showAnalyticsOverlay by remember { mutableStateOf(false) }

    LaunchedEffect(venue.id) {
        BookMySpaceRepository.recordVenueView(venue.id)
    }

    // Booking Analytics - Least Busy Hours Overlay
    if (showAnalyticsOverlay) {
        AlertDialog(
            onDismissRequest = { showAnalyticsOverlay = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Analytics, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Least Busy Hours Analytics", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            },
            text = {
                Column {
                    Text(
                        "Based on historical venue bookings for ${venue.name}, book during off-peak hours to avoid crowds and get cheaper rates:",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(12.dp))

                    Surface(
                        color = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.4f),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text("🟢 LEAST BUSY / OFF-PEAK (Best Value)", fontWeight = FontWeight.Bold, fontSize = 12.sp, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("• 07:00 AM - 10:00 AM (18% occupancy, 20% OFF)", fontSize = 11.sp)
                            Text("• 02:00 PM - 04:00 PM (28% occupancy, 15% OFF)", fontSize = 11.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Surface(
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text("🟡 MODERATE OCCUPANCY", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("• 10:00 AM - 01:00 PM (54% average occupancy)", fontSize = 11.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Surface(
                        color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.4f),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text("🔴 PEAK HOURS (High Demand)", fontWeight = FontWeight.Bold, fontSize = 12.sp, color = MaterialTheme.colorScheme.onErrorContainer)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("• 06:00 PM - 09:00 PM (88% occupancy - Reserve early)", fontSize = 11.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                    PeakHoursLineChartComponent(venue = venue)
                }
            },
            confirmButton = {
                Button(onClick = { showAnalyticsOverlay = false }, modifier = Modifier.testTag("close_analytics_overlay")) {
                    Text("Got It")
                }
            }
        )
    }

    // In-App Manager Enquiry Dialog (Prevents Platform Bypass)
    if (showInAppEnquiryDialog) {
        AlertDialog(
            onDismissRequest = { showInAppEnquiryDialog = false },
            title = { Text("💬 In-App Manager Enquiry", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text("Send your question directly to ${venue.name} management inside BookMySpace.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(8.dp))
                    Surface(
                        color = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "🔒 Privacy Protection: Direct phone numbers are unlocked automatically upon booking confirmation.",
                            fontSize = 11.sp,
                            modifier = Modifier.padding(8.dp),
                            color = MaterialTheme.colorScheme.onTertiaryContainer
                        )
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = enquiryMessage,
                        onValueChange = { enquiryMessage = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("Ask about slot availability, catering, capacity...") },
                        maxLines = 3
                    )
                    if (enquirySentSuccess) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("✓ Enquiry sent! Manager will reply in-app shortly.", color = Color(0xFF2E7D32), fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (enquiryMessage.isNotBlank()) {
                            BookMySpaceRepository.addNotification(
                                "Enquiry Received",
                                "Manager for ${venue.name} has received your enquiry: \"$enquiryMessage\"",
                                "enquiry"
                            )
                            enquirySentSuccess = true
                            enquiryMessage = ""
                        }
                    }
                ) {
                    Text("Send Message")
                }
            },
            dismissButton = {
                TextButton(onClick = { showInAppEnquiryDialog = false }) {
                    Text("Close")
                }
            }
        )
    }

    // ⚡ 1-Tap Quick Booking Dialog
    if (showQuickBookDialog) {
        val quickDates = listOf("Today, Aug 06", "Tomorrow, Aug 07", "Sat, Aug 08", "Sun, Aug 09")
        val selectedSlot = quickBookSlot ?: venue.timeSlots.firstOrNull()
        val basePrice = selectedSlot?.priceAmount ?: venue.pricingBaseAmount
        val taxAmount = basePrice * (venue.taxRate / 100.0)
        val grandTotal = basePrice + taxAmount

        AlertDialog(
            onDismissRequest = { showQuickBookDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("⚡ 1-Tap Quick Book", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                }
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text("Instant 1-step reservation for ${venue.name}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(12.dp))

                    Text("1. Select Date", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        quickDates.take(3).forEachIndexed { idx, d ->
                            FilterChip(
                                selected = quickBookDateIndex == idx,
                                onClick = {
                                    quickBookDateIndex = idx
                                    BookMySpaceRepository.notifySlotInteraction()
                                },
                                label = { Text(d.split(",")[0], fontSize = 11.sp) }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))
                    Text("2. Select Slot", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(6.dp))
                    venue.timeSlots.take(3).forEach { slot ->
                        val isSelected = selectedSlot?.id == slot.id
                        Surface(
                            onClick = {
                                quickBookSlot = slot
                                BookMySpaceRepository.notifySlotInteraction()
                            },
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 2.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("${slot.label} (${slot.startTime}-${slot.endTime})", fontSize = 12.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                Text("₹${slot.priceAmount.toInt()}", fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                    HorizontalDivider()
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Live Server Price:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Text("₹${grandTotal.toInt()} (Incl. Tax)", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val slot = selectedSlot
                        val newBooking = Booking(
                            id = "bk_qt_${System.currentTimeMillis()}",
                            userId = user?.id ?: "guest",
                            venueId = venue.id,
                            venueName = venue.name,
                            venueImageUrl = venue.coverImageUrl,
                            slotLabel = slot?.label ?: "Standard Slot",
                            bookingDate = "2026-08-${6 + quickBookDateIndex}",
                            startTime = slot?.startTime ?: "09:00",
                            endTime = slot?.endTime ?: "11:00",
                            baseAmount = basePrice,
                            taxAmount = taxAmount,
                            discountAmount = 0.0,
                            totalAmount = grandTotal,
                            couponCode = "QUICK1TAP",
                            status = BookingStatus.PENDING,
                            isPaid = false
                        )
                        BookMySpaceRepository.addBooking(newBooking)
                        showQuickBookDialog = false
                        onBookSlot(venue.id)
                    },
                    modifier = Modifier.testTag("quick_tap_confirm_button")
                ) {
                    Text("⚡ Pay & Confirm ₹${grandTotal.toInt()}", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showQuickBookDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(venue.name, fontWeight = FontWeight.Bold, maxLines = 1) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { showAnalyticsOverlay = true }, modifier = Modifier.testTag("venue_analytics_overlay_button")) {
                        Icon(
                            imageVector = Icons.Default.Analytics,
                            contentDescription = "Least Busy Hours Analytics",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                    VoiceReadoutButton(venue = venue)
                    Spacer(modifier = Modifier.width(4.dp))
                    IconButton(onClick = { BookMySpaceRepository.toggleSaved(venue.id) }) {
                        Icon(
                            imageVector = if (venue.isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                            contentDescription = "Favorite",
                            tint = if (venue.isSaved) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            )
        },
        bottomBar = {
            val context = LocalContext.current
            val cs = venue.contactSettings
            val canDirectPostBooking = userHasConfirmedBooking && cs.allowPostBookingDirectContact

            val showCall = cs.showCall || (canDirectPostBooking && cs.showCall)
            val showWhatsapp = cs.showWhatsapp || (canDirectPostBooking && cs.showWhatsapp)
            val showChat = cs.showChat || (canDirectPostBooking && cs.showChat)
            val showBmsSupport = cs.contactBookMySpace || (!cs.showCall && !cs.showWhatsapp && !cs.showChat && !cs.showOwnerContact)

            Surface(
                tonalElevation = 8.dp,
                color = MaterialTheme.colorScheme.surface
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val listingSection = CustomerSectionCatalog.sectionForVenue(venue)
                    Column(modifier = Modifier.weight(0.9f).padding(end = 4.dp)) {
                        val isPg = listingSection == CustomerSection.PG_HOSTELS
                        val selectedOpt = venue.pgDetails?.sharingOptions?.getOrNull(selectedSharingIndex)
                        val rentText = if (selectedOpt != null) "₹%,d/mo".format(selectedOpt.monthlyRent.toInt()) else if (isPg) "₹%,d/mo".format(venue.pricingBaseAmount.toInt()) else "₹%,d".format(venue.pricingBaseAmount.toInt())
                        
                        Text(text = if (isPg) "Monthly Rent" else "Starting from", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(text = rentText, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary, maxLines = 1)
                    }

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (showCall) {
                            IconButton(
                                onClick = {
                                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${venue.contactPhone}"))
                                    context.startActivity(intent)
                                },
                                modifier = Modifier
                                    .size(36.dp)
                                    .background(Color(0xFF2E7D32), RoundedCornerShape(10.dp))
                                    .testTag("call_owner_button")
                            ) {
                                Icon(Icons.Default.Call, contentDescription = "Call Owner", tint = Color.White, modifier = Modifier.size(16.dp))
                            }
                        }

                        if (showWhatsapp) {
                            IconButton(
                                onClick = {
                                    val url = "https://api.whatsapp.com/send?phone=91${venue.contactPhone.replace("-", "")}&text=Hi%2C%20I%20am%20interested%20in%20${Uri.encode(venue.name)}"
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                    context.startActivity(intent)
                                },
                                modifier = Modifier
                                    .size(36.dp)
                                    .background(Color(0xFF00897B), RoundedCornerShape(10.dp))
                                    .testTag("whatsapp_owner_button")
                            ) {
                                Icon(Icons.Default.Chat, contentDescription = "WhatsApp Owner", tint = Color.White, modifier = Modifier.size(16.dp))
                            }
                        }

                        if (showChat) {
                            IconButton(
                                onClick = { showInAppEnquiryDialog = true },
                                modifier = Modifier
                                    .size(36.dp)
                                    .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(10.dp))
                                    .testTag("chat_owner_button")
                            ) {
                                Icon(Icons.Default.QuestionAnswer, contentDescription = "Chat", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                            }
                        }

                        if (showBmsSupport) {
                            OutlinedButton(
                                onClick = { showInAppEnquiryDialog = true },
                                modifier = Modifier
                                    .height(36.dp)
                                    .testTag("contact_bookmyspace_button"),
                                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("Contact BMS", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                            }
                        }

                        OutlinedButton(
                            onClick = { showQuickBookDialog = true },
                            modifier = Modifier
                                .height(36.dp)
                                .testTag("check_availability_button"),
                            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Text("Check Availability", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }

                        Button(
                            onClick = {
                                if (listingSection == CustomerSection.INSTITUTES_CLASSES) {
                                    showInAppEnquiryDialog = true
                                } else {
                                    onBookSlot(venue.id)
                                }
                            },
                            modifier = Modifier
                                .height(36.dp)
                                .testTag("book_slot_button"),
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Text(
                                text = CustomerSectionCatalog.bookingCtaLabel(listingSection),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // Hero Image Header - Swipeable Page-View Carousel
            item {
                val heroImageModifier = if (sharedTransitionScope != null && animatedVisibilityScope != null) {
                    with(sharedTransitionScope) {
                        Modifier
                            .fillMaxWidth()
                            .sharedElement(
                                rememberSharedContentState(key = "venue-image-${venue.id}"),
                                animatedVisibilityScope = animatedVisibilityScope
                            )
                    }
                } else {
                    Modifier.fillMaxWidth()
                }

                Box(modifier = heroImageModifier) {
                    VenueImageCarousel(
                        venue = venue,
                        height = 260.dp,
                        showCaptions = true,
                        showFullscreenButton = true,
                        showNavButtons = true
                    )
                }
            }

            // Overview Section
            item {
                Column(modifier = Modifier.padding(20.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        val titleModifier = if (sharedTransitionScope != null && animatedVisibilityScope != null) {
                            with(sharedTransitionScope) {
                                Modifier.sharedElement(
                                    rememberSharedContentState(key = "venue-title-${venue.id}"),
                                    animatedVisibilityScope = animatedVisibilityScope
                                )
                            }
                        } else {
                            Modifier
                        }

                        Text(text = venue.name, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = titleModifier)
                        RatingBadge(rating = venue.avgRating, count = venue.ratingCount)
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.LocationOn, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(text = venue.fullAddress, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(text = "About Venue", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = venue.description, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, lineHeight = 18.sp)

                    Spacer(modifier = Modifier.height(16.dp))
                    if (venue.pgDetails != null) {
                        val pg = venue.pgDetails!!
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.4f))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(text = "🏠 PG & Co-Living House Rules", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MaterialTheme.colorScheme.tertiary)
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "👥 Occupancy Type:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = pg.pgType, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "🔒 Gate Lock Timing:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = pg.gateLockTime, fontSize = 12.sp, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.Bold)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "📅 Notice Period:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = "${pg.noticePeriodDays} Days", fontSize = 12.sp)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "💰 Security Deposit:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = "${pg.securityDepositMonths.toInt()} Month Rent (Refundable)", fontSize = 12.sp)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "🍲 Meal Plan:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = pg.mealPlan, fontSize = 12.sp)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "⚡ Electricity & Maint:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = pg.electricityCharges, fontSize = 12.sp)
                                }
                            }
                        }
                    } else {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(text = "Key Specifications", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "👥 Capacity:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = "${venue.minGuests} to ${venue.maxGuests} Guests", fontSize = 12.sp)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "🚗 Parking:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                    Text(text = "${venue.parkingCapacity}+ Cars (Valet Available)", fontSize = 12.sp)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                 Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                     Text(text = "🍽️ Catering Policy:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                     Text(text = venue.foodOptions, fontSize = 12.sp, maxLines = 1)
                                 }
                             }
                         }
                     }

                    val customValues = remember(venue.id) { BookMySpaceRepository.getCustomValuesForListing(venue.id) }
                    val dynamicTargetCategory = remember(venue.category, venue.pgDetails) {
                        val catName = venue.category?.name ?: ""
                        val catSlug = venue.category?.slug ?: ""
                        when {
                            venue.pgDetails != null || catName.contains("Hostel", ignoreCase = true) || catName.contains("PG", ignoreCase = true) || catSlug.contains("pg", ignoreCase = true) -> ListingTargetCategory.PG_HOSTEL
                            catName.contains("Hall", ignoreCase = true) || catName.contains("Banquet", ignoreCase = true) || catSlug.contains("hall", ignoreCase = true) -> ListingTargetCategory.FUNCTION_HALL
                            else -> ListingTargetCategory.VENUE
                        }
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                    DynamicListingFieldsDisplay(
                        targetCategory = dynamicTargetCategory,
                        values = customValues
                    )
                }
            }

            // Peak Booking Hours & Crowd Density Line Chart Data Visualization
            item {
                PeakHoursLineChartComponent(
                    venue = venue,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                )
            }

            // Real OpenStreetMap Location & Directions Section
            item {
                Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) {
                    Text(text = "🗺️ Exact Venue Location & Navigation", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))
                    com.bookmyspace.bookmyspace.ui.components.RealMapViewComponent(
                        venues = listOf(venue),
                        selectedVenueId = venue.id,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(240.dp)
                    )
                }
            }

            // PG Room Sharing Options & Rent Calculator Section
            if (venue.pgDetails != null && venue.pgDetails!!.sharingOptions.isNotEmpty()) {
                item {
                    val pg = venue.pgDetails!!
                    Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                        Text(text = "🛏️ Select Room Sharing Option", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(8.dp))
                        pg.sharingOptions.forEachIndexed { idx, opt ->
                            val isSelected = selectedSharingIndex == idx
                            Card(
                                onClick = { selectedSharingIndex = idx },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp),
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(
                                    containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface
                                ),
                                border = if (isSelected) androidx.compose.foundation.BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null,
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            RadioButton(
                                                selected = isSelected,
                                                onClick = { selectedSharingIndex = idx }
                                            )
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text(text = opt.typeName, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                        }
                                        Text(text = "₹%,d/mo".format(opt.monthlyRent.toInt()), fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                                    }
                                    if (opt.roomFeatures.isNotEmpty()) {
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Row(
                                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                                            modifier = Modifier.padding(start = 36.dp)
                                        ) {
                                            opt.roomFeatures.forEach { feature ->
                                                Surface(
                                                    shape = RoundedCornerShape(8.dp),
                                                    color = MaterialTheme.colorScheme.surfaceVariant
                                                ) {
                                                    Text(
                                                        text = feature,
                                                        fontSize = 10.sp,
                                                        fontWeight = FontWeight.Medium,
                                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Monthly Rent Estimator & Calculator Card
                        Spacer(modifier = Modifier.height(12.dp))
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text(text = "🧮 Monthly Rent Calculator", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.height(8.dp))
                                val breakdown = PgRentCalculator.calculate(venue, selectedSharingIndex, stayTenureMonths)
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(text = "Stay Duration:", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                                    Text(text = "$stayTenureMonths Month${if (stayTenureMonths > 1) "s" else ""}", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                }
                                Slider(
                                    value = stayTenureMonths.toFloat(),
                                    onValueChange = { stayTenureMonths = it.toInt().coerceAtLeast(1) },
                                    valueRange = 1f..12f,
                                    steps = 10,
                                    modifier = Modifier.fillMaxWidth()
                                )
                                HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "Total Rent ($stayTenureMonths mos):", fontSize = 12.sp)
                                    Text(text = "₹%,d".format((breakdown.monthlyBaseRent * stayTenureMonths).toInt()), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(text = "Refundable Security Deposit:", fontSize = 12.sp)
                                    Text(text = "₹%,d".format(breakdown.securityDeposit.toInt()), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFF2E7D32))
                                }
                                if (breakdown.monthlyMaintenanceFee > 0) {
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Text(text = "Maintenance Charges ($stayTenureMonths mos):", fontSize = 12.sp)
                                        Text(text = "₹%,d".format((breakdown.monthlyMaintenanceFee * stayTenureMonths).toInt()), fontSize = 12.sp)
                                    }
                                }
                                HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(text = "Estimated Total Move-in Payable:", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                                    Text(text = "₹%,d".format(breakdown.totalTenureCost.toInt()), fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                }
            }

            // Venue Packages Section
            if (venue.packages.isNotEmpty()) {
                item {
                    Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                        Text(text = "Available Booking Packages", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(8.dp))
                        venue.packages.forEach { pkg ->
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp),
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(text = pkg.name, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MaterialTheme.colorScheme.primary)
                                        Text(text = "₹%,d".format(pkg.priceAmount.toInt()), fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(text = pkg.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(text = "Includes:", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                    pkg.itemsIncluded.forEach { inc ->
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(12.dp), tint = MaterialTheme.colorScheme.primary)
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text(text = inc, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface)
                                        }
                                    }
                                    if (pkg.vegPlatePrice > 0 || pkg.nonVegPlatePrice > 0) {
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Text(text = "Veg Plate: ₹${pkg.vegPlatePrice.toInt()}/person", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = Color(0xFF2E7D32))
                                            Text(text = "Non-Veg Plate: ₹${pkg.nonVegPlatePrice.toInt()}/person", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = Color(0xFFC62828))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Venue Addons Section
            if (venue.addons.isNotEmpty()) {
                item {
                    Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                        Text(text = "Custom Add-ons & Extra Services", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(8.dp))
                        venue.addons.forEach { addon ->
                            Surface(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 3.dp),
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(text = addon.name, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        if (addon.description.isNotBlank()) {
                                            Text(text = addon.description, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                    }
                                    Text(text = "+₹%,d".format(addon.priceAmount.toInt()), fontWeight = FontWeight.Bold, fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                }
            }

            // Facilities Section
            item {
                Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                    Text(text = "Facilities & Amenities", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        venue.facilities.forEach { facility ->
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(text = facility.facility, fontSize = 12.sp)
                                }
                            }
                        }
                    }
                }
            }

            // Venue Rules
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(text = "Venue Rules & Guidelines", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        }
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(text = venue.rules, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            // -----------------------------------------------------------------
            // Reviews & Ratings Breakdown Header Card
            // -----------------------------------------------------------------
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                        .testTag("venue_reviews_summary_card"),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Player Reviews & Ratings",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Surface(
                                color = MaterialTheme.colorScheme.primaryContainer,
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text(
                                    text = "${venueReviews.size} Verified Reviews",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Score Box
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.padding(end = 20.dp)
                            ) {
                                Text(
                                    text = "${venue.avgRating}",
                                    fontSize = 32.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Row {
                                    repeat(5) { index ->
                                        val isFilled = (index + 1) <= Math.round(venue.avgRating)
                                        Text(
                                            text = if (isFilled) "★" else "☆",
                                            fontSize = 14.sp,
                                            color = Color(0xFFFFB800)
                                        )
                                    }
                                }
                                Text(
                                    text = "out of 5.0",
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }

                            // Rating Breakdown Bars
                            Column(modifier = Modifier.weight(1f)) {
                                (5 downTo 1).forEach { starLevel ->
                                    val countForStar = venueReviews.count { Math.round(it.rating).toInt() == starLevel }
                                    val fraction = if (venueReviews.isNotEmpty()) countForStar.toFloat() / venueReviews.size else 0f
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.padding(vertical = 1.dp)
                                    ) {
                                        Text("${starLevel}★", fontSize = 10.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(22.dp))
                                        LinearProgressIndicator(
                                            progress = { fraction },
                                            modifier = Modifier
                                                .weight(1f)
                                                .height(6.dp)
                                                .clip(RoundedCornerShape(3.dp)),
                                            color = Color(0xFFFFB800),
                                            trackColor = MaterialTheme.colorScheme.surfaceVariant
                                        )
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text("$countForStar", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Star Filter Chips
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            FilterChip(
                                selected = selectedStarFilter == null,
                                onClick = { selectedStarFilter = null },
                                label = { Text("All (${venueReviews.size})", fontSize = 10.sp, fontWeight = FontWeight.Bold) }
                            )
                            (5 downTo 1).forEach { star ->
                                val starCount = venueReviews.count { Math.round(it.rating).toInt() == star }
                                FilterChip(
                                    selected = selectedStarFilter == star,
                                    onClick = {
                                        selectedStarFilter = if (selectedStarFilter == star) null else star
                                    },
                                    label = { Text("$star★ ($starCount)", fontSize = 10.sp) }
                                )
                            }
                        }
                    }
                }
            }

            // User Review Cards List (filtered by star level)
            val filteredVenueReviews = if (selectedStarFilter == null) {
                venueReviews
            } else {
                venueReviews.filter { Math.round(it.rating).toInt() == selectedStarFilter }
            }

            if (filteredVenueReviews.isEmpty()) {
                item {
                    Text(
                        text = if (selectedStarFilter == null) "No reviews yet. Book a slot and share your experience!" else "No ${selectedStarFilter}★ reviews found.",
                        fontSize = 12.sp,
                        fontStyle = FontStyle.Italic,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                    )
                }
            } else {
                items(filteredVenueReviews) { review ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 4.dp)
                            .testTag("user_review_card_${review.id}"),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    // User Avatar Circle
                                    Box(
                                        modifier = Modifier
                                            .size(28.dp)
                                            .background(MaterialTheme.colorScheme.primaryContainer, CircleShape),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = review.userName.take(1).uppercase(),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Column {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                            Text(text = review.userName, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                            if (review.verifiedBooking) {
                                                Surface(
                                                    color = Color(0xFFE8F5E9),
                                                    shape = RoundedCornerShape(4.dp)
                                                ) {
                                                    Row(
                                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp),
                                                        verticalAlignment = Alignment.CenterVertically
                                                    ) {
                                                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(10.dp))
                                                        Spacer(modifier = Modifier.width(2.dp))
                                                        Text("Verified Booker", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color(0xFF2E7D32))
                                                    }
                                                }
                                            }
                                        }
                                        Text(text = review.date, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                RatingBadge(rating = review.rating)
                            }

                            if (review.tags.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(6.dp))
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    review.tags.forEach { tag ->
                                        Surface(
                                            color = MaterialTheme.colorScheme.surfaceVariant,
                                            shape = RoundedCornerShape(6.dp)
                                        ) {
                                            Text(
                                                text = tag,
                                                fontSize = 9.sp,
                                                fontWeight = FontWeight.Medium,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = review.comment,
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurface,
                                lineHeight = 16.sp
                            )
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // Interactive Review Submission Box for Booked Venues
            // -----------------------------------------------------------------
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 12.dp)
                        .testTag("write_review_card"),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (hasBookedThisVenue) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                        else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
                    )
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = "Rate & Review Your Experience",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = if (hasBookedThisVenue) "✓ Verified Booking (${userVenueBookings.firstOrNull()?.bookingRef ?: "Confirmed"}) • ${user?.fullName ?: "Player"}"
                                    else "Leave a community review • ${user?.fullName ?: "Guest"}",
                                    fontSize = 11.sp,
                                    color = if (hasBookedThisVenue) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }

                            if (hasBookedThisVenue) {
                                Surface(
                                    color = Color(0xFFE8F5E9),
                                    shape = RoundedCornerShape(6.dp)
                                ) {
                                    Text(
                                        text = "Booked",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF2E7D32),
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Star Rating Selector
                        Text(
                            text = "Select your star rating (1 to 5 stars):",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            (1..5).forEach { star ->
                                val isSelected = star <= userRating
                                Surface(
                                    onClick = { userRating = star },
                                    shape = CircleShape,
                                    color = if (isSelected) Color(0xFFFFB800) else MaterialTheme.colorScheme.surfaceVariant,
                                    modifier = Modifier
                                        .size(36.dp)
                                        .testTag("star_rating_${star}_btn")
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Text(
                                            text = "$star ★",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                            Spacer(modifier = Modifier.width(4.dp))
                            val ratingLabel = when (userRating) {
                                5 -> "5.0 ★ Excellent"
                                4 -> "4.0 ★ Very Good"
                                3 -> "3.0 ★ Average"
                                2 -> "2.0 ★ Poor"
                                else -> "1.0 ★ Disappointing"
                            }
                            Text(
                                text = ratingLabel,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        // Quick Feedback Tags Selector
                        Text(
                            text = "Quick Highlights (optional):",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            availableReviewTags.forEach { tag ->
                                val isSelected = selectedReviewTags.contains(tag)
                                FilterChip(
                                    selected = isSelected,
                                    onClick = {
                                        selectedReviewTags = if (isSelected) selectedReviewTags - tag else selectedReviewTags + tag
                                    },
                                    label = { Text(tag, fontSize = 10.sp) }
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = newComment,
                            onValueChange = { newComment = it },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("review_comment_input"),
                            placeholder = { Text("Share details about court condition, lighting, staff service, clean amenities, or parking...") },
                            maxLines = 4,
                            shape = RoundedCornerShape(12.dp)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "${newComment.length}/500",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )

                            Button(
                                onClick = {
                                    if (newComment.isNotBlank()) {
                                        val matchedBookingId = userVenueBookings.firstOrNull()?.id
                                        BookMySpaceRepository.addReview(
                                            venueId = venue.id,
                                            comment = newComment,
                                            rating = userRating.toDouble(),
                                            bookingId = matchedBookingId,
                                            tags = selectedReviewTags.toList()
                                        )
                                        newComment = ""
                                        selectedReviewTags = emptySet()
                                    }
                                },
                                enabled = newComment.isNotBlank(),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.testTag("submit_review_button")
                            ) {
                                Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Publish Review ⭐", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        }
    }
}
