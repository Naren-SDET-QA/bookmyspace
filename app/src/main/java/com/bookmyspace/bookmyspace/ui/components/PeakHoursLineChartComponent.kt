package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Venue
import kotlin.math.abs

data class HourlyOccupancy(
    val hour24: Int,
    val timeLabel: String,
    val occupancyPercentage: Float
) {
    val crowdStatus: String
        get() = when {
            occupancyPercentage >= 75f -> "Peak Crowd"
            occupancyPercentage >= 45f -> "Moderate"
            else -> "Quiet / Best Time"
        }

    val statusColor: Color
        get() = when {
            occupancyPercentage >= 75f -> Color(0xFFEF4444)
            occupancyPercentage >= 45f -> Color(0xFFF59E0B)
            else -> Color(0xFF10B981)
        }
}

enum class DayFilterType(val label: String) {
    WEEKDAY("Weekdays (Mon-Fri)"),
    WEEKEND("Weekends (Sat-Sun)")
}

@Composable
fun PeakHoursLineChartComponent(
    venue: Venue,
    modifier: Modifier = Modifier
) {
    var selectedDayFilter by remember { mutableStateOf(DayFilterType.WEEKDAY) }
    var selectedPointIndex by remember { mutableStateOf<Int?>(12) } // Default to 6 PM (index 12)

    val hourlyData = remember(venue.id, selectedDayFilter) {
        generateHourlyDataForVenue(venue, selectedDayFilter)
    }

    val peakHour = remember(hourlyData) {
        hourlyData.maxByOrNull { it.occupancyPercentage }
    }

    val quietestHour = remember(hourlyData) {
        // Find minimum during operating hours (e.g. 8 AM to 10 PM)
        hourlyData.filter { it.hour24 in 8..22 }.minByOrNull { it.occupancyPercentage } ?: hourlyData.first()
    }

    Card(
        modifier = modifier
            .fillMaxWidth()
            .testTag("peak_hours_chart_card"),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.ShowChart,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Peak Booking Hours",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Popular times & crowd density tracker",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.5f)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.TrendingUp,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.tertiary,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "Live Analytics",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.tertiary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Day Selector Segmented Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                DayFilterType.entries.forEach { filter ->
                    FilterChip(
                        selected = selectedDayFilter == filter,
                        onClick = { selectedDayFilter = filter },
                        label = { Text(filter.label, fontSize = 11.sp, fontWeight = if (selectedDayFilter == filter) FontWeight.Bold else FontWeight.Normal) },
                        leadingIcon = {
                            Icon(
                                imageVector = if (filter == DayFilterType.WEEKDAY) Icons.Default.WorkOutline else Icons.Default.Weekend,
                                contentDescription = null,
                                modifier = Modifier.size(14.dp)
                            )
                        },
                        modifier = Modifier
                            .weight(1f)
                            .testTag("day_filter_chip_${filter.name.lowercase()}")
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Quick Insight Badges
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Best Time / Quiet
                Surface(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    color = Color(0xFFD1FAE5)
                ) {
                    Column(modifier = Modifier.padding(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = Color(0xFF047857),
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Best Visit Time",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF047857)
                            )
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = quietestHour?.timeLabel ?: "2:00 PM",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color(0xFF065F46)
                        )
                        Text(
                            text = "${quietestHour?.occupancyPercentage?.toInt() ?: 15}% Occupied (Quiet)",
                            fontSize = 10.sp,
                            color = Color(0xFF047857)
                        )
                    }
                }

                // Peak Time
                Surface(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    color = Color(0xFFFEE2E2)
                ) {
                    Column(modifier = Modifier.padding(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.LocalFireDepartment,
                                contentDescription = null,
                                tint = Color(0xFFB91C1C),
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Highest Peak",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFFB91C1C)
                            )
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = peakHour?.timeLabel ?: "7:00 PM",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color(0xFF991B1B)
                        )
                        Text(
                            text = "${peakHour?.occupancyPercentage?.toInt() ?: 90}% Occupied (Busy)",
                            fontSize = 10.sp,
                            color = Color(0xFFB91C1C)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Chart Instructions
            Text(
                text = "Tap on any point along the line to inspect hourly crowd details:",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Canvas Native Compose Line Chart Component
            val primaryColor = MaterialTheme.colorScheme.primary
            val gridColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
            val selectedPointColor = MaterialTheme.colorScheme.tertiary

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(190.dp)
                    .testTag("peak_hours_line_canvas")
            ) {
                Canvas(
                    modifier = Modifier
                        .fillMaxSize()
                        .pointerInput(hourlyData) {
                            detectTapGestures { offset ->
                                val chartPaddingLeft = 32.dp.toPx()
                                val chartPaddingRight = 16.dp.toPx()
                                val availableWidth = size.width - chartPaddingLeft - chartPaddingRight
                                val stepX = availableWidth / (hourlyData.size - 1)

                                val clickedIndex = ((offset.x - chartPaddingLeft + stepX / 2f) / stepX)
                                    .toInt()
                                    .coerceIn(0, hourlyData.size - 1)

                                selectedPointIndex = clickedIndex
                            }
                        }
                ) {
                    val width = size.width
                    val height = size.height

                    val paddingLeft = 36.dp.toPx()
                    val paddingRight = 16.dp.toPx()
                    val paddingTop = 20.dp.toPx()
                    val paddingBottom = 32.dp.toPx()

                    val chartWidth = width - paddingLeft - paddingRight
                    val chartHeight = height - paddingTop - paddingBottom

                    // Draw Horizontal Grid Lines (100%, 75%, 50%, 25%, 0%)
                    val gridSteps = listOf(100f, 75f, 50f, 25f, 0f)
                    gridSteps.forEach { pct ->
                        val y = paddingTop + chartHeight * (1f - (pct / 100f))

                        // Line
                        drawLine(
                            color = if (pct == 75f) Color(0xFFEF4444).copy(alpha = 0.35f) else gridColor,
                            start = Offset(paddingLeft, y),
                            end = Offset(width - paddingRight, y),
                            strokeWidth = if (pct == 75f) 1.5.dp.toPx() else 1.dp.toPx(),
                            pathEffect = if (pct == 75f) PathEffect.dashPathEffect(floatArrayOf(10f, 10f), 0f) else null
                        )
                    }

                    // Calculate X, Y coordinates for each hour data point
                    val stepX = chartWidth / (hourlyData.size - 1)
                    val points = hourlyData.mapIndexed { index, data ->
                        val x = paddingLeft + index * stepX
                        val y = paddingTop + chartHeight * (1f - (data.occupancyPercentage / 100f))
                        Offset(x, y)
                    }

                    // Draw Gradient Area under Line Chart
                    if (points.isNotEmpty()) {
                        val path = Path().apply {
                            moveTo(points.first().x, points.first().y)
                            for (i in 0 until points.size - 1) {
                                val p1 = points[i]
                                val p2 = points[i + 1]
                                val controlPoint1 = Offset(p1.x + (p2.x - p1.x) / 2f, p1.y)
                                val controlPoint2 = Offset(p1.x + (p2.x - p1.x) / 2f, p2.y)
                                cubicTo(controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, p2.x, p2.y)
                            }
                            lineTo(points.last().x, paddingTop + chartHeight)
                            lineTo(points.first().x, paddingTop + chartHeight)
                            close()
                        }

                        drawPath(
                            path = path,
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    primaryColor.copy(alpha = 0.45f),
                                    primaryColor.copy(alpha = 0.05f)
                                ),
                                startY = paddingTop,
                                endY = paddingTop + chartHeight
                            )
                        )

                        // Draw Smooth Main Curved Line
                        val linePath = Path().apply {
                            moveTo(points.first().x, points.first().y)
                            for (i in 0 until points.size - 1) {
                                val p1 = points[i]
                                val p2 = points[i + 1]
                                val controlPoint1 = Offset(p1.x + (p2.x - p1.x) / 2f, p1.y)
                                val controlPoint2 = Offset(p1.x + (p2.x - p1.x) / 2f, p2.y)
                                cubicTo(controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, p2.x, p2.y)
                            }
                        }

                        drawPath(
                            path = linePath,
                            color = primaryColor,
                            style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
                        )

                        // Draw Data Points
                        points.forEachIndexed { index, pt ->
                            val isSelected = index == selectedPointIndex
                            val data = hourlyData[index]

                            if (isSelected) {
                                // Vertical Indicator Guide Line
                                drawLine(
                                    color = selectedPointColor,
                                    start = Offset(pt.x, paddingTop),
                                    end = Offset(pt.x, paddingTop + chartHeight),
                                    strokeWidth = 1.5.dp.toPx(),
                                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f), 0f)
                                )

                                // Selected Point Glow Circle
                                drawCircle(
                                    color = selectedPointColor.copy(alpha = 0.25f),
                                    radius = 12.dp.toPx(),
                                    center = pt
                                )
                                drawCircle(
                                    color = selectedPointColor,
                                    radius = 6.dp.toPx(),
                                    center = pt
                                )
                                drawCircle(
                                    color = Color.White,
                                    radius = 3.dp.toPx(),
                                    center = pt
                                )
                            } else {
                                // Regular point dot
                                drawCircle(
                                    color = data.statusColor,
                                    radius = 3.5.dp.toPx(),
                                    center = pt
                                )
                            }
                        }
                    }
                }
            }

            // X-Axis Hour Labels Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 28.dp, end = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                hourlyData.filterIndexed { idx, _ -> idx % 3 == 0 }.forEach { item ->
                    Text(
                        text = item.timeLabel,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Interactive Tooltip Card for Selected Time Point
            selectedPointIndex?.let { idx ->
                if (idx in hourlyData.indices) {
                    val pointData = hourlyData[idx]
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("selected_point_tooltip"),
                        shape = RoundedCornerShape(14.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                        border = androidx.compose.foundation.BorderStroke(1.dp, pointData.statusColor.copy(alpha = 0.4f))
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = "⏰ ${pointData.timeLabel}",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Surface(
                                        shape = RoundedCornerShape(6.dp),
                                        color = pointData.statusColor.copy(alpha = 0.2f)
                                    ) {
                                        Text(
                                            text = pointData.crowdStatus,
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = pointData.statusColor,
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                        )
                                    }
                                }
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = when {
                                        pointData.occupancyPercentage >= 75f -> "High demand slot. Book in advance to lock entry."
                                        pointData.occupancyPercentage >= 45f -> "Moderate crowd. Usually 15-20 mins waiting."
                                        else -> "Optimal time! Very low crowd and fastest check-in."
                                    },
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }

                            Column(horizontalAlignment = Alignment.End) {
                                Text(
                                    text = "${pointData.occupancyPercentage.toInt()}%",
                                    fontWeight = FontWeight.Black,
                                    fontSize = 18.sp,
                                    color = pointData.statusColor
                                )
                                Text(
                                    text = "Occupancy",
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// Generate realistic hourly occupancy curve based on venue category & day type
private fun generateHourlyDataForVenue(venue: Venue, dayFilter: DayFilterType): List<HourlyOccupancy> {
    val categorySlug = venue.category?.slug?.lowercase() ?: ""
    val isWeekend = dayFilter == DayFilterType.WEEKEND

    // Hours from 6 AM (index 0) to 11 PM (index 17)
    val hours = listOf(
        6 to "6 AM", 7 to "7 AM", 8 to "8 AM", 9 to "9 AM", 10 to "10 AM", 11 to "11 AM",
        12 to "12 PM", 13 to "1 PM", 14 to "2 PM", 15 to "3 PM", 16 to "4 PM", 17 to "5 PM",
        18 to "6 PM", 19 to "7 PM", 20 to "8 PM", 21 to "9 PM", 22 to "10 PM", 23 to "11 PM"
    )

    return hours.map { (h24, label) ->
        val pct = calculateCategoryOccupancy(categorySlug, h24, isWeekend)
        HourlyOccupancy(
            hour24 = h24,
            timeLabel = label,
            occupancyPercentage = pct.coerceIn(10f, 98f)
        )
    }
}

private fun calculateCategoryOccupancy(categorySlug: String, hour24: Int, isWeekend: Boolean): Float {
    val weekendMultiplier = if (isWeekend) 1.25f else 1.0f

    return when {
        categorySlug.contains("sports") || categorySlug.contains("turf") -> {
            // Peak morning 6-9 AM and evening 6-10 PM
            when (hour24) {
                in 6..8 -> (70f + (hour24 - 6) * 5f) * weekendMultiplier
                in 9..16 -> 25f + (hour24 % 3) * 10f
                in 17..21 -> (80f + (hour24 % 2) * 15f) * weekendMultiplier
                else -> 40f
            }
        }
        categorySlug.contains("banquet") || categorySlug.contains("party") || categorySlug.contains("event") -> {
            // Peak afternoon 12-3 PM & night 7-11 PM
            when (hour24) {
                in 12..15 -> (75f + (hour24 % 2) * 12f) * weekendMultiplier
                in 19..22 -> (88f + (hour24 % 2) * 8f) * weekendMultiplier
                in 6..11 -> 15f + (hour24 - 6) * 3f
                else -> 35f
            }
        }
        categorySlug.contains("coworking") || categorySlug.contains("office") -> {
            // Peak 10 AM - 5 PM on weekdays, low on weekends
            if (isWeekend) {
                20f + (hour24 % 4) * 5f
            } else {
                when (hour24) {
                    in 10..17 -> 85f + (hour24 % 3) * 4f
                    in 8..9 -> 50f
                    else -> 15f
                }
            }
        }
        categorySlug.contains("pg") || categorySlug.contains("co-living") -> {
            // Peak early morning 7-9 AM & evening 7-10 PM
            when (hour24) {
                in 7..9 -> 65f
                in 19..22 -> 80f
                else -> 30f
            }
        }
        categorySlug.contains("hotel") || categorySlug.contains("stay") -> {
            // Peak check-in 12 PM - 3 PM & evening lounge
            when (hour24) {
                in 12..15 -> 80f
                in 18..21 -> 75f
                else -> 40f
            }
        }
        else -> {
            // Standard smooth distribution curve
            val peakDiff = abs(hour24 - 18)
            val base = (90f - peakDiff * 7f) * weekendMultiplier
            base.coerceIn(20f, 95f)
        }
    }
}
