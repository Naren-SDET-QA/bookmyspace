package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/**
 * Creates an animated linear shimmer brush for skeleton loading effects.
 */
@Composable
fun shimmerBrush(
    targetValue: Float = 1200f,
    showShimmer: Boolean = true
): Brush {
    if (!showShimmer) return Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))

    val baseColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
    val highlightColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.25f)

    val shimmerColors = listOf(
        baseColor,
        highlightColor,
        baseColor
    )

    val transition = rememberInfiniteTransition(label = "shimmerTransition")
    val translateAnimation by transition.animateFloat(
        initialValue = 0f,
        targetValue = targetValue,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmerTranslation"
    )

    return Brush.linearGradient(
        colors = shimmerColors,
        start = Offset(translateAnimation - 300f, translateAnimation - 300f),
        end = Offset(translateAnimation, translateAnimation)
    )
}

/**
 * Extension modifier to apply animated shimmer loading effect with a given shape.
 */
@Composable
fun Modifier.shimmerLoading(
    shape: Shape = RoundedCornerShape(8.dp)
): Modifier {
    return this
        .clip(shape)
        .background(shimmerBrush())
}

/**
 * Skeleton placeholder card mirroring the layout of [VenueCard].
 */
@Composable
fun VenueCardSkeleton(
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .testTag("venue_card_skeleton"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column {
            // Image Box Skeleton (190.dp height)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(190.dp)
                    .shimmerLoading(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            ) {
                // Top Left: Category & Verified Pill Skeletons
                Row(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .width(65.dp)
                            .height(20.dp)
                            .shimmerLoading(RoundedCornerShape(8.dp))
                    )
                    Box(
                        modifier = Modifier
                            .width(55.dp)
                            .height(20.dp)
                            .shimmerLoading(RoundedCornerShape(8.dp))
                    )
                }

                // Top Right: Favorite Circle Skeleton
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(10.dp)
                        .size(36.dp)
                        .clip(CircleShape)
                        .shimmerLoading(CircleShape)
                )

                // Bottom Left: Rating Badge Skeleton
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(10.dp)
                        .width(65.dp)
                        .height(22.dp)
                        .shimmerLoading(RoundedCornerShape(8.dp))
                )

                // Bottom Right: Photo Count Pill Skeleton
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(10.dp)
                        .width(60.dp)
                        .height(20.dp)
                        .shimmerLoading(RoundedCornerShape(8.dp))
                )
            }

            // Body Skeleton
            Column(modifier = Modifier.padding(14.dp)) {
                // Title and Voice Button Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.7f)
                            .height(20.dp)
                            .shimmerLoading(RoundedCornerShape(6.dp))
                    )
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .shimmerLoading(CircleShape)
                    )
                }

                Spacer(modifier = Modifier.height(6.dp))

                // Location / Address Line
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(14.dp)
                            .shimmerLoading(CircleShape)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.80f)
                            .height(13.dp)
                            .shimmerLoading(RoundedCornerShape(4.dp))
                    )
                }

                // 1. Amenities Section Skeleton
                Spacer(modifier = Modifier.height(10.dp))
                Box(
                    modifier = Modifier
                        .width(130.dp)
                        .height(12.dp)
                        .shimmerLoading(RoundedCornerShape(4.dp))
                )
                Spacer(modifier = Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    repeat(4) {
                        Box(
                            modifier = Modifier
                                .width(76.dp)
                                .height(22.dp)
                                .shimmerLoading(RoundedCornerShape(8.dp))
                        )
                    }
                }

                // 2. Available Time Slots Section Skeleton
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .width(140.dp)
                            .height(12.dp)
                            .shimmerLoading(RoundedCornerShape(4.dp))
                    )
                    Box(
                        modifier = Modifier
                            .width(80.dp)
                            .height(12.dp)
                            .shimmerLoading(RoundedCornerShape(4.dp))
                    )
                }
                Spacer(modifier = Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    repeat(3) {
                        Box(
                            modifier = Modifier
                                .width(105.dp)
                                .height(50.dp)
                                .shimmerLoading(RoundedCornerShape(10.dp))
                        )
                    }
                }

                // 3. Quick Contact Strip Skeleton
                Spacer(modifier = Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    repeat(3) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(32.dp)
                                .shimmerLoading(RoundedCornerShape(10.dp))
                        )
                    }
                }

                // 4. Divider & Price/CTA Row Skeleton
                Spacer(modifier = Modifier.height(10.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f))
                )
                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Box(
                            modifier = Modifier
                                .width(90.dp)
                                .height(11.dp)
                                .shimmerLoading(RoundedCornerShape(4.dp))
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Box(
                            modifier = Modifier
                                .width(110.dp)
                                .height(20.dp)
                                .shimmerLoading(RoundedCornerShape(6.dp))
                        )
                    }

                    Box(
                        modifier = Modifier
                            .width(135.dp)
                            .height(38.dp)
                            .shimmerLoading(RoundedCornerShape(12.dp))
                    )
                }
            }
        }
    }
}

/**
 * Skeleton loader list showing multiple [VenueCardSkeleton] items.
 */
@Composable
fun VenueListSkeleton(
    modifier: Modifier = Modifier,
    count: Int = 3
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        repeat(count) {
            VenueCardSkeleton()
        }
    }
}

/**
 * Skeleton for Map view showing shimmering tile grid, search bar, pins, and venue card preview skeleton.
 */
@Composable
fun VenueMapSkeleton(
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .testTag("venue_map_skeleton")
    ) {
        // Map Grid Shimmer Background
        Box(
            modifier = Modifier
                .fillMaxSize()
                .shimmerLoading(RoundedCornerShape(0.dp))
        ) {
            // Simulated Map Grid Lines
            val gridColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
            Canvas(modifier = Modifier.fillMaxSize()) {
                val step = 80.dp.toPx()
                var x = 0f
                while (x < size.width) {
                    drawLine(gridColor, start = Offset(x, 0f), end = Offset(x, size.height), strokeWidth = 1.5f)
                    x += step
                }
                var y = 0f
                while (y < size.height) {
                    drawLine(gridColor, start = Offset(0f, y), end = Offset(size.width, y), strokeWidth = 1.5f)
                    y += step
                }
            }
        }

        // Shimmer Map Pin Placeholders
        Box(modifier = Modifier.fillMaxSize()) {
            val pinOffsets = listOf(
                Offset(0.25f, 0.35f),
                Offset(0.60f, 0.28f),
                Offset(0.40f, 0.52f),
                Offset(0.75f, 0.65f),
                Offset(0.20f, 0.72f)
            )

            pinOffsets.forEach { relOffset ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(bottom = 80.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .align(
                                Alignment.TopStart
                            )
                            .padding(
                                start = (relOffset.x * 320).dp,
                                top = (relOffset.y * 500).dp
                            )
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.8f))
                    )
                }
            }
        }

        // Search Bar Skeleton Overlay
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.TopCenter)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .shimmerLoading(RoundedCornerShape(26.dp))
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Filter Chips Skeleton Row
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(horizontal = 4.dp)
            ) {
                items(5) {
                    Box(
                        modifier = Modifier
                            .width(85.dp)
                            .height(32.dp)
                            .shimmerLoading(RoundedCornerShape(16.dp))
                    )
                }
            }
        }

        // Floating Bottom Venue Card Preview Skeleton
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.BottomCenter)
        ) {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 6.dp
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(90.dp)
                            .shimmerLoading(RoundedCornerShape(14.dp))
                    )

                    Spacer(modifier = Modifier.width(12.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(0.8f)
                                .height(16.dp)
                                .shimmerLoading(RoundedCornerShape(4.dp))
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(0.6f)
                                .height(12.dp)
                                .shimmerLoading(RoundedCornerShape(4.dp))
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Box(
                            modifier = Modifier
                                .width(90.dp)
                                .height(20.dp)
                                .shimmerLoading(RoundedCornerShape(6.dp))
                        )
                    }
                }
            }
        }
    }
}

/**
 * Skeleton card for Quick Filter chips or categories.
 */
@Composable
fun CategoryChipSkeleton(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .width(100.dp)
            .height(38.dp)
            .shimmerLoading(RoundedCornerShape(19.dp))
    )
}
