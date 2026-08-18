package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.EventBusy
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.CustomerSectionCatalog
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookingScreen(
    venueId: String,
    onBack: () -> Unit,
    onProceedToPayment: (String) -> Unit
) {
    val haptic = LocalHapticFeedback.current
    val venues by BookMySpaceRepository.venues.collectAsState()
    val venue = venues.firstOrNull { it.id == venueId } ?: venues.first()
    val user by BookMySpaceRepository.authUser.collectAsState()
    val bookings by BookMySpaceRepository.bookings.collectAsState()

    var selectedDateStr by remember { mutableStateOf("2026-08-08") }
    
    // Auto-select initial slot
    var selectedSlot by remember(venue, selectedDateStr) {
        val openSlots = venue.timeSlots.filter { slot ->
            !BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, slot.label)
        }
        mutableStateOf<TimeSlot?>(openSlots.firstOrNull() ?: venue.timeSlots.firstOrNull())
    }

    var couponCode by remember { mutableStateOf("") }
    var appliedCoupon by remember { mutableStateOf<String?>(null) }
    var discountAmount by remember { mutableStateOf(0.0) }
    var duplicateErrorMsg by remember { mutableStateOf<String?>(null) }
    var guestCount by remember { mutableIntStateOf(venue.minGuests.coerceAtLeast(1)) }
    var checkOutDateStr by remember { mutableStateOf("2026-08-09") }
    var selectedSharingIndex by remember { mutableIntStateOf(0) }

    val currentSlotLabel = selectedSlot?.label ?: "Standard Slot"

    // Check real-time if current slot on current date is booked
    val isDuplicate = remember(venue.id, selectedDateStr, currentSlotLabel, bookings) {
        BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, currentSlotLabel)
    }

    val dateAvailability = remember(venue.id, selectedDateStr, bookings) {
        BookMySpaceRepository.getDateAvailability(venue.id, selectedDateStr)
    }

    val alternativeSlots = remember(venue.id, selectedDateStr, currentSlotLabel, isDuplicate, bookings) {
        if (isDuplicate) {
            BookMySpaceRepository.getAlternativeSlots(venue.id, selectedDateStr, currentSlotLabel)
        } else emptyList()
    }

    val basePrice by remember(selectedSlot, venue) {
        derivedStateOf { selectedSlot?.priceAmount ?: venue.pricingBaseAmount }
    }
    val taxAmount by remember(basePrice, venue.taxRate) {
        derivedStateOf { basePrice * (venue.taxRate / 100.0) }
    }
    val grandTotal by remember(basePrice, taxAmount, discountAmount) {
        derivedStateOf { (basePrice + taxAmount - discountAmount).coerceAtLeast(0.0) }
    }

    com.bookmyspace.bookmyspace.util.TraceComposition("BookingScreen")

    val bookingSection = CustomerSectionCatalog.sectionForVenue(venue)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(CustomerSectionCatalog.bookingScreenTitle(bookingSection), fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        bottomBar = {
            Surface(tonalElevation = 8.dp) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Total Amount", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            text = "₹${grandTotal.toInt()}",
                            fontSize = 22.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    Button(
                        onClick = {
                            com.bookmyspace.bookmyspace.util.PerformanceTracer.traceBlock("booking_hold_workflow") {
                                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                
                                // Real-time atomic recheck
                                val freshDuplicate = BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, currentSlotLabel)
                                if (freshDuplicate) {
                                    duplicateErrorMsg = "Slot '$currentSlotLabel' on $selectedDateStr was just booked by another customer! Double booking prevented."
                                    return@traceBlock
                                }

                                val slot = selectedSlot
                                val newBooking = Booking(
                                    id = "bk_${System.currentTimeMillis()}",
                                    userId = user?.id ?: "guest",
                                    venueId = venue.id,
                                    venueName = venue.name,
                                    venueImageUrl = venue.coverImageUrl,
                                    slotLabel = slot?.label ?: "Standard Slot",
                                    bookingDate = selectedDateStr,
                                    startTime = slot?.startTime ?: "09:00",
                                    endTime = slot?.endTime ?: "11:00",
                                    baseAmount = basePrice,
                                    taxAmount = taxAmount,
                                    discountAmount = discountAmount,
                                    totalAmount = grandTotal,
                                    couponCode = appliedCoupon,
                                    status = BookingStatus.PENDING,
                                    isPaid = false
                                )
                                BookMySpaceRepository.addBooking(newBooking)
                                onProceedToPayment(newBooking.id)
                            }
                        },
                        modifier = Modifier
                            .height(50.dp)
                            .testTag("confirm_and_pay_button"),
                        enabled = selectedSlot != null &&
                            !isDuplicate &&
                            dateAvailability.status != BookMySpaceRepository.DateAvailabilityStatus.FULLY_BOOKED &&
                            bookingSection != com.bookmyspace.bookmyspace.data.model.CustomerSection.INSTITUTES_CLASSES,
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(if (isDuplicate) "Slot Unavailable" else "Hold Slot & Pay", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                }
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(20.dp)
        ) {
            // Venue Summary Header
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(60.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("🏟️", fontSize = 24.sp)
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(venue.name, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text(venue.fullAddress, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(20.dp))
            }

            item {
                val bookingSectionFields = CustomerSectionCatalog.sectionForVenue(venue)
                when (bookingSectionFields) {
                    com.bookmyspace.bookmyspace.data.model.CustomerSection.FUNCTION_HALLS -> {
                        Text("Event guests: $guestCount", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Slider(
                            value = guestCount.toFloat(),
                            onValueChange = { guestCount = it.toInt() },
                            valueRange = venue.minGuests.toFloat().coerceAtLeast(10f)..venue.maxGuests.toFloat().coerceAtLeast(50f),
                            modifier = Modifier.testTag("hall_guest_count_slider")
                        )
                    }
                    com.bookmyspace.bookmyspace.data.model.CustomerSection.LODGE_ROOMS -> {
                        Text("Check-in $selectedDateStr  ·  Check-out $checkOutDateStr", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text(
                            text = venue.hotelDetails?.roomTypes?.joinToString(" · ") ?: "Standard room",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    com.bookmyspace.bookmyspace.data.model.CustomerSection.PG_HOSTELS -> {
                        val pg = venue.pgDetails
                        val option = pg?.sharingOptions?.getOrNull(selectedSharingIndex)
                        val quote = com.bookmyspace.bookmyspace.util.PgRentCalculator.calculate(venue, selectedSharingIndex)
                        Text("Move-in $selectedDateStr", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text(
                            text = "${option?.typeName ?: "Sharing"} · Rent ₹${quote.monthlyBaseRent.toInt()} + Deposit ₹${quote.securityDeposit.toInt()}",
                            fontSize = 12.sp
                        )
                        if ((pg?.sharingOptions?.size ?: 0) > 1) {
                            TextButton(onClick = {
                                selectedSharingIndex = (selectedSharingIndex + 1) % pg!!.sharingOptions.size
                            }) { Text("Change sharing option") }
                        }
                    }
                    com.bookmyspace.bookmyspace.data.model.CustomerSection.INSTITUTES_CLASSES -> {
                        Text(
                            "This listing is advertising only. Use Call or WhatsApp instead of a hall hold.",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                    null -> {}
                }
                Spacer(modifier = Modifier.height(14.dp))
            }

            // DUPLICATE & SMART ALTERNATIVE SLOTS SUGGESTIONS
            if (isDuplicate || duplicateErrorMsg != null) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth().testTag("duplicate_booking_alert"),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.onErrorContainer)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Selected Slot Unavailable!",
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onErrorContainer,
                                    fontSize = 14.sp
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = duplicateErrorMsg ?: "Another user recently confirmed '$currentSlotLabel' on $selectedDateStr. Prevent duplicate double-booking by selecting an alternative below.",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onErrorContainer
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                }
            }

            if (alternativeSlots.isNotEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth().testTag("smart_alternative_slots_card"),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Lightbulb, contentDescription = null, tint = MaterialTheme.colorScheme.onTertiaryContainer)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Smart Availability Suggestions",
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onTertiaryContainer,
                                    fontSize = 13.sp
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "Recommended alternative open slots for your venue booking:",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onTertiaryContainer
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                alternativeSlots.forEach { alt ->
                                    FilterChip(
                                        selected = false,
                                        onClick = {
                                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                            val found = venue.timeSlots.find { "${it.startTime} - ${it.endTime}" == alt }
                                            if (found != null) {
                                                selectedSlot = found
                                            } else {
                                                selectedDateStr = "2026-08-09"
                                            }
                                            duplicateErrorMsg = null
                                        },
                                        label = { Text(alt, fontSize = 11.sp, fontWeight = FontWeight.Bold) },
                                        leadingIcon = { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(12.dp)) }
                                    )
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(20.dp))
                }
            }

            // Step 1: Interactive Calendar Date Picker
            item {
                Text("Select Date & Availability Calendar", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(10.dp))

                VenueInteractiveCalendar(
                    venueId = venue.id,
                    selectedDateStr = selectedDateStr,
                    onDateSelected = { date ->
                        selectedDateStr = date
                        duplicateErrorMsg = null
                        BookMySpaceRepository.notifySlotInteraction()
                    }
                )

                Spacer(modifier = Modifier.height(20.dp))
            }

            // Quick Shortcut Date Chips
            item {
                val quickDates = listOf(
                    "2026-08-08" to "Today, Aug 08",
                    "2026-08-09" to "Tomorrow, Aug 09",
                    "2026-08-10" to "Sun, Aug 10",
                    "2026-08-11" to "Mon, Aug 11",
                    "2026-08-15" to "Sat, Aug 15"
                )
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(quickDates) { (dateCode, label) ->
                        val isSelected = selectedDateStr == dateCode
                        val avail = BookMySpaceRepository.getDateAvailability(venue.id, dateCode)
                        val isBlocked = avail.status == BookMySpaceRepository.DateAvailabilityStatus.FULLY_BOOKED ||
                                avail.status == BookMySpaceRepository.DateAvailabilityStatus.MAINTENANCE_BLOCKED

                        FilterChip(
                            selected = isSelected,
                            enabled = !isBlocked,
                            onClick = {
                                selectedDateStr = dateCode
                                duplicateErrorMsg = null
                            },
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(label, fontSize = 12.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                    if (avail.status == BookMySpaceRepository.DateAvailabilityStatus.PARTIALLY_AVAILABLE) {
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("• ${avail.availableSlotsCount} open", fontSize = 10.sp, color = Color(0xFFE65100))
                                    }
                                }
                            }
                        )
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }

            // Step 2: Time Slot Selection Header & List
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Available Time Slots", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text(
                            text = "Showing slots for $selectedDateStr (${dateAvailability.availableSlotsCount} available)",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (dateAvailability.status == BookMySpaceRepository.DateAvailabilityStatus.FULLY_BOOKED) {
                        Badge(containerColor = MaterialTheme.colorScheme.errorContainer) {
                            Text("FULLY BOOKED", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onErrorContainer)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            items(venue.timeSlots) { slot ->
                val isSelected = selectedSlot?.id == slot.id
                val isBooked = BookMySpaceRepository.isSlotAlreadyBooked(venue.id, selectedDateStr, slot.label)

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clickable(enabled = !isBooked) {
                            selectedSlot = slot
                            duplicateErrorMsg = null
                            BookMySpaceRepository.notifySlotInteraction()
                        },
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = when {
                            isBooked -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                            isSelected -> MaterialTheme.colorScheme.primaryContainer
                            else -> MaterialTheme.colorScheme.surface
                        }
                    ),
                    border = if (isSelected && !isBooked) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (isBooked) {
                                Icon(Icons.Default.Lock, contentDescription = "Booked", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(20.dp))
                            } else if (isSelected) {
                                Icon(Icons.Default.Check, contentDescription = "Selected", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                            } else {
                                Icon(Icons.Default.CalendarMonth, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = slot.label,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = if (isBooked) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f) else MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "${slot.startTime} - ${slot.endTime}",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Column(horizontalAlignment = Alignment.End) {
                            if (isBooked) {
                                Badge(containerColor = MaterialTheme.colorScheme.errorContainer) {
                                    Text("RESERVED", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onErrorContainer)
                                }
                            } else {
                                Text(
                                    "₹${slot.priceAmount.toInt()}",
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontSize = 16.sp
                                )
                                Text(
                                    "Available",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = Color(0xFF2E7D32)
                                )
                            }
                        }
                    }
                }
            }

            // Step 3: Coupon Discount Box
            item {
                Spacer(modifier = Modifier.height(20.dp))
                Text("Apply Coupon Code", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = couponCode,
                        onValueChange = { couponCode = it.uppercase() },
                        modifier = Modifier.weight(1f),
                        placeholder = { Text("e.g. WELCOME10") },
                        singleLine = true,
                        leadingIcon = { Icon(Icons.Default.ConfirmationNumber, contentDescription = null) }
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = {
                            if (couponCode == "WELCOME10") {
                                appliedCoupon = "WELCOME10"
                                discountAmount = basePrice * 0.10
                            } else if (couponCode == "FESTIVE500") {
                                appliedCoupon = "FESTIVE500"
                                discountAmount = 500.0
                            }
                        }
                    ) {
                        Text("Apply")
                    }
                }
                if (appliedCoupon != null) {
                    Text(
                        "Coupon $appliedCoupon applied! Saved ₹${discountAmount.toInt()}",
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }

            // Step 4: Price Breakdown
            item {
                Spacer(modifier = Modifier.height(20.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Price Breakdown", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Court / Slot Base Fare", fontSize = 13.sp)
                            Text("₹${basePrice.toInt()}", fontSize = 13.sp)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("GST & Taxes (18%)", fontSize = 13.sp)
                            Text("₹${taxAmount.toInt()}", fontSize = 13.sp)
                        }
                        if (discountAmount > 0) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Discount ($appliedCoupon)", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
                                Text("-₹${discountAmount.toInt()}", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                            }
                        }
                        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Grand Total", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text("₹${grandTotal.toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        }
    }
}

/**
 * Interactive Calendar Component for Customer Booking Flow
 */
@Composable
fun VenueInteractiveCalendar(
    venueId: String,
    selectedDateStr: String,
    onDateSelected: (String) -> Unit
) {
    val initialDate = remember(selectedDateStr) {
        try {
            LocalDate.parse(selectedDateStr)
        } catch (e: Exception) {
            LocalDate.of(2026, 8, 8)
        }
    }

    var currentYearMonth by remember { mutableStateOf(YearMonth.from(initialDate)) }
    val today = remember {
        try { LocalDate.of(2026, 8, 8) } catch (e: Exception) { LocalDate.now() }
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("interactive_calendar_card"),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Calendar Header: Month/Year title + Navigation Controls
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.CalendarMonth,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = currentYearMonth.format(DateTimeFormatter.ofPattern("MMMM yyyy")),
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }

                Row {
                    IconButton(
                        onClick = { currentYearMonth = currentYearMonth.minusMonths(1) },
                        enabled = currentYearMonth.isAfter(YearMonth.from(today).minusMonths(1))
                    ) {
                        Icon(Icons.Default.ChevronLeft, contentDescription = "Previous Month")
                    }
                    IconButton(
                        onClick = { currentYearMonth = currentYearMonth.plusMonths(1) },
                        enabled = currentYearMonth.isBefore(YearMonth.from(today).plusMonths(6))
                    ) {
                        Icon(Icons.Default.ChevronRight, contentDescription = "Next Month")
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Legend Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(10.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                CalendarLegendItem(color = Color(0xFF2E7D32), label = "Available")
                CalendarLegendItem(color = Color(0xFFE65100), label = "Partial")
                CalendarLegendItem(color = Color(0xFFC62828), label = "Full/Blocked")
                CalendarLegendItem(color = MaterialTheme.colorScheme.primary, label = "Selected")
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Days of Week Header
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                val weekDays = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
                weekDays.forEach { dayName ->
                    Text(
                        text = dayName,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Days Grid
            val firstDayOfMonth = currentYearMonth.atDay(1)
            val daysInMonth = currentYearMonth.lengthOfMonth()
            val firstDayOfWeekOffset = firstDayOfMonth.dayOfWeek.value % 7 // Sunday = 0
            val totalCells = firstDayOfWeekOffset + daysInMonth
            val totalRows = (totalCells + 6) / 7

            Column {
                for (rowIndex in 0 until totalRows) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        for (colIndex in 0..6) {
                            val cellIndex = rowIndex * 7 + colIndex
                            val dayNumber = cellIndex - firstDayOfWeekOffset + 1

                            if (cellIndex < firstDayOfWeekOffset || dayNumber > daysInMonth) {
                                Box(modifier = Modifier.weight(1f).aspectRatio(1f))
                            } else {
                                val cellDate = currentYearMonth.atDay(dayNumber)
                                val cellDateStr = cellDate.toString()
                                val isToday = cellDate == today
                                val isSelected = cellDateStr == selectedDateStr

                                val availabilityInfo = BookMySpaceRepository.getDateAvailability(venueId, cellDateStr)
                                val status = availabilityInfo.status

                                CalendarDayCell(
                                    modifier = Modifier.weight(1f),
                                    dayNumber = dayNumber,
                                    isToday = isToday,
                                    isSelected = isSelected,
                                    availabilityInfo = availabilityInfo,
                                    onClick = {
                                        if (status == BookMySpaceRepository.DateAvailabilityStatus.AVAILABLE ||
                                            status == BookMySpaceRepository.DateAvailabilityStatus.PARTIALLY_AVAILABLE
                                        ) {
                                            onDateSelected(cellDateStr)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CalendarLegendItem(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(50))
                .background(color)
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun CalendarDayCell(
    modifier: Modifier,
    dayNumber: Int,
    isToday: Boolean,
    isSelected: Boolean,
    availabilityInfo: BookMySpaceRepository.DateAvailabilityInfo,
    onClick: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    val status = availabilityInfo.status

    val isClickable = status == BookMySpaceRepository.DateAvailabilityStatus.AVAILABLE ||
            status == BookMySpaceRepository.DateAvailabilityStatus.PARTIALLY_AVAILABLE

    val backgroundColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        status == BookMySpaceRepository.DateAvailabilityStatus.AVAILABLE -> Color(0xFFE8F5E9)
        status == BookMySpaceRepository.DateAvailabilityStatus.PARTIALLY_AVAILABLE -> Color(0xFFFFF3E0)
        status == BookMySpaceRepository.DateAvailabilityStatus.FULLY_BOOKED -> Color(0xFFFFEBEE)
        status == BookMySpaceRepository.DateAvailabilityStatus.MAINTENANCE_BLOCKED -> Color(0xFFF5F5F5)
        else -> Color.Transparent
    }

    val textColor = when {
        isSelected -> MaterialTheme.colorScheme.onPrimary
        !isClickable -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
        status == BookMySpaceRepository.DateAvailabilityStatus.AVAILABLE -> Color(0xFF1B5E20)
        status == BookMySpaceRepository.DateAvailabilityStatus.PARTIALLY_AVAILABLE -> Color(0xFFE65100)
        else -> MaterialTheme.colorScheme.onSurface
    }

    val badgeColor = when (status) {
        BookMySpaceRepository.DateAvailabilityStatus.AVAILABLE -> Color(0xFF2E7D32)
        BookMySpaceRepository.DateAvailabilityStatus.PARTIALLY_AVAILABLE -> Color(0xFFEF6C00)
        BookMySpaceRepository.DateAvailabilityStatus.FULLY_BOOKED -> Color(0xFFC62828)
        BookMySpaceRepository.DateAvailabilityStatus.MAINTENANCE_BLOCKED -> Color(0xFF616161)
        else -> Color.Transparent
    }

    val borderStroke = when {
        isSelected -> BorderStroke(2.dp, MaterialTheme.colorScheme.primaryContainer)
        isToday -> BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
        else -> null
    }

    Box(
        modifier = modifier
            .padding(2.dp)
            .aspectRatio(1f)
            .clip(RoundedCornerShape(10.dp))
            .background(backgroundColor)
            .then(if (borderStroke != null) Modifier.border(borderStroke, RoundedCornerShape(10.dp)) else Modifier)
            .clickable(enabled = true) {
                if (isClickable) {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onClick()
                } else {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                }
            },
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = dayNumber.toString(),
                fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Medium,
                fontSize = 13.sp,
                color = textColor
            )

            if (isSelected) {
                Text("SELECTED", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimary)
            } else if (isToday && isClickable) {
                Text("TODAY", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            } else when (status) {
                BookMySpaceRepository.DateAvailabilityStatus.PARTIALLY_AVAILABLE -> {
                    Text(
                        "${availabilityInfo.availableSlotsCount} open",
                        fontSize = 6.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFE65100)
                    )
                }
                BookMySpaceRepository.DateAvailabilityStatus.FULLY_BOOKED -> {
                    Text("FULL", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = Color(0xFFC62828))
                }
                BookMySpaceRepository.DateAvailabilityStatus.MAINTENANCE_BLOCKED -> {
                    Text("BLOCK", fontSize = 6.sp, fontWeight = FontWeight.Bold, color = Color(0xFF616161))
                }
                BookMySpaceRepository.DateAvailabilityStatus.AVAILABLE -> {
                    Box(
                        modifier = Modifier
                            .size(4.dp)
                            .clip(RoundedCornerShape(50))
                            .background(badgeColor)
                    )
                }
                else -> {}
            }
        }
    }
}

