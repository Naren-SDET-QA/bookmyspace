package com.bookmyspace.bookmyspace.ui.components

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.QuickBookPreferences
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.LocalizedStrings
import com.bookmyspace.bookmyspace.util.SpeechHelper
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@Composable
fun QuickBookCard(
    onNavigateToVenue: (String) -> Unit,
    onAiHelpClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val speechHelper = remember { SpeechHelper.getInstance(context) }
    val quickPrefs by BookMySpaceRepository.quickBookPreferences.collectAsState()
    val venues by BookMySpaceRepository.venues.collectAsState()

    var showEditPrefsDialog by remember { mutableStateOf(false) }
    var confirmedBooking by remember { mutableStateOf<Booking?>(null) }
    var confirmedVenue by remember { mutableStateOf<Venue?>(null) }
    var selectedTiming by remember { mutableStateOf("This Weekend (Sat)") }

    val timingOptions = listOf("Tomorrow (10 AM)", "This Weekend (Sat)", "Next Saturday")

    // Find best matching venue based on saved preferences
    val matchedVenue = remember(quickPrefs, venues) {
        venues.find { v ->
            v.capacity >= quickPrefs.preferredCapacity &&
                    v.pricingBaseAmount <= quickPrefs.preferredBudgetMax
        } ?: venues.firstOrNull()
    }

    if (showEditPrefsDialog) {
        QuickBookEditPrefsDialog(
            currentPrefs = quickPrefs,
            onDismiss = { showEditPrefsDialog = false },
            onSave = { updated ->
                BookMySpaceRepository.updateQuickBookPreferences(updated)
                showEditPrefsDialog = false
                speechHelper.speak("Quick Book preferences updated. Preferred event is ${updated.preferredEventType} in ${updated.preferredLocation}.")
            }
        )
    }

    Box(modifier = modifier.fillMaxWidth()) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .testTag("quick_book_card"),
            shape = RoundedCornerShape(22.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFFF6F5FE)
            ),
            border = BorderStroke(1.dp, Color(0xFFE2E0FA)),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            shape = CircleShape,
                            color = Color(0xFF4F46E5),
                            modifier = Modifier.size(36.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Default.FlashOn,
                                    contentDescription = "Quick Book",
                                    tint = Color.White,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "1-Tap Quick Book Mode",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF0F172A)
                            )
                            Text(
                                text = "Saved preferences for instant booking",
                                fontSize = 11.5.sp,
                                color = Color(0xFF64748B)
                            )
                        }
                    }

                    Surface(
                        onClick = { showEditPrefsDialog = true },
                        shape = CircleShape,
                        color = Color(0xFFEDE9FE),
                        modifier = Modifier
                            .size(34.dp)
                            .testTag("edit_quick_book_prefs_button")
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.Settings,
                                contentDescription = "Edit Quick Book Profile",
                                tint = Color(0xFF4F46E5),
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // SAVED PREFERENCES CHIPS STRIP
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Surface(
                        onClick = { showEditPrefsDialog = true },
                        shape = RoundedCornerShape(12.dp),
                        color = Color.White,
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                        modifier = Modifier.weight(1.2f)
                    ) {
                        Text(
                            text = "📍 ${quickPrefs.preferredLocation.take(15)}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFF1E293B),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp)
                        )
                    }
                    Surface(
                        onClick = { showEditPrefsDialog = true },
                        shape = RoundedCornerShape(12.dp),
                        color = Color.White,
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                        modifier = Modifier.weight(0.9f)
                    ) {
                        Text(
                            text = "👥 ${quickPrefs.preferredCapacity} guests",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFF1E293B),
                            maxLines = 1,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp)
                        )
                    }
                    Surface(
                        onClick = { showEditPrefsDialog = true },
                        shape = RoundedCornerShape(12.dp),
                        color = Color.White,
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                        modifier = Modifier.weight(1.1f)
                    ) {
                        Text(
                            text = "🎈 ${quickPrefs.preferredEventType}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFF1E293B),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                if (confirmedBooking != null && confirmedVenue != null) {
                    val b = confirmedBooking!!
                    val v = confirmedVenue!!
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE5E7EB))
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF16A34A), modifier = Modifier.size(22.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(text = "1-Tap Quick Booking Confirmed!", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color(0xFF16A34A))
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(text = v.name, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color(0xFF0F172A))
                            Text(text = "Date: ${b.bookingDate} • Guests: ${quickPrefs.preferredCapacity} (${quickPrefs.preferredEventType})", fontSize = 11.5.sp, color = Color(0xFF64748B))
                            Text(text = "Manager Phone: ${v.contactPhone}", fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF0F172A))

                            Spacer(modifier = Modifier.height(10.dp))

                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(
                                    onClick = {
                                        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${v.contactPhone}"))
                                        context.startActivity(intent)
                                    },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(10.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A))
                                ) {
                                    Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(15.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Call", fontSize = 12.sp)
                                }

                                Button(
                                    onClick = {
                                        val url = "https://api.whatsapp.com/send?phone=91${v.contactPhone.replace("-", "")}&text=Hello%20Manager%2C%20Quick%20Booked%20${Uri.encode(v.name)}"
                                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                        context.startActivity(intent)
                                    },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(10.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0D9488))
                                ) {
                                    Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(15.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("WhatsApp", fontSize = 12.sp)
                                }

                                OutlinedButton(
                                    onClick = { onNavigateToVenue(v.id) },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(10.dp)
                                ) {
                                    Text("Details", fontSize = 12.sp)
                                }
                            }
                        }
                    }
                } else if (matchedVenue != null) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE5E7EB))
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = "Best Matched Space for Profile",
                                        fontSize = 11.5.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF4F46E5)
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = matchedVenue.name,
                                        fontSize = 14.5.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF0F172A),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = "📍 ${matchedVenue.city} • Capacity up to ${matchedVenue.capacity}",
                                        fontSize = 11.sp,
                                        color = Color(0xFF64748B)
                                    )
                                }
                                Text(
                                    text = "₹%,d".format(matchedVenue.pricingBaseAmount.toInt()),
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color(0xFF4F46E5)
                                )
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Text(
                                text = "Select Timing",
                                fontSize = 11.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF0F172A)
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                timingOptions.forEach { option ->
                                    val isSelected = selectedTiming == option
                                    Surface(
                                        onClick = { selectedTiming = option },
                                        shape = RoundedCornerShape(10.dp),
                                        color = if (isSelected) Color(0xFFEEEDFE) else Color.White,
                                        border = BorderStroke(
                                            width = if (isSelected) 1.5.dp else 1.dp,
                                            color = if (isSelected) Color(0xFF4F46E5) else Color(0xFFE2E8F0)
                                        ),
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        Text(
                                            text = option,
                                            fontSize = 10.sp,
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                            color = if (isSelected) Color(0xFF4F46E5) else Color(0xFF334155),
                                            textAlign = TextAlign.Center,
                                            modifier = Modifier.padding(vertical = 8.dp, horizontal = 4.dp),
                                            maxLines = 2
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            Button(
                                onClick = {
                                    val cal = Calendar.getInstance()
                                    if (selectedTiming.contains("Tomorrow")) cal.add(Calendar.DAY_OF_YEAR, 1)
                                    else if (selectedTiming.contains("Weekend")) cal.add(Calendar.DAY_OF_YEAR, 3)
                                    else cal.add(Calendar.DAY_OF_YEAR, 7)

                                    val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                                    val dateStr = sdf.format(cal.time)

                                    val newBooking = Booking(
                                        id = "qb_${System.currentTimeMillis()}",
                                        userId = BookMySpaceRepository.authUser.value?.id ?: "user_101",
                                        venueId = matchedVenue.id,
                                        venueName = matchedVenue.name,
                                        venueImageUrl = matchedVenue.coverImageUrl,
                                        slotLabel = "Quick Book (${quickPrefs.preferredEventType})",
                                        bookingDate = dateStr,
                                        startTime = "10:00 AM",
                                        endTime = "06:00 PM",
                                        baseAmount = matchedVenue.pricingBaseAmount,
                                        taxAmount = matchedVenue.pricingBaseAmount * 0.18,
                                        discountAmount = 0.0,
                                        totalAmount = matchedVenue.pricingBaseAmount * 1.18,
                                        status = com.bookmyspace.bookmyspace.data.model.BookingStatus.CONFIRMED,
                                        isPaid = true
                                    )
                                    BookMySpaceRepository.addBooking(newBooking)
                                    confirmedBooking = newBooking
                                    confirmedVenue = matchedVenue
                                    speechHelper.speak("1-Tap Quick Booking successful for ${matchedVenue.name} on ${dateStr}!")
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(46.dp)
                                    .testTag("one_tap_quick_book_now_button"),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4F46E5))
                            ) {
                                Icon(Icons.Default.Bolt, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color.White)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("⚡ 1-TAP INSTANT QUICK BOOK", fontSize = 12.5.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            }
                        }
                    }
                }
            }
        }

        // Overlaid AI Help Pill button at bottom right
        Surface(
            onClick = { onAiHelpClick?.invoke() },
            shape = RoundedCornerShape(20.dp),
            color = Color.White,
            border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
            shadowElevation = 3.dp,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .offset(x = (-8).dp, y = (14).dp)
                .testTag("quick_book_ai_help_button")
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text("🤖", fontSize = 13.sp)
                Text(
                    text = "AI Help",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A)
                )
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = Color(0xFF64748B),
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickBookEditPrefsDialog(
    currentPrefs: QuickBookPreferences,
    onDismiss: () -> Unit,
    onSave: (QuickBookPreferences) -> Unit
) {
    var location by remember { mutableStateOf(currentPrefs.preferredLocation) }
    var capacity by remember { mutableFloatStateOf(currentPrefs.preferredCapacity.toFloat()) }
    var eventType by remember { mutableStateOf(currentPrefs.preferredEventType) }
    var budgetMax by remember { mutableFloatStateOf(currentPrefs.preferredBudgetMax.toFloat()) }

    val eventTypes = listOf("Birthday Party", "Wedding", "PG Room", "Hotel Stay", "Corporate Meeting", "Sports Turf")
    val locationOptions = listOf("Jubilee Hills, Hyderabad", "Madhapur, Hyderabad", "Gachibowli, Hyderabad", "Banjara Hills, Hyderabad", "Kondapur, Hyderabad")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "⚙️ Edit Quick Book Saved Profile",
                fontWeight = FontWeight.ExtraBold,
                fontSize = 18.sp
            )
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Text(
                    text = "Save your default booking choices once for 1-tap instant booking anytime.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // Preferred Event Type
                Column {
                    Text(text = "Preferred Space / Event Type:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(eventTypes) { type ->
                            val isSel = eventType == type
                            FilterChip(
                                selected = isSel,
                                onClick = { eventType = type },
                                label = { Text(type, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
                            )
                        }
                    }
                }

                // Preferred Location
                Column {
                    Text(text = "Preferred Area / Location:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(locationOptions) { loc ->
                            val isSel = location == loc
                            FilterChip(
                                selected = isSel,
                                onClick = { location = loc },
                                label = { Text(loc.split(",")[0], fontSize = 11.sp, fontWeight = FontWeight.Bold) }
                            )
                        }
                    }
                }

                // Guest Capacity
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(text = "Default Guest Capacity:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Text(text = "${capacity.toInt()} Guests", fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    }
                    Slider(
                        value = capacity,
                        onValueChange = { capacity = it },
                        valueRange = 10f..1000f,
                        steps = 99
                    )
                }

                // Max Budget
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(text = "Max Budget per Booking:", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Text(text = "₹%,d".format(budgetMax.toInt()), fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    }
                    Slider(
                        value = budgetMax,
                        onValueChange = { budgetMax = it },
                        valueRange = 5000f..200000f,
                        steps = 39
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onSave(
                        QuickBookPreferences(
                            preferredLocation = location,
                            preferredCapacity = capacity.toInt(),
                            preferredEventType = eventType,
                            preferredBudgetMax = budgetMax.toDouble(),
                            isQuickBookEnabled = true
                        )
                    )
                },
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Save Quick Book Profile")
            }
        },
        dismissButton = {
            OutlinedButton(
                onClick = onDismiss,
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Cancel")
            }
        }
    )
}
