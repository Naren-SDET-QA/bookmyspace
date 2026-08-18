package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

enum class CountdownState {
    UPCOMING_DAYS,      // More than 24 hours away
    UPCOMING_IMMINENT,  // Less than 24 hours away
    UPCOMING_URGENT,    // Less than 1 hour away
    IN_PROGRESS,        // Currently underway
    COMPLETED           // Past start and end time
}

data class BookingCountdownInfo(
    val state: CountdownState,
    val days: Long,
    val hours: Long,
    val minutes: Long,
    val seconds: Long,
    val formattedDisplay: String,
    val isImminent: Boolean,
    val targetStartMillis: Long
)

object BookingTimeParser {
    /**
     * Parses the start epoch millis of a booking based on bookingDate and startTime / slotLabel.
     */
    fun parseBookingStartMillis(booking: Booking): Long {
        return try {
            val dateStr = booking.bookingDate.trim()
            val timeStr = if (booking.startTime.isNotBlank()) {
                booking.startTime.trim()
            } else {
                booking.slotLabel.split("-").firstOrNull()?.trim() ?: "09:00 AM"
            }

            val calendar = Calendar.getInstance()

            // Parse Date Component
            when {
                dateStr.equals("Today", ignoreCase = true) || dateStr.startsWith("Today", ignoreCase = true) -> {
                    // today's calendar date
                }
                dateStr.equals("Tomorrow", ignoreCase = true) || dateStr.startsWith("Tomorrow", ignoreCase = true) -> {
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                }
                dateStr.contains("-") -> {
                    val parts = dateStr.split("-")
                    if (parts.size == 3) {
                        calendar.set(Calendar.YEAR, parts[0].toInt())
                        calendar.set(Calendar.MONTH, parts[1].toInt() - 1)
                        calendar.set(Calendar.DAY_OF_MONTH, parts[2].toInt())
                    }
                }
                else -> {
                    // Try parsing format like "Aug 20, 2026" or "Sat, Aug 08"
                    val patterns = listOf("MMM dd, yyyy", "yyyy-MM-dd", "EEE, MMM dd", "MMM dd")
                    var parsed = false
                    for (pattern in patterns) {
                        try {
                            val sdf = SimpleDateFormat(pattern, Locale.US)
                            val parsedDate = sdf.parse(dateStr)
                            if (parsedDate != null) {
                                val tempCal = Calendar.getInstance().apply { time = parsedDate }
                                if (tempCal.get(Calendar.YEAR) <= 1970) {
                                    tempCal.set(Calendar.YEAR, calendar.get(Calendar.YEAR))
                                }
                                calendar.set(Calendar.YEAR, tempCal.get(Calendar.YEAR))
                                calendar.set(Calendar.MONTH, tempCal.get(Calendar.MONTH))
                                calendar.set(Calendar.DAY_OF_MONTH, tempCal.get(Calendar.DAY_OF_MONTH))
                                parsed = true
                                break
                            }
                        } catch (_: Exception) {}
                    }
                }
            }

            // Parse Time Component
            var hour = 9
            var min = 0
            val normalizedTime = timeStr.uppercase().replace(" ", "")

            if (normalizedTime.contains("AM") || normalizedTime.contains("PM")) {
                val isPm = normalizedTime.contains("PM")
                val clean = normalizedTime.replace("AM", "").replace("PM", "").trim()
                val parts = clean.split(":")
                if (parts.isNotEmpty()) {
                    hour = parts[0].toIntOrNull() ?: 9
                    if (parts.size > 1) min = parts[1].toIntOrNull() ?: 0
                    if (isPm && hour < 12) hour += 12
                    if (!isPm && hour == 12) hour = 0
                }
            } else if (timeStr.contains(":")) {
                val parts = timeStr.split(":")
                hour = parts[0].trim().toIntOrNull() ?: 9
                if (parts.size > 1) min = parts[1].trim().toIntOrNull() ?: 0
            }

            calendar.set(Calendar.HOUR_OF_DAY, hour)
            calendar.set(Calendar.MINUTE, min)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)

            calendar.timeInMillis
        } catch (e: Exception) {
            // Fallback: 2 hours in the future
            System.currentTimeMillis() + (2 * 3600 * 1000L)
        }
    }

    /**
     * Computes the live countdown info from the current system time to the booking start time.
     */
    fun computeCountdown(booking: Booking, nowMillis: Long = System.currentTimeMillis()): BookingCountdownInfo {
        val startMillis = parseBookingStartMillis(booking)
        val durationMillis = 60 * 60 * 1000L // default 1 hour duration
        val endMillis = startMillis + durationMillis

        return when {
            nowMillis < startMillis -> {
                val diff = startMillis - nowMillis
                val days = TimeUnit.MILLISECONDS.toDays(diff)
                val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
                val minutes = TimeUnit.MILLISECONDS.toMinutes(diff) % 60
                val seconds = TimeUnit.MILLISECONDS.toSeconds(diff) % 60

                val state = when {
                    diff <= 60 * 60 * 1000L -> CountdownState.UPCOMING_URGENT
                    diff <= 24 * 60 * 60 * 1000L -> CountdownState.UPCOMING_IMMINENT
                    else -> CountdownState.UPCOMING_DAYS
                }

                val formatted = buildString {
                    if (days > 0) append("${days}d ")
                    append(String.format(Locale.US, "%02dh %02dm %02ds", hours, minutes, seconds))
                }

                BookingCountdownInfo(
                    state = state,
                    days = days,
                    hours = hours,
                    minutes = minutes,
                    seconds = seconds,
                    formattedDisplay = formatted,
                    isImminent = diff <= 24 * 60 * 60 * 1000L,
                    targetStartMillis = startMillis
                )
            }
            nowMillis in startMillis..endMillis -> {
                val remaining = endMillis - nowMillis
                val remMinutes = TimeUnit.MILLISECONDS.toMinutes(remaining)
                val remSeconds = TimeUnit.MILLISECONDS.toSeconds(remaining) % 60
                BookingCountdownInfo(
                    state = CountdownState.IN_PROGRESS,
                    days = 0,
                    hours = 0,
                    minutes = remMinutes,
                    seconds = remSeconds,
                    formattedDisplay = String.format(Locale.US, "Active • %02dm %02ds left", remMinutes, remSeconds),
                    isImminent = true,
                    targetStartMillis = startMillis
                )
            }
            else -> {
                BookingCountdownInfo(
                    state = CountdownState.COMPLETED,
                    days = 0,
                    hours = 0,
                    minutes = 0,
                    seconds = 0,
                    formattedDisplay = "Session Completed",
                    isImminent = false,
                    targetStartMillis = startMillis
                )
            }
        }
    }
}

/**
 * Compact, modern Material 3 Countdown Badge for Booking Cards.
 */
@Composable
fun BookingCountdownTimerBadge(
    booking: Booking,
    modifier: Modifier = Modifier
) {
    var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }

    // Live 1-second ticker effect
    LaunchedEffect(booking.id) {
        while (true) {
            delay(1000L)
            nowMillis = System.currentTimeMillis()
        }
    }

    val countdown = remember(booking, nowMillis) {
        BookingTimeParser.computeCountdown(booking, nowMillis)
    }

    if (countdown.state == CountdownState.COMPLETED) {
        return
    }

    val (containerColor, contentColor, borderColor, icon) = when (countdown.state) {
        CountdownState.UPCOMING_URGENT -> Quadruple(
            Color(0xFFFFF3E0),
            Color(0xFFE65100),
            Color(0xFFFFB74D),
            Icons.Default.HourglassTop
        )
        CountdownState.UPCOMING_IMMINENT -> Quadruple(
            Color(0xFFEDE7F6),
            Color(0xFF4A148C),
            Color(0xFFB39DDB),
            Icons.Default.Timer
        )
        CountdownState.IN_PROGRESS -> Quadruple(
            Color(0xFFE8F5E9),
            Color(0xFF1B5E20),
            Color(0xFF81C784),
            Icons.Default.PlayCircle
        )
        CountdownState.UPCOMING_DAYS -> Quadruple(
            MaterialTheme.colorScheme.surfaceVariant,
            MaterialTheme.colorScheme.onSurfaceVariant,
            MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
            Icons.Default.Schedule
        )
        CountdownState.COMPLETED -> Quadruple(
            MaterialTheme.colorScheme.surfaceVariant,
            MaterialTheme.colorScheme.onSurfaceVariant,
            Color.Transparent,
            Icons.Default.Schedule
        )
    }

    Surface(
        color = containerColor,
        contentColor = contentColor,
        shape = RoundedCornerShape(10.dp),
        modifier = modifier
            .border(1.dp, borderColor, RoundedCornerShape(10.dp))
            .testTag("booking_countdown_${booking.id}")
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = "Countdown Timer",
                tint = contentColor,
                modifier = Modifier.size(15.dp)
            )

            Text(
                text = if (countdown.state == CountdownState.IN_PROGRESS) "IN PROGRESS" else "STARTS IN",
                fontSize = 10.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.5.sp,
                color = contentColor.copy(alpha = 0.8f)
            )

            // Digit pills
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                if (countdown.days > 0) {
                    TimeUnitBox(value = countdown.days.toString(), label = "d", contentColor = contentColor)
                    Text(":", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = contentColor)
                }
                TimeUnitBox(value = String.format(Locale.US, "%02d", countdown.hours), label = "h", contentColor = contentColor)
                Text(":", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = contentColor)
                TimeUnitBox(value = String.format(Locale.US, "%02d", countdown.minutes), label = "m", contentColor = contentColor)
                Text(":", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = contentColor)
                TimeUnitBox(value = String.format(Locale.US, "%02d", countdown.seconds), label = "s", contentColor = contentColor)
            }
        }
    }
}

@Composable
private fun TimeUnitBox(
    value: String,
    label: String,
    contentColor: Color
) {
    Row(
        verticalAlignment = Alignment.Bottom,
        modifier = Modifier
            .background(contentColor.copy(alpha = 0.1f), RoundedCornerShape(4.dp))
            .padding(horizontal = 4.dp, vertical = 1.dp)
    ) {
        Text(
            text = value,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = contentColor
        )
        Text(
            text = label,
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold,
            color = contentColor.copy(alpha = 0.7f),
            modifier = Modifier.padding(start = 1.dp)
        )
    }
}

/**
 * Prominent Live Hero Countdown Banner for the Upcoming Sessions Section.
 */
@Composable
fun ImminentBookingCountdownHero(
    booking: Booking,
    onViewPass: () -> Unit,
    modifier: Modifier = Modifier
) {
    var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }

    LaunchedEffect(booking.id) {
        while (true) {
            delay(1000L)
            nowMillis = System.currentTimeMillis()
        }
    }

    val countdown = remember(booking, nowMillis) {
        BookingTimeParser.computeCountdown(booking, nowMillis)
    }

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.85f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
        elevation = CardDefaults.cardElevation(defaultElevation = 3.dp),
        modifier = modifier
            .fillMaxWidth()
            .testTag("upcoming_booking_countdown_hero")
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.95f),
                            MaterialTheme.colorScheme.tertiary.copy(alpha = 0.90f)
                        )
                    )
                )
                .padding(18.dp)
        ) {
            Column {
                // Header badge
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        color = Color.White.copy(alpha = 0.2f),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(if (countdown.state == CountdownState.IN_PROGRESS) Color(0xFF00E676) else Color(0xFFFFD54F))
                            )
                            Text(
                                text = if (countdown.state == CountdownState.IN_PROGRESS) "SESSION LIVE NOW" else "NEXT UPCOMING SESSION",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = Color.White,
                                letterSpacing = 0.8.sp
                            )
                        }
                    }

                    Text(
                        text = "Ref: ${booking.bookingRef}",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White.copy(alpha = 0.85f)
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Venue Name
                Text(
                    text = booking.venueName,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White
                )

                Text(
                    text = "📅 ${booking.bookingDate}  •  ⏰ ${booking.slotLabel}",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.9f),
                    modifier = Modifier.padding(top = 2.dp)
                )

                Spacer(modifier = Modifier.height(14.dp))

                // Big Digital Countdown Display
                Surface(
                    color = Color.Black.copy(alpha = 0.25f),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = if (countdown.state == CountdownState.IN_PROGRESS) "Time Remaining" else "Time Before Start",
                                fontSize = 10.sp,
                                color = Color.White.copy(alpha = 0.75f),
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.testTag("hero_countdown_digits")
                            ) {
                                if (countdown.days > 0) {
                                    HeroDigit(value = countdown.days.toString(), label = "DAYS")
                                    HeroColon()
                                }
                                HeroDigit(value = String.format(Locale.US, "%02d", countdown.hours), label = "HRS")
                                HeroColon()
                                HeroDigit(value = String.format(Locale.US, "%02d", countdown.minutes), label = "MINS")
                                HeroColon()
                                HeroDigit(value = String.format(Locale.US, "%02d", countdown.seconds), label = "SECS")
                            }
                        }

                        Button(
                            onClick = onViewPass,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color.White,
                                contentColor = MaterialTheme.colorScheme.primary
                            ),
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                            modifier = Modifier.testTag("hero_view_pass_btn")
                        ) {
                            Text("Entry Pass", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeroDigit(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Surface(
            color = Color.White.copy(alpha = 0.18f),
            shape = RoundedCornerShape(6.dp)
        ) {
            Text(
                text = value,
                fontSize = 16.sp,
                fontWeight = FontWeight.ExtraBold,
                fontFamily = FontFamily.Monospace,
                color = Color.White,
                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
            )
        }
        Text(
            text = label,
            fontSize = 8.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White.copy(alpha = 0.75f),
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

@Composable
private fun HeroColon() {
    Text(
        text = ":",
        fontSize = 16.sp,
        fontWeight = FontWeight.ExtraBold,
        color = Color.White.copy(alpha = 0.8f),
        modifier = Modifier.padding(bottom = 10.dp)
    )
}

private data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
