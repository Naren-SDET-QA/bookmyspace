package com.bookmyspace.bookmyspace.service

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * WorkManager CoroutineWorker for checking upcoming bookings in the background
 * and triggering local notifications 1 hour before session start time.
 */
class BookingReminderWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            BookingReminderManager.checkAndTriggerUpcomingReminders(applicationContext)
            Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            Result.retry()
        }
    }
}
