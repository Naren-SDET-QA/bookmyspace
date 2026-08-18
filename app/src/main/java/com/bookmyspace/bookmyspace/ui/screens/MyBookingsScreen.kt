package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.QrCode2
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

@Composable
fun MyBookingsScreen(
    onPayBooking: (String) -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    val coroutineScope = rememberCoroutineScope()
    val bookings by BookMySpaceRepository.bookings.collectAsState()
    val venues by BookMySpaceRepository.venues.collectAsState()
    val user by BookMySpaceRepository.authUser.collectAsState()

    var selectedTab by remember { mutableStateOf(0) } // 0 = Active, 1 = History

    // Re-book state for returning customers
    var rebookTargetBooking by remember { mutableStateOf<Booking?>(null) }
    var cancelTargetBooking by remember { mutableStateOf<Booking?>(null) }
    var isProcessingRefund by remember { mutableStateOf(false) }
    var refundSuccessResult by remember { mutableStateOf<com.bookmyspace.bookmyspace.util.RazorpayHelper.RazorpayRefundResult?>(null) }
    var refundCancelledBookingName by remember { mutableStateOf("") }
    var selectedBookingForDetails by remember { mutableStateOf<Booking?>(null) }
    var rebookDateIndex by remember { mutableStateOf(0) }
    var rebookSelectedSlot by remember { mutableStateOf<TimeSlot?>(null) }

    val rebookDates = listOf("Today, Aug 06", "Tomorrow, Aug 07", "Sat, Aug 08", "Sun, Aug 09")

    // Booking Details & PDF Invoice Dialog
    if (selectedBookingForDetails != null) {
        val target = selectedBookingForDetails!!
        var currentRating by remember(target.id) { mutableStateOf(target.rating?.toInt() ?: 5) }
        var feedbackText by remember(target.id) { mutableStateOf(target.feedback ?: "") }
        var feedbackSubmitted by remember(target.id) { mutableStateOf(target.rating != null) }

        AlertDialog(
            onDismissRequest = { selectedBookingForDetails = null },
            title = {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Booking Pass & Details", fontWeight = FontWeight.Bold, fontSize = 17.sp)
                    IconButton(onClick = { selectedBookingForDetails = null }) {
                        Icon(Icons.Default.ConfirmationNumber, contentDescription = "Close", tint = MaterialTheme.colorScheme.primary)
                    }
                }
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text(target.venueName, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("📅 Date: ${target.bookingDate}", fontSize = 12.sp)
                            Text("⏰ Slot: ${target.slotLabel}", fontSize = 12.sp)
                            Text("🎫 Pass Ref: #${target.id}", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            Text("💳 Paid: ₹${target.totalAmount.toInt()} (${target.status.name})", fontSize = 12.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    OutlinedButton(
                        onClick = {
                            com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator.generateAndDownloadInvoicePdf(context, target)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("dialog_download_pdf_${target.id}"),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.primary)
                    ) {
                        Text("📄 Download Confirmation PDF Invoice", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }

                    if (target.status == BookingStatus.COMPLETED) {
                        Spacer(modifier = Modifier.height(14.dp))
                        HorizontalDivider()
                        Spacer(modifier = Modifier.height(12.dp))

                        Text("⭐ Session Rating & Feedback", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.height(6.dp))

                        if (feedbackSubmitted) {
                            Surface(
                                color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.6f),
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("Your Rating: ", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                                            for (s in 1..5) {
                                                Icon(
                                                    imageVector = Icons.Default.Star,
                                                    contentDescription = null,
                                                    tint = if (s <= currentRating) Color(0xFFFFB300) else Color.LightGray,
                                                    modifier = Modifier.size(16.dp)
                                                )
                                            }
                                        }
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text("($currentRating/5)", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                    if (feedbackText.isNotBlank()) {
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Text("\"$feedbackText\"", fontSize = 12.sp, style = androidx.compose.ui.text.TextStyle(fontStyle = androidx.compose.ui.text.font.FontStyle.Italic))
                                    }
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text("✓ Review submitted & published to venue", fontSize = 10.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                                }
                            }
                        } else {
                            Column(modifier = Modifier.fillMaxWidth()) {
                                Text("How was your experience at ${target.venueName}?", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Spacer(modifier = Modifier.height(6.dp))

                                Row(
                                    horizontalArrangement = Arrangement.Center,
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    for (star in 1..5) {
                                        IconButton(
                                            onClick = { currentRating = star },
                                            modifier = Modifier
                                                .size(36.dp)
                                                .testTag("star_rating_${target.id}_$star")
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Star,
                                                contentDescription = "$star Stars",
                                                tint = if (star <= currentRating) Color(0xFFFFB300) else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                                                modifier = Modifier.size(28.dp)
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(8.dp))

                                OutlinedTextField(
                                    value = feedbackText,
                                    onValueChange = { feedbackText = it },
                                    label = { Text("Feedback & Comments") },
                                    placeholder = { Text("Share details about court quality, amenities, or staff...") },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("feedback_input_${target.id}"),
                                    maxLines = 3,
                                    shape = RoundedCornerShape(10.dp)
                                )

                                Spacer(modifier = Modifier.height(10.dp))

                                Button(
                                    onClick = {
                                        haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                                        BookMySpaceRepository.submitBookingFeedback(
                                            bookingId = target.id,
                                            rating = currentRating.toDouble(),
                                            feedback = feedbackText
                                        )
                                        feedbackSubmitted = true
                                        selectedBookingForDetails = target.copy(
                                            rating = currentRating.toDouble(),
                                            feedback = feedbackText
                                        )
                                    },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("submit_feedback_button_${target.id}"),
                                    shape = RoundedCornerShape(10.dp)
                                ) {
                                    Text("Submit Rating & Feedback ⭐", fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(onClick = { selectedBookingForDetails = null }) {
                    Text("Close")
                }
            }
        )
    }

    // Refund Receipt Modal
    refundSuccessResult?.let { result ->
        AlertDialog(
            onDismissRequest = { refundSuccessResult = null },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(24.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Booking Cancelled & Refunded", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Your booking for '$refundCancelledBookingName' has been cancelled and recorded in the database.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Surface(
                        color = Color(0xFF0C2340),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Shield, contentDescription = null, tint = Color(0xFF00C853), modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Razorpay Refund", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                }
                                Surface(
                                    color = Color(0xFF00C853).copy(alpha = 0.2f),
                                    shape = RoundedCornerShape(4.dp)
                                ) {
                                    Text(
                                        text = result.status,
                                        color = Color(0xFF00E676),
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            HorizontalDivider(color = Color.White.copy(alpha = 0.15f))
                            Spacer(modifier = Modifier.height(6.dp))
                            Text("💰 Refund Amount: ₹${result.amount.toInt()}", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text("⚡ Refund ID: ${result.refundId}", color = Color.White.copy(alpha = 0.85f), fontSize = 11.sp)
                            Text("🏦 Bank ARN: ${result.arn}", color = Color.White.copy(alpha = 0.85f), fontSize = 11.sp)
                            Text("💳 Credited to: Original Payment Method / Wallet", color = Color.White.copy(alpha = 0.7f), fontSize = 10.sp)
                        }
                    }
                }
            },
            confirmButton = {
                Button(onClick = { refundSuccessResult = null }) {
                    Text("Done")
                }
            }
        )
    }

    // Cancel Booking Dialog
    if (cancelTargetBooking != null) {
        val target = cancelTargetBooking!!
        AlertDialog(
            onDismissRequest = {
                if (!isProcessingRefund) cancelTargetBooking = null
            },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Cancel, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(24.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Cancel Booking & Refund", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text("Venue: ${target.venueName}", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    Text("Date: ${target.bookingDate} | Slot: ${target.slotLabel}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(10.dp))
                    Surface(
                        color = Color(0xFF0C2340),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Shield, contentDescription = null, tint = Color(0xFF00C853), modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Razorpay Refund Gateway", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                }
                                Text("Instant", color = Color(0xFF00E676), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = if (target.isPaid) "Refund Amount: ₹${target.totalAmount.toInt()} (100% Instant Refund)" else "No payment charged (Unpaid)",
                                color = if (target.isPaid) Color(0xFF00E676) else Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Instant refund processed to your original payment method or wallet via Razorpay.",
                                color = Color.White.copy(alpha = 0.75f),
                                fontSize = 10.sp
                            )
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        isProcessingRefund = true
                        haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                        coroutineScope.launch {
                            kotlinx.coroutines.delay(350)
                            val result = BookMySpaceRepository.cancelBookingWithRazorpayRefund(target.id)
                            isProcessingRefund = false
                            refundCancelledBookingName = target.venueName
                            cancelTargetBooking = null
                            refundSuccessResult = result
                        }
                    },
                    enabled = !isProcessingRefund,
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    if (isProcessingRefund) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Processing Refund...", fontSize = 12.sp)
                    } else {
                        Text("Cancel Booking & Refund", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            },
            dismissButton = {
                if (!isProcessingRefund) {
                    TextButton(onClick = { cancelTargetBooking = null }) {
                        Text("Keep Booking")
                    }
                }
            }
        )
    }

    // Re-booking Dialog
    if (rebookTargetBooking != null) {
        val target = rebookTargetBooking!!
        val liveVenue = venues.firstOrNull { it.id == target.venueId } ?: venues.first()
        val activeSlot = rebookSelectedSlot ?: liveVenue.timeSlots.firstOrNull()
        
        // Live server-side price calculation (never reuse old cached price from past booking)
        val basePrice = activeSlot?.priceAmount ?: liveVenue.pricingBaseAmount
        val taxAmount = basePrice * (liveVenue.taxRate / 100.0)
        val grandTotal = basePrice + taxAmount

        AlertDialog(
            onDismissRequest = { rebookTargetBooking = null },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("⚡ Re-Book ${liveVenue.name}", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                }
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("🟢 Live Server Rates & Availability Active", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                        }
                    }
                    Spacer(modifier = Modifier.height(12.dp))

                    Text("1. Select New Date (Mandatory)", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        rebookDates.take(3).forEachIndexed { idx, d ->
                            FilterChip(
                                selected = rebookDateIndex == idx,
                                onClick = { rebookDateIndex = idx },
                                label = { Text(d.split(",")[0], fontSize = 11.sp) }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))
                    Text("2. Select Available Slot", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(6.dp))
                    liveVenue.timeSlots.take(3).forEach { slot ->
                        val isSelected = activeSlot?.id == slot.id
                        Surface(
                            onClick = {
                                rebookSelectedSlot = slot
                                com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.notifySlotInteraction()
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
                        Column {
                            Text("Current Live Total", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("Base ₹${basePrice.toInt()} + GST ${liveVenue.taxRate.toInt()}%", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Text("₹${grandTotal.toInt()}", fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val slot = activeSlot
                        val newBooking = Booking(
                            id = "bk_again_${System.currentTimeMillis()}",
                            userId = user?.id ?: "guest",
                            venueId = liveVenue.id,
                            venueName = liveVenue.name,
                            venueImageUrl = liveVenue.coverImageUrl,
                            slotLabel = slot?.label ?: "Standard Slot",
                            bookingDate = "2026-08-${6 + rebookDateIndex}",
                            startTime = slot?.startTime ?: "09:00",
                            endTime = slot?.endTime ?: "11:00",
                            baseAmount = basePrice,
                            taxAmount = taxAmount,
                            discountAmount = 0.0,
                            totalAmount = grandTotal,
                            couponCode = "REBOOK_LIVE",
                            status = BookingStatus.PENDING,
                            isPaid = false
                        )
                        BookMySpaceRepository.addBooking(newBooking)
                        rebookTargetBooking = null
                        onPayBooking(newBooking.id)
                    },
                    modifier = Modifier.testTag("rebook_confirm_pay_button")
                ) {
                    Text("⚡ Pay & Confirm ₹${grandTotal.toInt()}", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { rebookTargetBooking = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    val filteredBookings by remember(bookings, selectedTab) {
        derivedStateOf {
            if (selectedTab == 0) {
                bookings.filter { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.PENDING || it.status == BookingStatus.HELD }
            } else {
                bookings.filter { it.status == BookingStatus.COMPLETED || it.status == BookingStatus.CANCELLED }
            }
        }
    }

    var reminderMessage by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .testTag("my_bookings_screen")
    ) {
        // App Header Logo with Room Local Database persistence indicator
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            com.bookmyspace.bookmyspace.ui.components.BookMySpaceLogo()
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = {
                        com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator.exportBookingHistoryPdf(context, bookings)
                    },
                    shape = RoundedCornerShape(12.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                    modifier = Modifier.testTag("export_booking_history_pdf_btn")
                ) {
                    Text("📄 Export PDF", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        // Booking Reminder Background Service Status Card
        Surface(
            color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("⏰", fontSize = 18.sp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text("1-Hour Booking Reminder Service", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            Text("WorkManager background worker active • Auto local alerts", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Button(
                        onClick = {
                            val count = com.bookmyspace.bookmyspace.service.BookingReminderManager.checkAndTriggerUpcomingReminders(context)
                            reminderMessage = if (count > 0) "Triggered $count session reminder notification(s)!" else "Checked upcoming bookings: No sessions within 1 hr."
                        },
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text("Check Now 🔄", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                }

                Spacer(modifier = Modifier.height(6.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = reminderMessage ?: "System notifications will trigger 1 hour before booked session starts.",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    OutlinedButton(
                        onClick = {
                            com.bookmyspace.bookmyspace.service.BookingReminderManager.triggerImmediateTestNotification(context)
                            reminderMessage = "Posted 1-hour test notification to system bar! 🔔"
                        },
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text("Test Alert 🔔", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // Tab Row
        TabRow(selectedTabIndex = selectedTab) {
            Tab(selected = selectedTab == 0, onClick = { selectedTab = 0 }) {
                Text(
                    "Upcoming & Active (${bookings.count { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.PENDING || it.status == BookingStatus.HELD }})",
                    modifier = Modifier.padding(vertical = 14.dp),
                    fontWeight = FontWeight.Bold
                )
            }
            Tab(selected = selectedTab == 1, onClick = { selectedTab = 1 }) {
                Text(
                    "Past History (${bookings.count { it.status == BookingStatus.COMPLETED || it.status == BookingStatus.CANCELLED }})",
                    modifier = Modifier.padding(vertical = 14.dp),
                    fontWeight = FontWeight.Bold
                )
            }
        }

        if (filteredBookings.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(20.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🎟️", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(12.dp))
                    Text("No bookings in this tab", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Text("Book a court or turf to see your tickets here!", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(filteredBookings) { booking ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("booking_card_${booking.id}"),
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                val (statusBg, statusFg, statusIcon) = when (booking.status) {
                                    BookingStatus.CONFIRMED -> Triple(Color(0xFFE8F5E9), Color(0xFF2E7D32), Icons.Default.CheckCircle)
                                    BookingStatus.PENDING -> Triple(Color(0xFFFFF8E1), Color(0xFFF57F17), Icons.Default.HourglassTop)
                                    BookingStatus.CANCELLED -> Triple(Color(0xFFFFEBEE), Color(0xFFC62828), Icons.Default.Cancel)
                                    BookingStatus.COMPLETED -> Triple(Color(0xFFE0F2F1), Color(0xFF00695C), Icons.Default.TaskAlt)
                                    BookingStatus.HELD -> Triple(Color(0xFFE1F5FE), Color(0xFF0277BD), Icons.Default.Timer)
                                    BookingStatus.AVAILABLE -> Triple(Color(0xFFF3E5F5), Color(0xFF6A1B9A), Icons.Default.CheckCircle)
                                }

                                Surface(
                                    color = statusBg,
                                    shape = RoundedCornerShape(8.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        Icon(
                                            imageVector = statusIcon,
                                            contentDescription = booking.status.name,
                                            tint = statusFg,
                                            modifier = Modifier.size(14.dp)
                                        )
                                        Text(
                                            text = booking.status.name,
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = statusFg
                                        )
                                    }
                                }
                                Text("Pass #${booking.id}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }

                            Spacer(modifier = Modifier.height(12.dp))
                            Text(booking.venueName, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("📅 Date: ${booking.bookingDate}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("⏰ Slot: ${booking.slotLabel}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            
                            if (booking.status == BookingStatus.COMPLETED) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Surface(
                                    color = if (booking.rating != null) MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.5f) else MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f),
                                    shape = RoundedCornerShape(8.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        if (booking.rating != null) {
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                                Text("Your Rating:", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                                repeat(booking.rating.toInt()) {
                                                    Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFFFB300), modifier = Modifier.size(14.dp))
                                                }
                                                Text("(${booking.rating.toInt()}/5)", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                            }
                                            if (!booking.feedback.isNullOrEmpty()) {
                                                Text(
                                                    text = "\"${booking.feedback}\"",
                                                    fontSize = 11.sp,
                                                    color = MaterialTheme.colorScheme.onTertiaryContainer,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis,
                                                    modifier = Modifier.padding(start = 8.dp)
                                                )
                                            }
                                        } else {
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                                Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFFFB300), modifier = Modifier.size(16.dp))
                                                Text("Rate & Leave Feedback for this completed booking", fontSize = 11.sp, fontWeight = FontWeight.Medium)
                                            }
                                        }
                                    }
                                }
                            }

                            HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text("Total Paid", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("₹${booking.totalAmount.toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                                }

                                if (!booking.isPaid && booking.status == BookingStatus.PENDING) {
                                    Button(
                                        onClick = { onPayBooking(booking.id) },
                                        shape = RoundedCornerShape(10.dp)
                                    ) {
                                        Text("Pay Pending ₹${booking.totalAmount.toInt()}")
                                    }
                                } else {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        if (booking.status == BookingStatus.CONFIRMED || booking.status == BookingStatus.COMPLETED) {
                                            OutlinedButton(
                                                onClick = {
                                                    com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator.generateAndDownloadInvoicePdf(context, booking)
                                                },
                                                shape = RoundedCornerShape(8.dp),
                                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                                                modifier = Modifier.testTag("download_pdf_card_${booking.id}")
                                            ) {
                                                Text("📄 Invoice", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                            }

                                            Surface(
                                                color = MaterialTheme.colorScheme.primaryContainer,
                                                shape = RoundedCornerShape(8.dp),
                                                onClick = { selectedBookingForDetails = booking }
                                            ) {
                                                Row(
                                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                                                    verticalAlignment = Alignment.CenterVertically
                                                ) {
                                                    Icon(Icons.Default.QrCode2, contentDescription = "QR Code", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                                                    Spacer(modifier = Modifier.width(4.dp))
                                                    Text("QR Pass", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                                                }
                                            }
                                        }

                                         if (booking.status == BookingStatus.CONFIRMED || booking.status == BookingStatus.HELD) {
                                            TextButton(
                                                onClick = { cancelTargetBooking = booking },
                                                contentPadding = PaddingValues(horizontal = 6.dp)
                                            ) {
                                                Text("Cancel", color = MaterialTheme.colorScheme.error, fontSize = 11.sp)
                                            }
                                        }

                                        FilledTonalButton(
                                            onClick = {
                                                rebookTargetBooking = booking
                                            },
                                            shape = RoundedCornerShape(8.dp),
                                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                                            modifier = Modifier.testTag("book_again_button_${booking.id}")
                                        ) {
                                            Text("⚡ Re-book", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold)
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
