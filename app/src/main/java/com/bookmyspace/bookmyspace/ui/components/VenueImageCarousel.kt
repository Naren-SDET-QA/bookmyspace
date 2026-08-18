package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.util.VenueImageResolver
import kotlinx.coroutines.launch

/**
 * A smooth, swipable page-view carousel component for venue images with indicator dots,
 * amenity captions, left/right navigation arrows, image counter badge, and full-screen lightbox modal.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun VenueImageCarousel(
    venue: Venue,
    modifier: Modifier = Modifier,
    height: androidx.compose.ui.unit.Dp = 240.dp,
    showCaptions: Boolean = true,
    showFullscreenButton: Boolean = true,
    showNavButtons: Boolean = true,
    targetPage: Int = 0,
    onImageClick: ((Int) -> Unit)? = null
) {
    val images = remember(venue) {
        VenueImageResolver.resolveGalleryImages(venue)
    }

    val captions = remember(venue, images) {
        generateAmenityCaptions(venue, images.size)
    }

    val pagerState = rememberPagerState(pageCount = { images.size })
    val coroutineScope = rememberCoroutineScope()
    var showFullscreenDialog by remember { mutableStateOf(false) }
    var initialDialogPage by remember { mutableIntStateOf(0) }

    LaunchedEffect(targetPage) {
        if (targetPage in 0 until images.size && targetPage != pagerState.currentPage) {
            pagerState.animateScrollToPage(targetPage)
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .testTag("venue_image_carousel")
    ) {
        // 1. Swipeable Horizontal Pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            val imageUrl = images.getOrElse(page) { VenueImageResolver.resolveCoverImage(venue) }
            val caption = captions.getOrElse(page) { venue.name }

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clickable {
                        onImageClick?.invoke(page) ?: run {
                            initialDialogPage = page
                            showFullscreenDialog = true
                        }
                    }
                    .testTag("carousel_image_item_$page")
            ) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = "$caption - ${venue.name}",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                // Bottom Gradient Scrim for readable text
                if (showCaptions) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(80.dp)
                            .align(Alignment.BottomCenter)
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        Color.Transparent,
                                        Color.Black.copy(alpha = 0.75f)
                                    )
                                )
                            )
                    )

                    // Amenity / Area Caption Banner
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .align(Alignment.BottomStart)
                            .padding(start = 12.dp, end = 12.dp, bottom = 22.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.PhotoLibrary,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.9f),
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = caption,
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }
        }

        // 2. Top Bar Overlay: Verified Badge & Image Count
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Category / Verified Badge
            if (venue.isVerified) {
                Surface(
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(20.dp),
                    shadowElevation = 2.dp
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Verified,
                            contentDescription = "Verified",
                            tint = Color.White,
                            modifier = Modifier.size(12.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "VERIFIED GALLERY",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            } else {
                Spacer(modifier = Modifier.width(1.dp))
            }

            // Image Counter Badge & Fullscreen Button
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Surface(
                    color = Color.Black.copy(alpha = 0.65f),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                            .testTag("carousel_image_counter"),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Collections,
                            contentDescription = "Photo count",
                            tint = Color.White,
                            modifier = Modifier.size(12.dp)
                        )
                        Text(
                            text = "${pagerState.currentPage + 1} / ${images.size}",
                            color = Color.White,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                if (showFullscreenButton) {
                    Surface(
                        color = Color.Black.copy(alpha = 0.65f),
                        shape = CircleShape,
                        modifier = Modifier
                            .size(28.dp)
                            .clickable {
                                initialDialogPage = pagerState.currentPage
                                showFullscreenDialog = true
                            }
                            .testTag("carousel_fullscreen_button")
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.Fullscreen,
                                contentDescription = "Expand Fullscreen",
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }
        }

        // 3. Navigation Arrow Buttons (Left / Right)
        if (showNavButtons && images.size > 1) {
            // Previous Button
            if (pagerState.currentPage > 0) {
                Surface(
                    color = Color.Black.copy(alpha = 0.5f),
                    shape = CircleShape,
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = 8.dp)
                        .size(32.dp)
                        .clickable {
                            coroutineScope.launch {
                                pagerState.animateScrollToPage(pagerState.currentPage - 1)
                            }
                        }
                        .testTag("carousel_prev_button")
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Default.ChevronLeft,
                            contentDescription = "Previous Photo",
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }

            // Next Button
            if (pagerState.currentPage < images.size - 1) {
                Surface(
                    color = Color.Black.copy(alpha = 0.5f),
                    shape = CircleShape,
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .padding(end = 8.dp)
                        .size(32.dp)
                        .clickable {
                            coroutineScope.launch {
                                pagerState.animateScrollToPage(pagerState.currentPage + 1)
                            }
                        }
                        .testTag("carousel_next_button")
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Default.ChevronRight,
                            contentDescription = "Next Photo",
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }

        // 4. Indicator Dots Bar
        if (images.size > 1) {
            Row(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 8.dp)
                    .testTag("carousel_dots_indicator"),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                images.indices.forEach { index ->
                    val isSelected = index == pagerState.currentPage
                    val width by animateDpAsState(
                        targetValue = if (isSelected) 22.dp else 8.dp,
                        animationSpec = tween(300),
                        label = "dotWidth"
                    )
                    val color by animateColorAsState(
                        targetValue = if (isSelected) MaterialTheme.colorScheme.primary else Color.White.copy(alpha = 0.6f),
                        animationSpec = tween(300),
                        label = "dotColor"
                    )

                    Box(
                        modifier = Modifier
                            .height(8.dp)
                            .width(width)
                            .clip(CircleShape)
                            .background(color)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) {
                                coroutineScope.launch {
                                    pagerState.animateScrollToPage(index)
                                }
                            }
                            .testTag("carousel_dot_$index")
                    )
                }
            }
        }
    }

    // 5. Fullscreen Interactive Lightbox Modal Dialog
    if (showFullscreenDialog) {
        FullscreenImageGalleryModal(
            images = images,
            captions = captions,
            initialPage = initialDialogPage,
            venueName = venue.name,
            onDismiss = { showFullscreenDialog = false }
        )
    }
}

/**
 * Fullscreen Lightbox Modal Dialog for inspecting high-res venue amenity photos.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun FullscreenImageGalleryModal(
    images: List<String>,
    captions: List<String>,
    initialPage: Int,
    venueName: String,
    onDismiss: () -> Unit
) {
    val dialogPagerState = rememberPagerState(
        initialPage = initialPage.coerceIn(0, (images.size - 1).coerceAtLeast(0)),
        pageCount = { images.size }
    )
    val coroutineScope = rememberCoroutineScope()

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            dismissOnBackPress = true,
            dismissOnClickOutside = false
        )
    ) {
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .testTag("fullscreen_gallery_dialog"),
            color = Color.Black
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                // Swipeable High-Res Pager
                HorizontalPager(
                    state = dialogPagerState,
                    modifier = Modifier.fillMaxSize()
                ) { page ->
                    val url = images.getOrElse(page) { "" }
                    val caption = captions.getOrElse(page) { "" }

                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        AsyncImage(
                            model = url,
                            contentDescription = caption,
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }

                // Top Toolbar: Back / Close & Title
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Black.copy(alpha = 0.8f), Color.Transparent)
                            )
                        )
                        .padding(horizontal = 16.dp, vertical = 16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(
                            onClick = onDismiss,
                            modifier = Modifier.testTag("close_fullscreen_gallery")
                        ) {
                            Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = venueName,
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                            Text(
                                text = "High-Res Photo ${dialogPagerState.currentPage + 1} of ${images.size}",
                                color = Color.White.copy(alpha = 0.7f),
                                fontSize = 12.sp
                            )
                        }
                    }
                }

                // Bottom Caption Banner & Dot Indicators
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.9f))
                            )
                        )
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    val currentCaption = captions.getOrElse(dialogPagerState.currentPage) { "" }
                    if (currentCaption.isNotBlank()) {
                        Surface(
                            color = Color.White.copy(alpha = 0.15f),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.padding(bottom = 12.dp)
                        ) {
                            Text(
                                text = "✨ $currentCaption",
                                color = Color.White,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                            )
                        }
                    }

                    // Dot indicators inside dialog
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        images.indices.forEach { index ->
                            val isSelected = index == dialogPagerState.currentPage
                            Box(
                                modifier = Modifier
                                    .height(8.dp)
                                    .width(if (isSelected) 24.dp else 8.dp)
                                    .clip(CircleShape)
                                    .background(if (isSelected) MaterialTheme.colorScheme.primary else Color.White.copy(alpha = 0.4f))
                                    .clickable {
                                        coroutineScope.launch {
                                            dialogPagerState.animateScrollToPage(index)
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

/**
 * Generates descriptive amenity captions based on venue category & facilities.
 */
private fun generateAmenityCaptions(venue: Venue, count: Int): List<String> {
    val categoryName = venue.category?.name?.lowercase() ?: ""
    val availableFacilities = venue.facilities.filter { it.isAvailable }.map { it.facility }

    val baseCaptions = when {
        categoryName.contains("pg") || categoryName.contains("coliving") || categoryName.contains("hostel") -> listOf(
            "Main Bedroom & Air Conditioned Setup",
            "Shared Living Lounge & Study Area",
            "Modern Kitchenette & Dining Zone",
            "Washroom & Housekeeping Facilities"
        )
        categoryName.contains("hotel") || categoryName.contains("stay") || categoryName.contains("resort") -> listOf(
            "Luxury Suite & King Bed Layout",
            "Executive Workstation & Room Amenities",
            "Ensuite Bathroom & Rain Shower",
            "Hotel Lobby & Concierge Entrance"
        )
        categoryName.contains("meeting") || categoryName.contains("office") || categoryName.contains("conference") -> listOf(
            "Boardroom Seating & Projector Setup",
            "High-Speed Wi-Fi & Conference Tech",
            "Executive Lounge & Refreshments Area",
            "Reception & Breakout Zone"
        )
        categoryName.contains("sport") || categoryName.contains("turf") || categoryName.contains("ground") -> listOf(
            "Floodlit Turf & Professional Playing Surface",
            "Dressing Rooms & Equipment Storage",
            "Spectator Gallery & Refreshment Stall",
            "Night Lighting & Parking Facility"
        )
        else -> listOf(
            "Main Grand Hall & Event Stage",
            "Banquet Dining & Catering Setup",
            "VIP Lounge & Green Room",
            "Outdoor Entrance & Valet Parking"
        )
    }

    return List(count) { idx ->
        if (idx == 0) {
            "Main View • ${venue.name}"
        } else if (idx - 1 < availableFacilities.size) {
            "Amenity: ${availableFacilities[idx - 1]}"
        } else {
            baseCaptions.getOrElse(idx % baseCaptions.size) { "Venue Photo ${idx + 1}" }
        }
    }
}
