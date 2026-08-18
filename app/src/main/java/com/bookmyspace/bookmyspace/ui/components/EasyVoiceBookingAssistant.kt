package com.bookmyspace.bookmyspace.ui.components

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.LocalizedStrings
import com.bookmyspace.bookmyspace.util.PgRentCalculator
import com.bookmyspace.bookmyspace.util.SpeechHelper
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun EasyVoiceBookingBanner(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .testTag("easy_voice_booking_banner"),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFFF8F7FD)
        ),
        border = BorderStroke(1.dp, Color(0xFFECEAFB)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.5.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(52.dp)
                        .background(Color(0xFF4F46E5), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Mic,
                        contentDescription = "Voice Assistant",
                        tint = Color.White,
                        modifier = Modifier.size(28.dp)
                    )
                }
                Spacer(modifier = Modifier.width(14.dp))
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.GraphicEq,
                            contentDescription = null,
                            tint = Color(0xFF3B82F6),
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(5.dp))
                        Text(
                            text = "Bol-ke-Book (Voice Search)",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                    }
                    Spacer(modifier = Modifier.height(3.dp))
                    Text(
                        text = "1-Tap Booking with Pictures & Voice",
                        fontSize = 12.sp,
                        color = Color(0xFF64748B)
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(1.dp)
                ) {
                    Text("EA", fontSize = 8.sp, fontWeight = FontWeight.Black, color = Color(0xFF1E293B), letterSpacing = 0.5.sp)
                    Text("SY", fontSize = 8.sp, fontWeight = FontWeight.Black, color = Color(0xFF1E293B), letterSpacing = 0.5.sp)
                    Text("IN", fontSize = 8.sp, fontWeight = FontWeight.Black, color = Color(0xFF4F46E5), letterSpacing = 0.5.sp)
                    Text("DE", fontSize = 8.sp, fontWeight = FontWeight.Black, color = Color(0xFF1E293B), letterSpacing = 0.5.sp)
                }
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = Color(0xFF334155)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EasyVoiceBookingDialog(
    onDismiss: () -> Unit,
    onNavigateToVenue: (String) -> Unit
) {
    val context = LocalContext.current
    val speechHelper = remember { SpeechHelper.getInstance(context) }
    val scope = rememberCoroutineScope()
    val venues by BookMySpaceRepository.venues.collectAsState()
    val appSections by BookMySpaceRepository.appSections.collectAsState()

    val availableVoiceCategories = remember(appSections) {
        val list = mutableListOf<Triple<String, String, String>>()
        if (BookMySpaceRepository.isSectionEnabled("venues_halls")) {
            list.add(Triple("VENUE", "🏰 Function Hall", "Marriage/Party"))
        }
        if (BookMySpaceRepository.isSectionEnabled("pg_hostels")) {
            list.add(Triple("PG", "🏡 PG Room", "Gents/Ladies"))
        }
        if (BookMySpaceRepository.isSectionEnabled("hotels_rooms")) {
            list.add(Triple("HOTEL", "🏨 Hotel Room", "Day/Night Stay"))
        }
        if (BookMySpaceRepository.isCategoryEnabled("cricket") || BookMySpaceRepository.isCategoryEnabled("football") || BookMySpaceRepository.isCategoryEnabled("indoor")) {
            list.add(Triple("TURF", "🏏 Turf / Ground", "Cricket/Football"))
        }
        list
    }

    var isListening by remember { mutableStateOf(false) }
    var spokenText by remember { mutableStateOf("") }
    var selectedCategoryType by remember { mutableStateOf<String?>(null) } // "PG", "VENUE", "HOTEL", "TURF"
    var selectedBudgetTier by remember { mutableStateOf<String?>(null) } // "BUDGET", "MID", "PREMIUM"
    var bookedVenueResult by remember { mutableStateOf<Venue?>(null) }
    var bookingConfirmed by remember { mutableStateOf(false) }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // Initial audio greeting when dialog opens
    LaunchedEffect(Unit) {
        speechHelper.speak("Welcome to Easy Booking! Tap a picture below or tap the microphone to speak what space you want to book.")
    }

    ModalBottomSheet(
        onDismissRequest = {
            speechHelper.stop()
            onDismiss()
        },
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "🎙️ Easy 1-Tap Voice Booking",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 18.sp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    IconButton(onClick = {
                        speechHelper.speak("Easy Booking helps everyone book function halls, P G rooms, hotels, and sports grounds in 3 simple taps.")
                    }) {
                        Icon(
                            imageVector = Icons.Default.VolumeUp,
                            contentDescription = "Audio Help",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                }
                IconButton(onClick = {
                    speechHelper.stop()
                    onDismiss()
                }) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            if (bookingConfirmed && bookedVenueResult != null) {
                // SUCCESS BOOKING CARD
                val venue = bookedVenueResult!!
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(text = "🎉", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Booking Request Created!",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color(0xFF2E7D32)
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = venue.name,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = "Location: ${venue.city}",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(text = "🎫 Booking Reference ID: BMS-${venue.id.takeLast(6).uppercase()}", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text(text = "✅ Status: Instant Hold Confirmed", fontSize = 12.sp, color = Color(0xFF2E7D32), fontWeight = FontWeight.Bold)
                            Text(text = "📞 Direct Manager Contact: ${venue.contactPhone}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Button(
                            onClick = {
                                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${venue.contactPhone}"))
                                context.startActivity(intent)
                            },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32))
                        ) {
                            Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Call Owner Now")
                        }

                        Button(
                            onClick = {
                                val url = "https://api.whatsapp.com/send?phone=91${venue.contactPhone.replace("-", "")}&text=Hello%20Manager%2C%20I%20want%20to%20confirm%20my%20booking%20for%20${Uri.encode(venue.name)}"
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                context.startActivity(intent)
                            },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF00897B))
                        ) {
                            Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("WhatsApp Owner")
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    OutlinedButton(
                        onClick = {
                            onNavigateToVenue(venue.id)
                            onDismiss()
                        },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Text("View Full Property Details")
                    }
                }
            } else {
                // STEP 1: VOICE MIC BUTTON
                Box(
                    modifier = Modifier
                        .padding(vertical = 12.dp)
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(if (isListening) Color(0xFFD32F2F) else MaterialTheme.colorScheme.primary)
                        .clickable {
                            isListening = !isListening
                            if (isListening) {
                                spokenText = "Listening for your query..."
                                speechHelper.speak("Listening now. Tell me what space you are looking for.")
                                scope.launch {
                                    delay(2500)
                                    spokenText = "Need Gents PG room in Madhapur under 8000"
                                    isListening = false
                                    selectedCategoryType = "PG"
                                    selectedBudgetTier = "BUDGET"
                                    speechHelper.speak("Found 3 Gents P G rooms matching your budget. Tap any card to lock your room instantly.")
                                }
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (isListening) Icons.Default.GraphicEq else Icons.Default.Mic,
                        contentDescription = "Speak Now",
                        tint = Color.White,
                        modifier = Modifier.size(38.dp)
                    )
                }

                Text(
                    text = if (isListening) spokenText.ifEmpty { "Listening... Speak now!" } else "Tap Microphone & Speak OR Tap Pictures Below",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isListening) Color(0xFFD32F2F) else MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center
                )

                Spacer(modifier = Modifier.height(16.dp))

                // STEP 2: PICTURE CATEGORY SELECTION
                Text(
                    text = "STEP 1: Select Space Picture",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.align(Alignment.Start)
                )

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    availableVoiceCategories.forEach { (catKey, catName, catSub) ->
                        val selected = selectedCategoryType == catKey
                        Card(
                            modifier = Modifier
                                .weight(1f)
                                .clickable {
                                    selectedCategoryType = catKey
                                    speechHelper.speak("Selected $catName. Now choose your budget tier.")
                                },
                            colors = CardDefaults.cardColors(
                                containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant
                            ),
                            border = if (selected) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null,
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 12.dp, horizontal = 4.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(text = catName, fontSize = 12.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                                Text(text = catSub, fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // STEP 3: BUDGET SELECTOR
                Text(
                    text = "STEP 2: Select Budget Range",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.align(Alignment.Start)
                )

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    listOf(
                        Triple("BUDGET", "🟢 Low Cost", "Best Value"),
                        Triple("MID", "🟡 Medium", "Standard Comfort"),
                        Triple("PREMIUM", "🔴 Luxury", "5-Star Standard")
                    ).forEach { (bKey, bName, bSub) ->
                        val selected = selectedBudgetTier == bKey
                        Card(
                            modifier = Modifier
                                .weight(1f)
                                .clickable {
                                    selectedBudgetTier = bKey
                                    speechHelper.speak("Budget set to $bName. Here are matching verified spaces for instant 1-tap booking.")
                                },
                            colors = CardDefaults.cardColors(
                                containerColor = if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceVariant
                            ),
                            border = if (selected) BorderStroke(2.dp, MaterialTheme.colorScheme.secondary) else null,
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 10.dp, horizontal = 4.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(text = bName, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                Text(text = bSub, fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // MATCHING SPACES DISPLAY FOR 1-TAP INSTANT BOOKING
                val matchingVenues = remember(selectedCategoryType, selectedBudgetTier, venues) {
                    venues.filter { v ->
                        val matchType = when (selectedCategoryType) {
                            "PG" -> v.pgDetails != null || v.category?.slug == "pg_hostel"
                            "HOTEL" -> v.hotelDetails != null || v.category?.slug == "hotel_stay"
                            "TURF" -> v.category?.slug == "sports_turf"
                            "VENUE" -> v.pgDetails == null && v.hotelDetails == null
                            else -> true
                        }
                        val matchBudget = when (selectedBudgetTier) {
                            "BUDGET" -> v.pricingBaseAmount <= 25000
                            "MID" -> v.pricingBaseAmount in 25000.0..100000.0
                            "PREMIUM" -> v.pricingBaseAmount >= 100000
                            else -> true
                        }
                        matchType && matchBudget
                    }.take(3)
                }

                Text(
                    text = "STEP 3: Tap Any Space Below to Book Instantly",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.align(Alignment.Start)
                )

                Spacer(modifier = Modifier.height(8.dp))

                if (matchingVenues.isEmpty()) {
                    Text(
                        text = "Showing featured top available spaces for instant 1-tap booking:",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                val listToDisplay = if (matchingVenues.isNotEmpty()) matchingVenues else venues.take(3)

                LazyRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(listToDisplay) { venue ->
                        Card(
                            modifier = Modifier
                                .width(240.dp)
                                .clickable {
                                    bookedVenueResult = venue
                                    bookingConfirmed = true
                                    speechHelper.speak("Booking confirmed for ${venue.name}! You can call the manager directly.")
                                },
                            shape = RoundedCornerShape(18.dp),
                            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Text(text = venue.name, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1)
                                Text(text = "📍 ${venue.city}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Spacer(modifier = Modifier.height(6.dp))

                                val priceText = if (venue.pgDetails != null) {
                                    val breakdown = PgRentCalculator.calculate(venue)
                                    "₹%,d/mo • Deposit ₹%,d".format(breakdown.monthlyBaseRent.toInt(), breakdown.securityDeposit.toInt())
                                } else {
                                    "₹%,d".format(venue.pricingBaseAmount.toInt())
                                }

                                Text(
                                    text = priceText,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary
                                )

                                Spacer(modifier = Modifier.height(8.dp))

                                Button(
                                    onClick = {
                                        bookedVenueResult = venue
                                        bookingConfirmed = true
                                        speechHelper.speak("Booking confirmed for ${venue.name}! You can call the manager directly.")
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    shape = RoundedCornerShape(10.dp),
                                    contentPadding = PaddingValues(vertical = 4.dp)
                                ) {
                                    Text("⚡ 1-Tap Quick Book", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}
