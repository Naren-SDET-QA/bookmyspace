package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import com.bookmyspace.bookmyspace.data.model.Venue

/**
 * Data class representing Amenity Filter option with ID, display label, and icon badge
 */
data class AmenityFilterOption(
    val id: String,
    val label: String,
    val iconEmoji: String,
    val keywords: List<String>
)

val defaultAmenityFilterOptions = listOf(
    AmenityFilterOption("parking", "Vehicle Parking & Valet", "🅿️", listOf("parking", "valet", "car")),
    AmenityFilterOption("wifi", "High-speed Wi-Fi", "📶", listOf("wifi", "wi-fi", "internet", "fiber")),
    AmenityFilterOption("changing_rooms", "Changing Rooms & Showers", "🚿", listOf("changing", "shower", "washroom", "restroom", "dressing", "locker", "bath")),
    AmenityFilterOption("ac", "Air Conditioning", "❄️", listOf("ac", "air condition", "centralized ac", "cooling")),
    AmenityFilterOption("power_backup", "Power Backup Generator", "⚡", listOf("power", "backup", "generator", "electricity")),
    AmenityFilterOption("catering", "In-house Catering & Food", "🍽️", listOf("cater", "kitchen", "food", "dining", "meal", "buffet", "cafe")),
    AmenityFilterOption("stage_sound", "Stage & Audio / Mic", "🎤", listOf("stage", "sound", "led", "audio", "mic", "dj")),
    AmenityFilterOption("rooms", "Guest AC Deluxe Rooms", "🛏️", listOf("room", "suite", "bridal", "bedroom", "stay")),
    AmenityFilterOption("pool", "Swimming Pool", "🏊", listOf("pool", "swimming")),
    AmenityFilterOption("lights", "Floodlights / Night Play", "💡", listOf("light", "floodlight")),
    AmenityFilterOption("lockers", "Secure Lockers", "🔒", listOf("locker")),
    AmenityFilterOption("drinking_water", "RO Drinking Water", "💧", listOf("water", "ro", "dispenser"))
)

/**
 * Reusable Bottom Sheet Filter component for venues.
 * Allows filtering by:
 * 1. Price range (₹ Min - ₹ Max) with price presets
 * 2. Minimum Rating Threshold (0.0★ to 4.5★)
 * 3. Amenity Availability (Multi-select)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VenueFilterBottomSheet(
    initialMinPrice: Float = 0f,
    initialMaxPrice: Float = 10000f,
    initialMinRating: Float = 0f,
    initialSelectedAmenities: Set<String> = emptySet(),
    maxPriceLimit: Float = 10000f,
    totalVenuesCount: Int = 0,
    matchingVenuesCount: Int = totalVenuesCount,
    onDismissRequest: () -> Unit,
    onApplyFilters: (minPrice: Float, maxPrice: Float, minRating: Float, selectedAmenities: Set<String>) -> Unit,
    onResetFilters: () -> Unit = {}
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val coroutineScope = rememberCoroutineScope()

    val dismissWithAnimation: () -> Unit = {
        coroutineScope.launch {
            try {
                sheetState.hide()
            } finally {
                onDismissRequest()
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = MaterialTheme.colorScheme.surface,
        dragHandle = {
            BottomSheetDefaults.DragHandle(
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
            )
        },
        modifier = Modifier.testTag("venue_filter_bottom_sheet")
    ) {
        VenueFilterContent(
            initialMinPrice = initialMinPrice,
            initialMaxPrice = initialMaxPrice,
            initialMinRating = initialMinRating,
            initialSelectedAmenities = initialSelectedAmenities,
            maxPriceLimit = maxPriceLimit,
            matchingVenuesCount = matchingVenuesCount,
            onDismissRequest = dismissWithAnimation,
            onApplyFilters = { minPrice, maxPrice, minRating, selectedAmenities ->
                onApplyFilters(minPrice, maxPrice, minRating, selectedAmenities)
                dismissWithAnimation()
            },
            onResetFilters = onResetFilters
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VenueFilterContent(
    initialMinPrice: Float = 0f,
    initialMaxPrice: Float = 10000f,
    initialMinRating: Float = 0f,
    initialSelectedAmenities: Set<String> = emptySet(),
    maxPriceLimit: Float = 10000f,
    matchingVenuesCount: Int = 0,
    onDismissRequest: () -> Unit,
    onApplyFilters: (minPrice: Float, maxPrice: Float, minRating: Float, selectedAmenities: Set<String>) -> Unit,
    onResetFilters: () -> Unit = {}
) {
    var tempMinPrice by remember(initialMinPrice) { mutableFloatStateOf(initialMinPrice) }
    var tempMaxPrice by remember(initialMaxPrice) { mutableFloatStateOf(initialMaxPrice.coerceAtMost(maxPriceLimit)) }
    var tempMinRating by remember(initialMinRating) { mutableFloatStateOf(initialMinRating) }
    var tempSelectedAmenities by remember(initialSelectedAmenities) { mutableStateOf(initialSelectedAmenities) }

    val activeCount = remember(tempMinPrice, tempMaxPrice, tempMinRating, tempSelectedAmenities, maxPriceLimit) {
        var count = 0
        if (tempMinPrice > 0f || tempMaxPrice < maxPriceLimit) count++
        if (tempMinRating > 0f) count++
        count += tempSelectedAmenities.size
        count
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("venue_filter_content_container")
    ) {
        // --- Header ---
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier.size(38.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.FilterList,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "Filter Venues",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        AnimatedContent(
                            targetState = activeCount,
                            transitionSpec = {
                                (slideInVertically { height -> height / 2 } + fadeIn()) togetherWith
                                    (slideOutVertically { height -> -height / 2 } + fadeOut())
                            },
                            label = "active_filter_count_anim"
                        ) { count ->
                            if (count > 0) {
                                Text(
                                    text = "$count active filter${if (count > 1) "s" else ""} applied",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            } else {
                                Text(
                                    text = "Customize price, ratings & amenities",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    AnimatedVisibility(
                        visible = activeCount > 0,
                        enter = fadeIn(tween(180)) + scaleIn(tween(180)),
                        exit = fadeOut(tween(150)) + scaleOut(tween(150))
                    ) {
                        TextButton(
                            onClick = {
                                tempMinPrice = 0f
                                tempMaxPrice = maxPriceLimit
                                tempMinRating = 0f
                                tempSelectedAmenities = emptySet()
                                onResetFilters()
                            },
                            modifier = Modifier.testTag("reset_venue_filters_btn")
                        ) {
                            Text(
                                text = "Reset",
                                color = MaterialTheme.colorScheme.error,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp
                            )
                        }
                    }
                    IconButton(
                        onClick = onDismissRequest,
                        modifier = Modifier.testTag("close_venue_filters_btn")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        HorizontalDivider(
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
            modifier = Modifier.padding(top = 4.dp)
        )

        // --- Body Content (Scrollable) ---
        Column(
            modifier = Modifier
                .weight(1f, fill = false)
                .heightIn(max = 500.dp)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp)
        ) {
            // -----------------------------------------------------------------
            // 1. PRICE RANGE FILTER (₹)
            // -----------------------------------------------------------------
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("💰", fontSize = 16.sp)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Price Range per Hour",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }

                Surface(
                    color = MaterialTheme.colorScheme.secondaryContainer,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = "₹${tempMinPrice.toInt()} - ${if (tempMaxPrice >= maxPriceLimit) "₹${maxPriceLimit.toInt()}+" else "₹${tempMaxPrice.toInt()}"}",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Price Range Slider
            RangeSlider(
                value = tempMinPrice..tempMaxPrice,
                onValueChange = { range ->
                    tempMinPrice = range.start
                    tempMaxPrice = range.endInclusive
                },
                valueRange = 0f..maxPriceLimit,
                steps = 19, // steps of ~500
                colors = SliderDefaults.colors(
                    thumbColor = MaterialTheme.colorScheme.primary,
                    activeTrackColor = MaterialTheme.colorScheme.primary,
                    inactiveTrackColor = MaterialTheme.colorScheme.surfaceVariant
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("price_range_slider")
            )

            // Price Presets Quick Chips
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                listOf(
                    "Under ₹1,000" to (0f to 1000f),
                    "₹1,000 - ₹2,500" to (1000f to 2500f),
                    "₹2,500 - ₹5,000" to (2500f to 5000f),
                    "₹5,000+" to (5000f to maxPriceLimit)
                ).forEach { (label, range) ->
                    val isSelected = tempMinPrice == range.first && tempMaxPrice == range.second
                    FilterChip(
                        selected = isSelected,
                        onClick = {
                            tempMinPrice = range.first
                            tempMaxPrice = range.second
                        },
                        label = { Text(label, fontSize = 10.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                        ),
                        modifier = Modifier
                            .weight(1f)
                            .testTag("price_preset_${label.replace(" ", "_").lowercase()}")
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
            Spacer(modifier = Modifier.height(16.dp))

            // -----------------------------------------------------------------
            // 2. RATING FILTER (★)
            // -----------------------------------------------------------------
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("⭐", fontSize = 16.sp)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Minimum Venue Rating",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf(
                    0.0f to "All Ratings",
                    3.0f to "3.0★+",
                    4.0f to "4.0★+",
                    4.5f to "4.5★+"
                ).forEach { (ratingValue, label) ->
                    val isSelected = tempMinRating == ratingValue
                    Surface(
                        onClick = { tempMinRating = ratingValue },
                        shape = RoundedCornerShape(12.dp),
                        color = if (isSelected) Color(0xFFFFB800) else MaterialTheme.colorScheme.surfaceVariant,
                        border = if (isSelected) BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary) else null,
                        modifier = Modifier
                            .weight(1f)
                            .testTag("rating_filter_chip_${ratingValue.toInt()}")
                    ) {
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier.padding(vertical = 10.dp, horizontal = 4.dp)
                        ) {
                            Text(
                                text = label,
                                fontSize = 11.sp,
                                fontWeight = if (isSelected) FontWeight.ExtraBold else FontWeight.Medium,
                                color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
            Spacer(modifier = Modifier.height(16.dp))

            // -----------------------------------------------------------------
            // 3. AMENITIES AVAILABILITY FILTER (With Smooth Toggling Animations)
            // -----------------------------------------------------------------
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("✨", fontSize = 16.sp)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Amenity Availability",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
                AnimatedVisibility(
                    visible = tempSelectedAmenities.isNotEmpty(),
                    enter = slideInVertically { it / 2 } + fadeIn(tween(200)) + scaleIn(tween(200)),
                    exit = slideOutVertically { -it / 2 } + fadeOut(tween(150)) + scaleOut(tween(150))
                ) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary
                    ) {
                        Text(
                            text = "${tempSelectedAmenities.size} selected",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Amenity Multi-select Chips Grid
            val chunkedAmenities = defaultAmenityFilterOptions.chunked(2)
            chunkedAmenities.forEach { rowOptions ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 3.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    rowOptions.forEach { option ->
                        val isChecked = tempSelectedAmenities.contains(option.id)
                        val containerColor by animateColorAsState(
                            targetValue = if (isChecked) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            animationSpec = tween(durationMillis = 200),
                            label = "amenity_bg_color"
                        )
                        val borderColor by animateColorAsState(
                            targetValue = if (isChecked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                            animationSpec = tween(durationMillis = 200),
                            label = "amenity_border_color"
                        )

                        Surface(
                            onClick = {
                                tempSelectedAmenities = if (isChecked) {
                                    tempSelectedAmenities - option.id
                                } else {
                                    tempSelectedAmenities + option.id
                                }
                            },
                            shape = RoundedCornerShape(12.dp),
                            color = containerColor,
                            border = BorderStroke(
                                width = if (isChecked) 1.5.dp else 1.dp,
                                color = borderColor
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .testTag("amenity_chip_${option.id}")
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(text = option.iconEmoji, fontSize = 14.sp)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = option.label,
                                    fontSize = 11.sp,
                                    fontWeight = if (isChecked) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isChecked) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.weight(1f)
                                )
                                AnimatedVisibility(
                                    visible = isChecked,
                                    enter = scaleIn(spring(dampingRatio = Spring.DampingRatioMediumBouncy)) + fadeIn(tween(150)),
                                    exit = scaleOut(tween(100)) + fadeOut(tween(100))
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.CheckCircle,
                                        contentDescription = "Selected",
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                        }
                    }
                    if (rowOptions.size == 1) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }

        // --- Sticky Footer Action Bar ---
        Surface(
            tonalElevation = 6.dp,
            shadowElevation = 8.dp,
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedButton(
                    onClick = {
                        tempMinPrice = 0f
                        tempMaxPrice = maxPriceLimit
                        tempMinRating = 0f
                        tempSelectedAmenities = emptySet()
                        onResetFilters()
                    },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .weight(1f)
                        .testTag("clear_all_filters_button")
                ) {
                    Text(
                        text = "Clear All",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Button(
                    onClick = {
                        onApplyFilters(tempMinPrice, tempMaxPrice, tempMinRating, tempSelectedAmenities)
                    },
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = Color.White
                    ),
                    modifier = Modifier
                        .weight(1.8f)
                        .testTag("apply_venue_filters_button")
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        AnimatedContent(
                            targetState = matchingVenuesCount,
                            transitionSpec = {
                                (slideInVertically { height -> height / 2 } + fadeIn()) togetherWith
                                    (slideOutVertically { height -> -height / 2 } + fadeOut())
                            },
                            label = "matching_venues_btn_text_anim"
                        ) { count ->
                            Text(
                                text = if (count > 0) "Apply ($count Spaces)" else "Apply Filters",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}
