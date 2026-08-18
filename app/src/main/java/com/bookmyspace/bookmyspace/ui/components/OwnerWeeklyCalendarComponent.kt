package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.MaintenanceBlock
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.text.SimpleDateFormat
import java.util.*

data class CalendarDayInfo(
    val dateStr: String, // YYYY-MM-DD
    val dayName: String, // Mon, Tue, etc.
    val dayOfMonth: Int,
    val isToday: Boolean
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OwnerWeeklyCalendarComponent(
    venues: List<Venue>,
    bookings: List<Booking>,
    maintenanceBlocks: List<MaintenanceBlock>,
    modifier: Modifier = Modifier
) {
    var weekOffset by remember { mutableIntStateOf(0) } // 0 = current week
    var selectedVenueFilterId by remember { mutableStateOf<String?>(null) } // null = All Venues
    var showMaintenanceDialog by remember { mutableStateOf(false) }

    // Selected cell info for pre-filling maintenance block dialog
    var targetMaintenanceDate by remember { mutableStateOf<String?>(null) }
    var targetMaintenanceSlot by remember { mutableStateOf<String?>(null) }
    var selectedBookingDetail by remember { mutableStateOf<Booking?>(null) }

    // Dialog Input State for Maintenance
    var selectedVenueForMaintenance by remember { mutableStateOf(venues.firstOrNull()?.id ?: "") }
    var maintenanceReason by remember { mutableStateOf("AC Central Duct Servicing & Filter Replacement") }
    var maintenanceNotes by remember { mutableStateOf("") }
    var selectedSlotForMaintenance by remember { mutableStateOf("Morning (06:00 AM - 10:00 AM)") }

    val slotCategories = listOf(
        "Morning (06:00 AM - 10:00 AM)",
        "Midday (10:00 AM - 02:00 PM)",
        "Afternoon (02:00 PM - 06:00 PM)",
        "Evening (06:00 PM - 10:00 PM)"
    )

    // Compute week days for the current weekOffset
    val weekDays = remember(weekOffset) {
        val cal = Calendar.getInstance()
        // Set to Monday of current week
        cal.firstDayOfWeek = Calendar.MONDAY
        cal.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
        cal.add(Calendar.WEEK_OF_YEAR, weekOffset)

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val dayNameFormat = SimpleDateFormat("EEE", Locale.getDefault())
        val todayStr = dateFormat.format(Date())

        (0..6).map { i ->
            val dayCal = cal.clone() as Calendar
            dayCal.add(Calendar.DAY_OF_MONTH, i)
            val dStr = dateFormat.format(dayCal.time)
            CalendarDayInfo(
                dateStr = dStr,
                dayName = dayNameFormat.format(dayCal.time),
                dayOfMonth = dayCal.get(Calendar.DAY_OF_MONTH),
                isToday = dStr == todayStr
            )
        }
    }

    val startDateLabel = weekDays.firstOrNull()?.let {
        try {
            val d = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(it.dateStr)
            SimpleDateFormat("MMM dd", Locale.getDefault()).format(d)
        } catch (e: Exception) { it.dateStr }
    } ?: ""

    val endDateLabel = weekDays.lastOrNull()?.let {
        try {
            val d = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(it.dateStr)
            SimpleDateFormat("MMM dd, yyyy", Locale.getDefault()).format(d)
        } catch (e: Exception) { it.dateStr }
    } ?: ""

    // Filter bookings & maintenance blocks by selected venue
    val filteredBookings = remember(bookings, selectedVenueFilterId) {
        if (selectedVenueFilterId == null) bookings
        else bookings.filter { it.venueId == selectedVenueFilterId }
    }

    val filteredMaintenance = remember(maintenanceBlocks, selectedVenueFilterId) {
        if (selectedVenueFilterId == null) maintenanceBlocks
        else maintenanceBlocks.filter { it.venueId == selectedVenueFilterId }
    }

    // Weekly metrics computation
    val weekDateStrs = weekDays.map { it.dateStr }.toSet()
    val weeklyBookings = filteredBookings.filter { it.bookingDate in weekDateStrs && (it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.COMPLETED) }
    val weeklyRevenue = weeklyBookings.sumOf { it.totalAmount }
    val weeklyMaintenanceCount = filteredMaintenance.count { it.date in weekDateStrs }
    val totalSlotsInGrid = 7 * 4 // 7 days x 4 time slots
    val occupiedSlots = weeklyBookings.size + weeklyMaintenanceCount
    val occupancyPercent = if (totalSlotsInGrid > 0) ((occupiedSlots.toFloat() / totalSlotsInGrid.toFloat()) * 100).toInt() else 0

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("owner_weekly_calendar_view"),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Top Header: Title & Main Control
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("📅 Weekly Calendar & Maintenance Grid", fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                        Text("Visualize booking density & schedule maintenance slots", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }

                    Button(
                        onClick = {
                            targetMaintenanceDate = weekDays.firstOrNull()?.dateStr
                            targetMaintenanceSlot = slotCategories.first()
                            showMaintenanceDialog = true
                        },
                        shape = RoundedCornerShape(10.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.tertiary),
                        modifier = Modifier.testTag("owner_schedule_maintenance_btn")
                    ) {
                        Icon(Icons.Default.Build, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("🛠️ Block Maintenance", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Week Navigator & Venue Filter
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Week Switcher
                    Surface(
                        color = MaterialTheme.colorScheme.surface,
                        shape = RoundedCornerShape(12.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                        ) {
                            IconButton(
                                onClick = { weekOffset-- },
                                modifier = Modifier
                                    .size(32.dp)
                                    .testTag("calendar_prev_week_btn")
                            ) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Prev Week", modifier = Modifier.size(16.dp))
                            }

                            Text(
                                text = "$startDateLabel - $endDateLabel",
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                modifier = Modifier
                                    .clickable { weekOffset = 0 }
                                    .padding(horizontal = 8.dp)
                            )

                            IconButton(
                                onClick = { weekOffset++ },
                                modifier = Modifier
                                    .size(32.dp)
                                    .testTag("calendar_next_week_btn")
                            ) {
                                Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Next Week", modifier = Modifier.size(16.dp))
                            }
                        }
                    }

                    if (weekOffset != 0) {
                        OutlinedButton(
                            onClick = { weekOffset = 0 },
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                        ) {
                            Text("Today", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Venue Filter Chips
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    FilterChip(
                        selected = selectedVenueFilterId == null,
                        onClick = { selectedVenueFilterId = null },
                        label = { Text("All Venues (${venues.size})", fontSize = 11.sp) },
                        modifier = Modifier.testTag("filter_all_venues")
                    )

                    venues.forEach { venue ->
                        FilterChip(
                            selected = selectedVenueFilterId == venue.id,
                            onClick = { selectedVenueFilterId = venue.id },
                            label = { Text(venue.name, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                            modifier = Modifier.testTag("filter_venue_${venue.id}")
                        )
                    }
                }
            }
        }

        // Weekly Performance Stats Summary
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Card(
                modifier = Modifier.weight(1f),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFE8F5E9))
            ) {
                Column(modifier = Modifier.padding(10.dp)) {
                    Text("Week Revenue", fontSize = 10.sp, color = Color(0xFF1B5E20), fontWeight = FontWeight.Bold)
                    Text("₹${weeklyRevenue.toInt()}", fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF2E7D32))
                }
            }

            Card(
                modifier = Modifier.weight(1f),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
            ) {
                Column(modifier = Modifier.padding(10.dp)) {
                    Text("Confirmed Bookings", fontSize = 10.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Text("${weeklyBookings.size} Slots", fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                }
            }

            Card(
                modifier = Modifier.weight(1f),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0))
            ) {
                Column(modifier = Modifier.padding(10.dp)) {
                    Text("Maintenance Slots", fontSize = 10.sp, color = Color(0xFFE65100), fontWeight = FontWeight.Bold)
                    Text("$weeklyMaintenanceCount Blocked", fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFEF6C00))
                }
            }

            Card(
                modifier = Modifier.weight(1f),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
            ) {
                Column(modifier = Modifier.padding(10.dp)) {
                    Text("Occupancy Rate", fontSize = 10.sp, color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.Bold)
                    Text("$occupancyPercent%", fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }

        // Status Color Legend
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Legend:", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)

            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(Color(0xFF2E7D32)))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Confirmed", fontSize = 10.sp)
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(Color(0xFFEF6C00)))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Maintenance", fontSize = 10.sp)
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(Color(0xFFF57F17)))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Held / Pending", fontSize = 10.sp)
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Available", fontSize = 10.sp)
            }
        }

        // WEEKLY GRID MATRIX TABLE
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp)
            ) {
                // Horizontal Scrollable Container for 7-day columns
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                ) {
                    // Time slot label column header
                    Column(
                        modifier = Modifier.width(110.dp),
                        horizontalAlignment = Alignment.Start
                    ) {
                        Text("TIME SLOT", fontWeight = FontWeight.ExtraBold, fontSize = 11.sp, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(bottom = 8.dp))
                        Spacer(modifier = Modifier.height(6.dp))

                        slotCategories.forEach { slot ->
                            Box(
                                modifier = Modifier
                                    .height(96.dp)
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp, horizontal = 2.dp)
                                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                                    .padding(6.dp),
                                contentAlignment = Alignment.CenterStart
                            ) {
                                Text(
                                    text = slot.replace(" (", "\n("),
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    lineHeight = 13.sp
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    // 7 Day Columns
                    weekDays.forEach { day ->
                        Column(
                            modifier = Modifier
                                .width(135.dp)
                                .padding(horizontal = 3.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            // Day Column Header
                            Surface(
                                color = if (day.isToday) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 8.dp)
                            ) {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    modifier = Modifier.padding(vertical = 6.dp)
                                ) {
                                    Text(
                                        text = day.dayName.uppercase(),
                                        fontWeight = FontWeight.ExtraBold,
                                        fontSize = 10.sp,
                                        color = if (day.isToday) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = "${day.dayOfMonth}",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp,
                                        color = if (day.isToday) Color.White else MaterialTheme.colorScheme.onSurface
                                    )
                                    if (day.isToday) {
                                        Text("TODAY", fontSize = 8.sp, fontWeight = FontWeight.ExtraBold, color = Color.White.copy(alpha = 0.9f))
                                    }
                                }
                            }

                            // Slot cells for this day
                            slotCategories.forEach { slotLabel ->
                                val slotPrefix = slotLabel.substringBefore(" ")

                                // Find matching booking for this day and slot
                                val matchedBooking = filteredBookings.find { b ->
                                    b.bookingDate == day.dateStr &&
                                    (b.slotLabel.contains(slotPrefix, ignoreCase = true) || b.slotLabel.contains(slotLabel, ignoreCase = true)) &&
                                    b.status != BookingStatus.CANCELLED
                                }

                                // Find matching maintenance block
                                val matchedMaintenance = filteredMaintenance.find { m ->
                                    m.date == day.dateStr &&
                                    (m.slotTimeLabel.contains(slotPrefix, ignoreCase = true) || m.slotTimeLabel.contains(slotLabel, ignoreCase = true))
                                }

                                Box(
                                    modifier = Modifier
                                        .height(96.dp)
                                        .fillMaxWidth()
                                        .padding(vertical = 4.dp)
                                ) {
                                    when {
                                        matchedMaintenance != null -> {
                                            // MAINTENANCE BLOCK CARD
                                            Card(
                                                colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0)),
                                                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFEF6C00)),
                                                shape = RoundedCornerShape(8.dp),
                                                modifier = Modifier
                                                    .fillMaxSize()
                                                    .testTag("grid_maintenance_${day.dateStr}_${slotPrefix}")
                                            ) {
                                                Column(
                                                    modifier = Modifier
                                                        .fillMaxSize()
                                                        .padding(6.dp),
                                                    verticalArrangement = Arrangement.SpaceBetween
                                                ) {
                                                    Row(
                                                        modifier = Modifier.fillMaxWidth(),
                                                        horizontalArrangement = Arrangement.SpaceBetween,
                                                        verticalAlignment = Alignment.CenterVertically
                                                    ) {
                                                        Text("🛠️ MAINTENANCE", fontSize = 8.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFE65100))
                                                        IconButton(
                                                            onClick = {
                                                                BookMySpaceRepository.removeMaintenanceBlock(matchedMaintenance.id)
                                                            },
                                                            modifier = Modifier.size(16.dp)
                                                        ) {
                                                            Icon(Icons.Default.Close, contentDescription = "Clear", tint = Color(0xFFE65100), modifier = Modifier.size(12.dp))
                                                        }
                                                    }

                                                    Text(
                                                        text = matchedMaintenance.reason,
                                                        fontSize = 9.sp,
                                                        fontWeight = FontWeight.Bold,
                                                        color = Color(0xFFBF360C),
                                                        maxLines = 2,
                                                        overflow = TextOverflow.Ellipsis,
                                                        lineHeight = 11.sp
                                                    )

                                                    Text("Blocked", fontSize = 8.sp, color = Color(0xFFE65100))
                                                }
                                            }
                                        }

                                        matchedBooking != null -> {
                                            // BOOKING CARD
                                            val isConfirmed = matchedBooking.status == BookingStatus.CONFIRMED || matchedBooking.status == BookingStatus.COMPLETED
                                            val cardBg = if (isConfirmed) Color(0xFFE8F5E9) else Color(0xFFFFF8E1)
                                            val borderColor = if (isConfirmed) Color(0xFF2E7D32) else Color(0xFFF57F17)
                                            val textColor = if (isConfirmed) Color(0xFF1B5E20) else Color(0xFFE65100)

                                            Card(
                                                colors = CardDefaults.cardColors(containerColor = cardBg),
                                                border = androidx.compose.foundation.BorderStroke(1.dp, borderColor),
                                                shape = RoundedCornerShape(8.dp),
                                                modifier = Modifier
                                                    .fillMaxSize()
                                                    .clickable { selectedBookingDetail = matchedBooking }
                                                    .testTag("grid_booking_${day.dateStr}_${slotPrefix}")
                                            ) {
                                                Column(
                                                    modifier = Modifier
                                                        .fillMaxSize()
                                                        .padding(6.dp),
                                                    verticalArrangement = Arrangement.SpaceBetween
                                                ) {
                                                    Row(
                                                        modifier = Modifier.fillMaxWidth(),
                                                        horizontalArrangement = Arrangement.SpaceBetween,
                                                        verticalAlignment = Alignment.CenterVertically
                                                    ) {
                                                        Text(
                                                            if (isConfirmed) "✓ BOOKED" else "⏳ HELD",
                                                            fontSize = 8.sp,
                                                            fontWeight = FontWeight.ExtraBold,
                                                            color = textColor
                                                        )
                                                        Text("₹${matchedBooking.totalAmount.toInt()}", fontSize = 9.sp, fontWeight = FontWeight.ExtraBold, color = textColor)
                                                    }

                                                    Text(
                                                        text = matchedBooking.venueName,
                                                        fontSize = 9.sp,
                                                        fontWeight = FontWeight.Bold,
                                                        color = textColor,
                                                        maxLines = 2,
                                                        overflow = TextOverflow.Ellipsis,
                                                        lineHeight = 11.sp
                                                    )

                                                    Text("Ref: #${matchedBooking.id}", fontSize = 8.sp, color = textColor.copy(alpha = 0.8f))
                                                }
                                            }
                                        }

                                        else -> {
                                            // AVAILABLE SLOT CELL
                                            Surface(
                                                color = MaterialTheme.colorScheme.surface,
                                                border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.15f)),
                                                shape = RoundedCornerShape(8.dp),
                                                modifier = Modifier
                                                    .fillMaxSize()
                                                    .clickable {
                                                        targetMaintenanceDate = day.dateStr
                                                        targetMaintenanceSlot = slotLabel
                                                        selectedSlotForMaintenance = slotLabel
                                                        showMaintenanceDialog = true
                                                    }
                                                    .testTag("grid_available_${day.dateStr}_${slotPrefix}")
                                            ) {
                                                Column(
                                                    modifier = Modifier.fillMaxSize(),
                                                    horizontalAlignment = Alignment.CenterHorizontally,
                                                    verticalArrangement = Arrangement.Center
                                                ) {
                                                    Icon(
                                                        Icons.Default.AddCircleOutline,
                                                        contentDescription = null,
                                                        tint = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f),
                                                        modifier = Modifier.size(16.dp)
                                                    )
                                                    Spacer(modifier = Modifier.height(2.dp))
                                                    Text("Available", fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f))
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
        }
    }

    // SCHEDULE MAINTENANCE BLOCK DIALOG
    if (showMaintenanceDialog) {
        val presetReasons = listOf(
            "AC Central Duct Servicing & Filter Replacement",
            "Court / Floor Resurfacing & Matting Repair",
            "Stage Lighting & Sound System Testing",
            "Sanitization & Deep Cleaning Protocol",
            "Private Reserved Owner Event"
        )

        AlertDialog(
            onDismissRequest = { showMaintenanceDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Build, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Schedule Maintenance Block", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(
                        "Block slot to prevent customer bookings during repairs, cleaning, or upgrades.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    // Venue Selection
                    Text("Select Venue:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    var venueExpanded by remember { mutableStateOf(false) }
                    val currentVenueObj = venues.find { it.id == selectedVenueForMaintenance } ?: venues.firstOrNull()

                    Box {
                        OutlinedButton(
                            onClick = { venueExpanded = true },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(currentVenueObj?.name ?: "Select Venue", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                            }
                        }

                        DropdownMenu(
                            expanded = venueExpanded,
                            onDismissRequest = { venueExpanded = false }
                        ) {
                            venues.forEach { v ->
                                DropdownMenuItem(
                                    text = { Text(v.name, fontSize = 12.sp) },
                                    onClick = {
                                        selectedVenueForMaintenance = v.id
                                        venueExpanded = false
                                    }
                                )
                            }
                        }
                    }

                    // Target Date Display
                    Text("Target Date: ${targetMaintenanceDate ?: weekDays.firstOrNull()?.dateStr}", fontSize = 12.sp, fontWeight = FontWeight.Bold)

                    // Slot Picker
                    Text("Target Time Slot:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        slotCategories.forEach { slot ->
                            val isSelected = selectedSlotForMaintenance == slot
                            FilterChip(
                                selected = isSelected,
                                onClick = { selectedSlotForMaintenance = slot },
                                label = { Text(slot.substringBefore(" "), fontSize = 10.sp) }
                            )
                        }
                    }

                    // Maintenance Reason Preset Chips
                    Text("Maintenance Reason:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        presetReasons.forEach { reason ->
                            Surface(
                                color = if (maintenanceReason == reason) MaterialTheme.colorScheme.tertiaryContainer else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                shape = RoundedCornerShape(8.dp),
                                border = androidx.compose.foundation.BorderStroke(1.dp, if (maintenanceReason == reason) MaterialTheme.colorScheme.tertiary else Color.Transparent),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { maintenanceReason = reason }
                            ) {
                                Row(
                                    modifier = Modifier.padding(8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    RadioButton(
                                        selected = maintenanceReason == reason,
                                        onClick = { maintenanceReason = reason }
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(reason, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                                }
                            }
                        }
                    }

                    OutlinedTextField(
                        value = maintenanceNotes,
                        onValueChange = { maintenanceNotes = it },
                        label = { Text("Vendor / Technician Notes (Optional)", fontSize = 11.sp) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp)
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val vObj = venues.find { it.id == selectedVenueForMaintenance } ?: venues.firstOrNull()
                        if (vObj != null) {
                            BookMySpaceRepository.addMaintenanceBlock(
                                MaintenanceBlock(
                                    id = "mb_${System.currentTimeMillis()}",
                                    venueId = vObj.id,
                                    venueName = vObj.name,
                                    date = targetMaintenanceDate ?: weekDays.firstOrNull()?.dateStr ?: "2026-08-08",
                                    slotTimeLabel = selectedSlotForMaintenance,
                                    reason = maintenanceReason,
                                    notes = maintenanceNotes
                                )
                            )
                        }
                        showMaintenanceDialog = false
                    },
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.testTag("confirm_schedule_maintenance_btn")
                ) {
                    Text("Save Maintenance Block", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showMaintenanceDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // BOOKING DETAIL DIALOG (When owner taps a booking in grid)
    if (selectedBookingDetail != null) {
        val booking = selectedBookingDetail!!
        AlertDialog(
            onDismissRequest = { selectedBookingDetail = null },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.ConfirmationNumber, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Reservation #${booking.id}", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text(booking.venueName, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("📅 Date: ${booking.bookingDate}", fontSize = 12.sp)
                            Text("⏰ Slot: ${booking.slotLabel}", fontSize = 12.sp)
                            Text("💳 Amount Paid: ₹${booking.totalAmount.toInt()}", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            Text(" Status: ${booking.status.name}", fontSize = 12.sp)
                            if (booking.isCheckedIn) {
                                Text("✓ Venue Checked-In at ${booking.checkInTime}", fontSize = 11.sp, color = Color(0xFF2E7D32), fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(onClick = { selectedBookingDetail = null }) {
                    Text("Close")
                }
            }
        )
    }
}
