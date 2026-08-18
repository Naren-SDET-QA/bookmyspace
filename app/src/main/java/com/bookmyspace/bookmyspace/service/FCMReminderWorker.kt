package com.bookmyspace.bookmyspace.service

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * WorkManager CoroutineWorker for triggering FCM Push Notifications
 * 1 hour before scheduled booking start times.
 */
class FCMReminderWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val bookingId = inputData.getString(KEY_BOOKING_ID) ?: ""
            val venueName = inputData.getString(KEY_VENUE_NAME) ?: "Booked Venue"
            val slotLabel = inputData.getString(KEY_SLOT_LABEL) ?: "06:00 PM - 07:00 PM"
            val minsRemaining = inputData.getInt(KEY_MINUTES_REMAINING, 60)

            if (bookingId.isNotEmpty()) {
                FCMNotificationManager.postUpcomingSlotReminderNotification(
                    context = applicationContext,
                    bookingId = bookingId,
                    venueName = venueName,
                    slotLabel = slotLabel,
                    minutesRemaining = minsRemaining
                )
            } else {
                BookingReminderManager.checkAndTriggerUpcomingReminders(applicationContext)
            }
            Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            Result.retry()
        }
    }

    companion object {
        const val KEY_BOOKING_ID = "booking_id"
        const val KEY_VENUE_NAME = "venue_name"
        const val KEY_SLOT_LABEL = "slot_label"
        const val KEY_MINUTES_REMAINING = "minutes_remaining"
    }
}
