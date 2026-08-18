package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Chat
import coil.compose.AsyncImage
import androidx.compose.material.icons.filled.Apartment
import com.bookmyspace.bookmyspace.data.model.Course
import com.bookmyspace.bookmyspace.data.model.Event
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.util.PgRentCalculator
import com.bookmyspace.bookmyspace.util.VenueImageResolver
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.EventAvailable
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.Wifi
import com.bookmyspace.bookmyspace.data.model.TimeSlot
import coil.request.ImageRequest
import coil.compose.AsyncImage

import androidx.compose.foundation.Canvas
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import com.bookmyspace.bookmyspace.ui.theme.MidnightNavy
import com.bookmyspace.bookmyspace.ui.theme.RoyalBlue
import com.bookmyspace.bookmyspace.ui.theme.SaffronGold

@Composable
fun BookMySpaceBrandSymbol(
    modifier: Modifier = Modifier,
    isDarkBackground: Boolean = false
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = Color(0xFF4F46E5),
        modifier = modifier
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Canvas(modifier = Modifier.fillMaxSize(0.68f)) {
                val w = size.width
                val h = size.height
                
                // Draw Location pin with inner dot/person
                val pinPath = androidx.compose.ui.graphics.Path().apply {
                    moveTo(w * 0.5f, h * 0.05f)
                    cubicTo(w * 0.85f, h * 0.05f, w * 0.95f, h * 0.35f, w * 0.95f, h * 0.50f)
                    cubicTo(w * 0.95f, h * 0.72f, w * 0.68f, h * 0.88f, w * 0.50f, h * 0.98f)
                    cubicTo(w * 0.32f, h * 0.88f, w * 0.05f, h * 0.72f, w * 0.05f, h * 0.50f)
                    cubicTo(w * 0.05f, h * 0.35f, w * 0.15f, h * 0.05f, w * 0.50f, h * 0.05f)
                    close()
                }
                
                drawPath(
                    path = pinPath,
                    color = Color.White,
                    style = androidx.compose.ui.graphics.drawscope.Stroke(
                        width = w * 0.14f,
                        cap = androidx.compose.ui.graphics.StrokeCap.Round,
                        join = androidx.compose.ui.graphics.StrokeJoin.Round
                    )
                )
                
                // Center inner circle / dot
                drawCircle(
                    color = Color.White,
                    radius = w * 0.16f,
                    center = androidx.compose.ui.geometry.Offset(w * 0.5f, h * 0.44f)
                )
            }
        }
    }
}

@Composable
fun BookMySpaceLogo(
    modifier: Modifier = Modifier,
    showSubtext: Boolean = true,
    isDarkBackground: Boolean = false,
    symbolSize: androidx.compose.ui.unit.Dp = 38.dp
) {
    val primaryTextColor = if (isDarkBackground) Color.White else Color(0xFF0F172A)
    val subtextColor = if (isDarkBackground) Color.White.copy(alpha = 0.85f) else Color(0xFF64748B)

    Row(
        modifier = modifier.testTag("bookmyspace_logo"),
        verticalAlignment = Alignment.CenterVertically
    ) {
        BookMySpaceBrandSymbol(
            modifier = Modifier.size(symbolSize),
            isDarkBackground = isDarkBackground
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column {
            Text(
                text = "BOOKMYSPACE",
                fontSize = 17.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 0.5.sp,
                color = primaryTextColor
            )
            if (showSubtext) {
                Text(
                    text = "India's Venue Booking Platform",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = subtextColor
                )
            }
        }
    }
}

@Composable
fun RatingBadge(rating: Double, count: Int = 0) {
    Surface(
        color = MaterialTheme.colorScheme.primaryContainer,
        shape = RoundedCornerShape(8.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Star,
                contentDescription = null,
                tint = Color(0xFFFFB800),
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(2.dp))
            Text(
                text = "$rating",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
            if (count > 0) {
                Text(
                    text = " ($count)",
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun VenueCard(
    venue: Venue,
    onClick: () -> Unit,
    onFavoriteToggle: () -> Unit,
    modifier: Modifier = Modifier,
    sharedTransitionScope: SharedTransitionScope? = null,
    animatedVisibilityScope: AnimatedVisibilityScope? = null
) {
    var isGalleryExpanded by remember { mutableStateOf(false) }
    var selectedThumbnailIndex by remember { mutableIntStateOf(0) }

    val galleryImages = remember(venue) {
        VenueImageResolver.resolveGalleryImages(venue)
    }

    val animatedImageHeight by animateDpAsState(
        targetValue = if (isGalleryExpanded) 250.dp else 190.dp,
        animationSpec = tween(durationMillis = 300),
        label = "venue_card_image_height"
    )

    val cardModifier = modifier
        .fillMaxWidth()
        .testTag("venue_card_${venue.id}")

    val displayAmenities = remember(venue) {
        getVenueDisplayAmenitiesList(venue)
    }

    val displayTimeSlots = remember(venue) {
        getVenueDisplayTimeSlotsList(venue)
    }

    Card(
        modifier = cardModifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column {
            val imageModifier = if (sharedTransitionScope != null && animatedVisibilityScope != null) {
                with(sharedTransitionScope) {
                    Modifier
                        .fillMaxWidth()
                        .height(animatedImageHeight)
                        .sharedElement(
                            rememberSharedContentState(key = "venue-image-${venue.id}"),
                            animatedVisibilityScope = animatedVisibilityScope
                        )
                }
            } else {
                Modifier
                    .fillMaxWidth()
                    .height(animatedImageHeight)
            }

            Box(
                modifier = imageModifier
            ) {
                // Coil Image Carousel with smooth page swiping & gallery expansion
                VenueImageCarousel(
                    venue = venue,
                    height = animatedImageHeight,
                    showCaptions = true,
                    showFullscreenButton = isGalleryExpanded,
                    showNavButtons = isGalleryExpanded,
                    targetPage = selectedThumbnailIndex,
                    onImageClick = {
                        isGalleryExpanded = !isGalleryExpanded
                    }
                )

                // Category & Verified Badge Overlay (Top Left)
                Row(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val categoryName = venue.category?.name ?: "Venue"
                    Surface(
                        color = MidnightNavy.copy(alpha = 0.82f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = categoryName,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    }

                    if (venue.isVerified) {
                        Surface(
                            color = Color(0xFF2E7D32).copy(alpha = 0.90f),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(2.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Verified,
                                    contentDescription = "Verified Venue",
                                    tint = Color.White,
                                    modifier = Modifier.size(11.dp)
                                )
                                Text(
                                    text = "VERIFIED",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = Color.White
                                )
                            }
                        }
                    }
                }

                // Favorite Icon (Top Right)
                IconButton(
                    onClick = onFavoriteToggle,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .background(Color.Black.copy(alpha = 0.45f), CircleShape)
                ) {
                    Icon(
                        imageVector = if (venue.isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                        contentDescription = "Save Venue",
                        tint = if (venue.isSaved) MaterialTheme.colorScheme.tertiary else Color.White
                    )
                }

                // Rating Badge (Bottom Left)
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(10.dp)
                ) {
                    RatingBadge(rating = venue.avgRating, count = venue.ratingCount)
                }

                // Image Count / Expand Gallery Toggle Badge (Bottom Right)
                Surface(
                    color = if (isGalleryExpanded) MaterialTheme.colorScheme.primary else Color.Black.copy(alpha = 0.65f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(10.dp)
                        .clickable { isGalleryExpanded = !isGalleryExpanded }
                        .testTag("expand_venue_gallery_button_${venue.id}")
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = if (isGalleryExpanded) Icons.Default.ExpandLess else Icons.Default.PhotoCamera,
                            contentDescription = "Expand Photo Gallery",
                            tint = Color.White,
                            modifier = Modifier.size(11.dp)
                        )
                        Text(
                            text = if (isGalleryExpanded) "Collapse Gallery" else "${galleryImages.size.coerceAtLeast(1)} Photos",
                            fontSize = 9.5.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White
                        )
                    }
                }
            }

            // Expanded Photo Gallery Thumbnail Strip
            AnimatedVisibility(
                visible = isGalleryExpanded,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))
                        .padding(vertical = 8.dp, horizontal = 12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "PHOTO GALLERY (${galleryImages.size} PHOTOS)",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = "Tap thumbnail to switch",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        itemsIndexed(galleryImages) { idx, imgUrl ->
                            val isSelected = idx == selectedThumbnailIndex
                            Surface(
                                modifier = Modifier
                                    .size(width = 68.dp, height = 48.dp)
                                    .clickable { selectedThumbnailIndex = idx },
                                shape = RoundedCornerShape(8.dp),
                                border = if (isSelected) androidx.compose.foundation.BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null,
                                shadowElevation = if (isSelected) 3.dp else 0.dp
                            ) {
                                AsyncImage(
                                    model = imgUrl,
                                    contentDescription = "Gallery Thumbnail $idx",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }
                        }
                    }
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onClick() }
                    .padding(14.dp)
            ) {
                val cardContext = LocalContext.current
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val titleModifier = if (sharedTransitionScope != null && animatedVisibilityScope != null) {
                        with(sharedTransitionScope) {
                            Modifier
                                .sharedElement(
                                    rememberSharedContentState(key = "venue-title-${venue.id}"),
                                    animatedVisibilityScope = animatedVisibilityScope
                                )
                                .weight(1f)
                        }
                    } else {
                        Modifier.weight(1f)
                    }

                    Text(
                        text = venue.name,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = titleModifier
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    VoiceReadoutButton(venue = venue)
                }
                Spacer(modifier = Modifier.height(3.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "${venue.fullAddress} • ${venue.distanceKm} km away",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                if (venue.pgDetails != null || venue.category?.slug == "pg_hostel") {
                    Text(
                        text = "${venue.pgDetails?.pgType ?: "Co-living PG"} • ${venue.pgDetails?.mealPlan ?: "Meals Included"} • Gate: ${venue.pgDetails?.gateLockTime ?: "10:30 PM"}",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.tertiary
                    )
                } else {
                    Text(
                        text = "Capacity: ${venue.minGuests}–${venue.maxGuests} guests • ${venue.parkingCapacity}+ parking",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.secondary
                    )
                }

                // -------------------------------------------------------------
                // User Reviews Summary Banner
                // -------------------------------------------------------------
                val latestReview = remember(venue.id) {
                    BookMySpaceRepository.reviews.value.firstOrNull { it.venueId == venue.id }
                }

                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.45f),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("venue_card_review_summary_${venue.id}")
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("⭐", fontSize = 12.sp)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "${venue.avgRating}",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onSecondaryContainer
                            )
                            Text(
                                text = " (${venue.ratingCount} reviews)",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.8f)
                            )
                            if (latestReview != null) {
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "• \"${latestReview.comment}\"",
                                    fontSize = 11.sp,
                                    fontStyle = FontStyle.Italic,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.9f),
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                        Text(
                            text = "Reviews ›",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                // -------------------------------------------------------------
                // 1. Amenities Section
                // -------------------------------------------------------------
                Spacer(modifier = Modifier.height(10.dp))
                Text(
                    text = "AMENITIES & FACILITIES",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    for (amenity in displayAmenities) {
                        AmenityChip(amenity = amenity)
                    }
                }

                // -------------------------------------------------------------
                // 2. Available Time Slots Section
                // -------------------------------------------------------------
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(7.dp)
                                .clip(CircleShape)
                                .background(Color(0xFF2E7D32))
                        )
                        Text(
                            text = "AVAILABLE TIME SLOTS",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 0.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Text(
                        text = "${displayTimeSlots.count { slot -> slot.isAvailable }} Slots Open Today",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF2E7D32)
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    for (slot in displayTimeSlots) {
                        TimeSlotChip(slot = slot, onClick = onClick)
                    }
                }

                // -------------------------------------------------------------
                // 3. Quick Actions Contact Strip
                // -------------------------------------------------------------
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AssistChip(
                        onClick = {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${venue.contactPhone}"))
                            cardContext.startActivity(intent)
                        },
                        label = { Text("Call", fontSize = 11.sp, fontWeight = FontWeight.Bold) },
                        leadingIcon = { Icon(Icons.Default.Call, contentDescription = "Call ${venue.name} manager at ${venue.contactPhone}", modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary) },
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.semantics {
                            contentDescription = "Call venue manager for ${venue.name}"
                        }
                    )

                    AssistChip(
                        onClick = {
                            launchGoogleMapsDirections(cardContext, venue.latitude, venue.longitude, venue.name)
                        },
                        label = { Text("Directions", fontSize = 11.sp, fontWeight = FontWeight.Bold) },
                        leadingIcon = { Icon(Icons.Default.LocationOn, contentDescription = "Get directions to ${venue.name} in Google Maps", modifier = Modifier.size(14.dp), tint = Color(0xFFD84315)) },
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.semantics {
                            contentDescription = "Get directions to ${venue.name}"
                        }
                    )

                    AssistChip(
                        onClick = {
                            val url = "https://api.whatsapp.com/send?phone=91${venue.contactPhone.replace("-", "")}&text=Hi%20Manager%2C%20I%20want%20to%20inquire%20about%20${Uri.encode(venue.name)}"
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            cardContext.startActivity(intent)
                        },
                        label = { Text("WhatsApp", fontSize = 11.sp, fontWeight = FontWeight.Bold) },
                        leadingIcon = { Icon(Icons.Default.Chat, contentDescription = "Chat with ${venue.name} manager on WhatsApp", modifier = Modifier.size(14.dp), tint = Color(0xFF00897B)) },
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.semantics {
                            contentDescription = "Chat with ${venue.name} manager on WhatsApp"
                        }
                    )
                }

                // -------------------------------------------------------------
                // 4. Detailed Pricing & Primary CTA
                // -------------------------------------------------------------
                Spacer(modifier = Modifier.height(10.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(10.dp))

                if (venue.pgDetails != null || venue.category?.slug == "pg_hostel") {
                    val breakdown = PgRentCalculator.calculate(venue)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Monthly Rent from",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Row(verticalAlignment = Alignment.Bottom) {
                                Text(
                                    text = "₹%,d".format(breakdown.monthlyBaseRent.toInt()),
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Text(
                                    text = "/mo",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Text(
                                text = "Move-in: ₹%,d • Deposit ₹%,d".format(breakdown.totalMoveInCost.toInt(), breakdown.securityDeposit.toInt()),
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.tertiary
                            )
                        }
                        Button(
                            onClick = onClick,
                            shape = RoundedCornerShape(12.dp),
                            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)
                        ) {
                            Text(
                                text = "View PG Rooms",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                } else {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Starting Slot Price",
                                fontSize = 10.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Row(verticalAlignment = Alignment.Bottom) {
                                Text(
                                    text = "₹%,d".format(venue.pricingBaseAmount.toInt()),
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Text(
                                    text = " + 18% GST",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            if (venue.packages.isNotEmpty()) {
                                val minPkg = venue.packages.minByOrNull { it.priceAmount }
                                if (minPkg != null && minPkg.vegPlatePrice > 0) {
                                    Text(
                                        text = "Veg Plate: ₹%,d • Non-Veg: ₹%,d".format(minPkg.vegPlatePrice.toInt(), minPkg.nonVegPlatePrice.toInt()),
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = MaterialTheme.colorScheme.secondary
                                    )
                                }
                            }
                        }
                        Button(
                            onClick = onClick,
                            shape = RoundedCornerShape(12.dp),
                            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)
                        ) {
                            Text(
                                text = "Check Availability",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun VenueCarouselCard(
    venue: Venue,
    onClick: () -> Unit,
    onFavoriteToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isSaved by remember { mutableStateOf(false) }
    val imageUrl = remember(venue) {
        venue.images.firstOrNull()?.url ?: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800"
    }

    Card(
        modifier = modifier
            .width(265.dp)
            .clickable { onClick() }
            .testTag("venue_carousel_card_${venue.id}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(130.dp)
            ) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = venue.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                // Top Left '✔ Verified' Badge
                Surface(
                    color = Color(0xFF16A34A),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(8.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Text(
                            text = "✔ Verified",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }

                // Top Right Heart Button
                Surface(
                    onClick = {
                        isSaved = !isSaved
                        onFavoriteToggle()
                    },
                    color = Color.Black.copy(alpha = 0.35f),
                    shape = CircleShape,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .size(28.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = if (isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                            contentDescription = "Save Venue",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            ) {
                Text(
                    text = venue.name,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(3.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = Color(0xFF64748B),
                        modifier = Modifier.size(13.dp)
                    )
                    Spacer(modifier = Modifier.width(3.dp))
                    val locationLabel = venue.addressLine1.ifBlank { venue.city }
                    Text(
                        text = "$locationLabel, ${venue.city}",
                        fontSize = 11.sp,
                        color = Color(0xFF64748B),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Spacer(modifier = Modifier.height(6.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "★",
                            color = Color(0xFFF59E0B),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = "${venue.avgRating}",
                            fontSize = 11.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                        Text(
                            text = " (${venue.ratingCount})",
                            fontSize = 11.sp,
                            color = Color(0xFF64748B)
                        )
                    }

                    Text(
                        text = "₹%,d onwards".format(venue.pricingBaseAmount.toInt()),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF4F46E5)
                    )
                }
            }
        }
    }
}

@Composable
private fun AmenityChip(amenity: String) {
    val icon = when {
        amenity.contains("AC", true) || amenity.contains("Air", true) -> Icons.Default.AcUnit
        amenity.contains("WiFi", true) || amenity.contains("Internet", true) -> Icons.Default.Wifi
        amenity.contains("Parking", true) -> Icons.Default.DirectionsCar
        amenity.contains("Meal", true) || amenity.contains("Catering", true) || amenity.contains("Food", true) -> Icons.Default.Restaurant
        amenity.contains("Power", true) || amenity.contains("Backup", true) -> Icons.Default.FlashOn
        amenity.contains("Sound", true) || amenity.contains("Audio", true) -> Icons.Default.VolumeUp
        else -> Icons.Default.CheckCircle
    }

    Surface(
        color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f),
        shape = RoundedCornerShape(8.dp),
        border = androidx.compose.foundation.BorderStroke(0.5.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(12.dp)
            )
            Text(
                text = amenity,
                fontSize = 10.5.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSecondaryContainer
            )
        }
    }
}

@Composable
private fun TimeSlotChip(slot: TimeSlot, onClick: () -> Unit) {
    val statusBg = if (slot.isAvailable) Color(0xFFE8F5E9) else Color(0xFFFFEBEE)
    val statusBorder = if (slot.isAvailable) Color(0xFF81C784) else Color(0xFFE57373)
    val textPrimary = if (slot.isAvailable) Color(0xFF1B5E20) else Color(0xFFC62828)

    Surface(
        onClick = onClick,
        color = statusBg,
        shape = RoundedCornerShape(10.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, statusBorder)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.AccessTime,
                    contentDescription = null,
                    tint = textPrimary,
                    modifier = Modifier.size(11.dp)
                )
                Text(
                    text = slot.label,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = textPrimary
                )
            }
            Text(
                text = "${slot.startTime} - ${slot.endTime}",
                fontSize = 9.5.sp,
                fontWeight = FontWeight.Medium,
                color = textPrimary.copy(alpha = 0.85f)
            )
            Text(
                text = "₹%,d".format(slot.priceAmount.toInt()),
                fontSize = 11.sp,
                fontWeight = FontWeight.ExtraBold,
                color = textPrimary
            )
        }
    }
}

private fun getVenueDisplayAmenitiesList(venue: Venue): List<String> {
    val existing = venue.facilities.map { it.facility }.filter { it.isNotBlank() }
    if (existing.isNotEmpty()) return existing.take(6)

    val categorySlug = venue.category?.slug ?: ""
    return when {
        categorySlug.contains("pg") || venue.pgDetails != null -> listOf("High-speed WiFi", "3 Meals Daily", "Air Conditioned", "24/7 Security", "Washing Machine", "Power Backup")
        categorySlug.contains("turf") || categorySlug.contains("sports") -> listOf("Floodlights", "Changing Rooms", "Free Parking", "Water Station", "Equipment Rental", "Pro Turf")
        categorySlug.contains("hotel") || venue.hotelDetails != null -> listOf("Luxury Rooms", "Swimming Pool", "Complimentary Breakfast", "24h Room Service", "Valet Parking", "Spa & Gym")
        else -> listOf("Air Conditioned", "${venue.parkingCapacity}+ Parking", "In-house Catering", "Power Backup", "Stage & Lighting", "Sound System")
    }
}

private fun getVenueDisplayTimeSlotsList(venue: Venue): List<TimeSlot> {
    if (venue.timeSlots.isNotEmpty()) return venue.timeSlots
    return listOf(
        TimeSlot(
            id = "slot_morn_${venue.id}",
            venueId = venue.id,
            label = "Morning Slot",
            startTime = "08:00 AM",
            endTime = "12:00 PM",
            priceAmount = (venue.pricingBaseAmount * 0.35).coerceAtLeast(1500.0),
            isAvailable = true
        ),
        TimeSlot(
            id = "slot_aft_${venue.id}",
            venueId = venue.id,
            label = "Afternoon Slot",
            startTime = "12:30 PM",
            endTime = "04:30 PM",
            priceAmount = (venue.pricingBaseAmount * 0.40).coerceAtLeast(2000.0),
            isAvailable = true
        ),
        TimeSlot(
            id = "slot_eve_${venue.id}",
            venueId = venue.id,
            label = "Evening Prime",
            startTime = "05:00 PM",
            endTime = "11:00 PM",
            priceAmount = (venue.pricingBaseAmount * 0.70).coerceAtLeast(3500.0),
            isAvailable = true
        )
    )
}


@Composable
fun EventCard(
    event: Event,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .width(280.dp)
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(110.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Text(event.category, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = event.title,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "📅 ${event.eventDate} • ${event.timeSlot}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(text = "₹${event.ticketPrice.toInt()}", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                Text(
                    text = if (event.isRegistered) "Registered ✓" else "${event.seatsBooked}/${event.totalSeats} seats",
                    fontSize = 11.sp,
                    color = if (event.isRegistered) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
fun CourseCard(
    course: Course,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.secondary.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Text(course.level, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.secondary)
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = course.title, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1)
                Text(text = course.academyName, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(4.dp))
                Text(text = "${course.durationWeeks} Weeks • ${course.schedule}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(6.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "₹${course.price.toInt()}", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    if (course.isEnrolled) {
                        Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(8.dp)) {
                            Text("Enrolled", modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}
