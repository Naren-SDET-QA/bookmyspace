package com.bookmyspace.bookmyspace.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.bookmyspace.bookmyspace.MainActivity
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

object BookingReminderManager {

    const val CHANNEL_ID = "booking_reminders_channel"
    const val CHANNEL_NAME = "Booking Reminders & Session Alerts"
    const val WORK_NAME = "booking_reminder_periodic_work"

    private val notifiedBookingIds = mutableSetOf<String>()

    /**
     * Initializes notification channels and schedules background WorkManager task.
     */
    fun init(context: Context) {
        createNotificationChannel(context)
        scheduleBackgroundReminderWorker(context)
    }

    /**
     * Creates system notification channel (Android 8.0+)
     */
    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Sends local reminders 1 hour before booked venue sessions start"
                enableVibration(true)
                enableLights(true)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Schedules periodic background task via WorkManager to inspect upcoming bookings every 15 minutes.
     */
    fun scheduleBackgroundReminderWorker(context: Context) {
        try {
            val reminderWorkRequest = PeriodicWorkRequestBuilder<BookingReminderWorker>(
                15, TimeUnit.MINUTES
            ).build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                reminderWorkRequest
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Checks all confirmed bookings in the repository and triggers local notifications
     * for any sessions starting within 1 hour.
     */
    fun checkAndTriggerUpcomingReminders(context: Context): Int {
        createNotificationChannel(context)

        val bookings = BookMySpaceRepository.bookings.value
        val confirmedBookings = bookings.filter { it.status == BookingStatus.CONFIRMED && it.isPaid }

        val currentTimeMillis = System.currentTimeMillis()
        var triggeredCount = 0

        for (booking in confirmedBookings) {
            if (notifiedBookingIds.contains(booking.id)) continue

            val sessionStartMillis = parseBookingStartMillis(booking)

            // If session is within 1 hour from now (0 to 60 minutes away) or today's upcoming session
            val diffMinutes = (sessionStartMillis - currentTimeMillis) / (1000 * 60)

            if (diffMinutes in 0..65 || isSessionUpcomingToday(booking)) {
                postLocalBookingNotification(context, booking, minutesRemaining = diffMinutes.coerceAtLeast(10))
                notifiedBookingIds.add(booking.id)
                triggeredCount++
            }
        }

        return triggeredCount
    }

    /**
     * Posts a local Android system notification for a specific booking.
     */
    fun postLocalBookingNotification(context: Context, booking: Booking, minutesRemaining: Long = 60) {
        createNotificationChannel(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("navigate_route", "my_bookings")
            putExtra("booking_id", booking.id)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            booking.id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = "⏰ Session Reminder: ${booking.venueName}"
        val content = "Your slot (${booking.slotLabel}) starts in ~$minutesRemaining mins! Tap to view details and pass."

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("Get ready! Your reserved slot '${booking.slotLabel}' at ${booking.venueName} is scheduled for ${booking.bookingDate} (${booking.startTime}). Reference: ${booking.bookingRef}.")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(booking.id.hashCode(), builder.build())
            BookMySpaceRepository.addNotification(
                title = title,
                message = content,
                type = "reminder"
            )
            BookMySpaceRepository.logAnalyticsEvent(
                "booking_reminder_notification_posted",
                mapOf("booking_id" to booking.id, "venue" to booking.venueName),
                "reminders"
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    /**
     * Triggers an immediate test notification for demonstration/testing purposes.
     */
    fun triggerImmediateTestNotification(context: Context, venueName: String = "SmashPro Badminton Arena", slotLabel: String = "06:00 PM - 07:00 PM") {
        createNotificationChannel(context)

        val sampleBooking = Booking(
            id = "test_rem_${System.currentTimeMillis()}",
            userId = "u_101",
            venueId = "v_1",
            venueName = venueName,
            venueImageUrl = "",
            slotLabel = slotLabel,
            bookingDate = "Today",
            startTime = "06:00 PM",
            endTime = "07:00 PM",
            baseAmount = 1200.0,
            taxAmount = 216.0,
            totalAmount = 1416.0,
            status = BookingStatus.CONFIRMED,
            isPaid = true
        )

        postLocalBookingNotification(context, sampleBooking, minutesRemaining = 55)
    }

    private fun parseBookingStartMillis(booking: Booking): Long {
        return try {
            val dateStr = booking.bookingDate // e.g. 2026-08-08 or Today
            val timeStr = booking.startTime.ifEmpty { booking.slotLabel.split("-").firstOrNull()?.trim() ?: "06:00 PM" }
            
            val calendar = Calendar.getInstance()
            if (!dateStr.equals("Today", ignoreCase = true) && dateStr.contains("-")) {
                val parts = dateStr.split("-")
                if (parts.size == 3) {
                    calendar.set(Calendar.YEAR, parts[0].toInt())
                    calendar.set(Calendar.MONTH, parts[1].toInt() - 1)
                    calendar.set(Calendar.DAY_OF_MONTH, parts[2].toInt())
                }
            }

            val timeParts = timeStr.replace("AM", "").replace("PM", "").trim().split(":")
            if (timeParts.size >= 2) {
                var hour = timeParts[0].trim().toInt()
                val min = timeParts[1].trim().toInt()
                if (timeStr.contains("PM", ignoreCase = true) && hour < 12) hour += 12
                if (timeStr.contains("AM", ignoreCase = true) && hour == 12) hour = 0
                calendar.set(Calendar.HOUR_OF_DAY, hour)
                calendar.set(Calendar.MINUTE, min)
                calendar.set(Calendar.SECOND, 0)
            }
            calendar.timeInMillis
        } catch (e: Exception) {
            System.currentTimeMillis() + (45 * 60 * 1000) // fallback 45 mins ahead
        }
    }

    private fun isSessionUpcomingToday(booking: Booking): Boolean {
        return booking.bookingDate.equals("Today", ignoreCase = true) ||
                booking.bookingDate == SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }
}
