package com.bookmyspace.bookmyspace.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.bookmyspace.bookmyspace.MainActivity
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.google.firebase.messaging.FirebaseMessaging
import java.util.Calendar
import java.util.concurrent.TimeUnit

object FCMNotificationManager {

    const val CHANNEL_CONFIRMATIONS = "fcm_booking_confirmations"
    const val CHANNEL_REMINDERS = "fcm_slot_reminders"
    const val CHANNEL_STATUS_UPDATES = "fcm_booking_status_updates"

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val channelConfirmations = NotificationChannel(
                CHANNEL_CONFIRMATIONS,
                "Booking Confirmations & Passes",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Push notifications when venue bookings are successfully confirmed"
                enableVibration(true)
                enableLights(true)
            }

            val channelReminders = NotificationChannel(
                CHANNEL_REMINDERS,
                "Upcoming Slot Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Push notifications reminding you 1 hour before your booked slot starts"
                enableVibration(true)
                enableLights(true)
            }

            val channelStatus = NotificationChannel(
                CHANNEL_STATUS_UPDATES,
                "Booking Status Updates",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Push notifications for QR check-ins, completions, and cancellations"
                enableVibration(true)
            }

            notificationManager.createNotificationChannel(channelConfirmations)
            notificationManager.createNotificationChannel(channelReminders)
            notificationManager.createNotificationChannel(channelStatus)
        }
    }

    /**
     * Posts a FCM Push Notification for a Booking Confirmation
     */
    fun postBookingConfirmationNotification(
        context: Context,
        bookingId: String,
        venueName: String,
        bookingDate: String,
        slotLabel: String,
        totalAmount: Double
    ) {
        createNotificationChannels(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("navigate_route", "my_bookings")
            putExtra("booking_id", bookingId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            ("conf_$bookingId").hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = "🎟️ FCM Push: Booking Confirmed!"
        val content = "'$venueName' is confirmed for $bookingDate ($slotLabel). Paid ₹${totalAmount.toInt()}."

        val builder = NotificationCompat.Builder(context, CHANNEL_CONFIRMATIONS)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("Great news! Your booking at $venueName on $bookingDate ($slotLabel) has been confirmed. Total Paid: ₹${totalAmount.toInt()}. Tap to view your pass.")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(("conf_$bookingId").hashCode(), builder.build())
            BookMySpaceRepository.addNotification(
                title = title,
                message = content,
                type = "booking"
            )
            BookMySpaceRepository.logAnalyticsEvent(
                "fcm_push_confirmation_sent",
                mapOf("booking_id" to bookingId, "venue" to venueName),
                "fcm_messaging"
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    /**
     * Posts a FCM Push Notification for Upcoming Slot Reminders
     */
    fun postUpcomingSlotReminderNotification(
        context: Context,
        bookingId: String,
        venueName: String,
        slotLabel: String,
        minutesRemaining: Int = 60
    ) {
        createNotificationChannels(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("navigate_route", "my_bookings")
            putExtra("booking_id", bookingId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            ("rem_$bookingId").hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = "⏰ FCM Push: Slot Starts in $minutesRemaining Mins"
        val content = "Get ready! Your reserved slot ($slotLabel) at '$venueName' starts soon."

        val builder = NotificationCompat.Builder(context, CHANNEL_REMINDERS)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("Reminder: Your slot '$slotLabel' at $venueName starts in approximately $minutesRemaining minutes. Present your QR pass at check-in.")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(("rem_$bookingId").hashCode(), builder.build())
            BookMySpaceRepository.addNotification(
                title = title,
                message = content,
                type = "reminder"
            )
            BookMySpaceRepository.logAnalyticsEvent(
                "fcm_push_reminder_sent",
                mapOf("booking_id" to bookingId, "venue" to venueName),
                "fcm_messaging"
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    /**
     * Posts a FCM Push Notification for Booking Status Updates
     */
    fun postBookingStatusUpdateNotification(
        context: Context,
        bookingId: String,
        venueName: String,
        newStatus: String
    ) {
        createNotificationChannels(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("navigate_route", "my_bookings")
            putExtra("booking_id", bookingId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            ("stat_$bookingId").hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val (statusEmoji, statusText) = when (newStatus.uppercase()) {
            "CONFIRMED" -> "✅" to "CONFIRMED"
            "CHECKED_IN" -> "🎯" to "CHECKED IN (QR Verified)"
            "COMPLETED" -> "🏆" to "COMPLETED"
            "CANCELLED" -> "❌" to "CANCELLED & REFUNDED"
            else -> "ℹ️" to newStatus
        }

        val title = "$statusEmoji FCM Push: Booking $statusText"
        val content = "Your booking for '$venueName' has been updated to $statusText."

        val builder = NotificationCompat.Builder(context, CHANNEL_STATUS_UPDATES)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("Booking Status Update: Your reservation at $venueName (ID: $bookingId) is now $statusText.")
            )
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(("stat_$bookingId").hashCode(), builder.build())
            BookMySpaceRepository.addNotification(
                title = title,
                message = content,
                type = "status_update"
            )
            BookMySpaceRepository.logAnalyticsEvent(
                "fcm_push_status_update_sent",
                mapOf("booking_id" to bookingId, "status" to newStatus),
                "fcm_messaging"
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    /**
     * Fetches current FCM token safely
     */
    fun fetchFCMToken(context: Context, onToken: (String) -> Unit) {
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (task.isSuccessful && task.result != null) {
                    val token = task.result
                    onToken(token)
                    BookMySpaceRepository.updateFcmToken(token)
                } else {
                    val fallback = "fcm_token_dev_${System.currentTimeMillis()}"
                    onToken(fallback)
                    BookMySpaceRepository.updateFcmToken(fallback)
                }
            }
        } catch (e: Exception) {
            val fallback = "fcm_token_dev_${System.currentTimeMillis()}"
            onToken(fallback)
            BookMySpaceRepository.updateFcmToken(fallback)
        }
    }

    /**
     * Schedules an FCM notification trigger to send a push alert 1 hour before the user's scheduled booking start time.
     */
    fun scheduleFCMReminderTrigger(context: Context, booking: Booking) {
        createNotificationChannels(context)
        try {
            val sessionStartMillis = parseStartMillis(booking)
            val currentTimeMillis = System.currentTimeMillis()

            // Calculate target notification time: 1 hour (60 minutes) before start time
            val targetReminderTimeMillis = sessionStartMillis - (60 * 60 * 1000)
            val delayMs = targetReminderTimeMillis - currentTimeMillis

            if (delayMs > 0) {
                val inputData = workDataOf(
                    FCMReminderWorker.KEY_BOOKING_ID to booking.id,
                    FCMReminderWorker.KEY_VENUE_NAME to booking.venueName,
                    FCMReminderWorker.KEY_SLOT_LABEL to booking.slotLabel,
                    FCMReminderWorker.KEY_MINUTES_REMAINING to 60
                )

                val reminderRequest = OneTimeWorkRequestBuilder<FCMReminderWorker>()
                    .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
                    .setInputData(inputData)
                    .build()

                val workName = "fcm_reminder_booking_${booking.id}"
                WorkManager.getInstance(context).enqueueUniqueWork(
                    workName,
                    ExistingWorkPolicy.REPLACE,
                    reminderRequest
                )

                BookMySpaceRepository.logAnalyticsEvent(
                    "fcm_1hr_reminder_scheduled",
                    mapOf(
                        "booking_id" to booking.id,
                        "venue" to booking.venueName,
                        "delay_mins" to (delayMs / (1000 * 60)).toString()
                    ),
                    "fcm_messaging"
                )
            } else {
                // If the booking is starting within 1 hour or already past trigger time, trigger push reminder immediately
                postUpcomingSlotReminderNotification(
                    context = context,
                    bookingId = booking.id,
                    venueName = booking.venueName,
                    slotLabel = booking.slotLabel,
                    minutesRemaining = 60
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Triggers an immediate 1-hour pre-slot FCM reminder push notification for demonstration / QA testing.
     */
    fun triggerTest1HourFCMAlert(context: Context, venueName: String = "SmashPro Badminton Arena", slotLabel: String = "06:00 PM - 07:00 PM") {
        createNotificationChannels(context)
        val testBookingId = "fcm_test_${System.currentTimeMillis()}"
        postUpcomingSlotReminderNotification(
            context = context,
            bookingId = testBookingId,
            venueName = venueName,
            slotLabel = slotLabel,
            minutesRemaining = 60
        )
    }

    private fun parseStartMillis(booking: Booking): Long {
        return try {
            val dateStr = booking.bookingDate
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
            System.currentTimeMillis() + (60 * 60 * 1000)
        }
    }
}
