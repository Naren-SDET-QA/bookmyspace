package com.bookmyspace.bookmyspace.service

import android.util.Log
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class BookMySpaceMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "Refreshed FCM Registration Token: $token")
        BookMySpaceRepository.updateFcmToken(token)
        BookMySpaceRepository.logAnalyticsEvent(
            eventName = "fcm_token_refreshed",
            params = mapOf("token_snippet" to token.take(12)),
            category = "fcm_messaging"
        )
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "From: ${remoteMessage.from}")

        // Check if message contains data payload
        val data = remoteMessage.data
        val notificationType = data["notification_type"] ?: data["type"] ?: "booking_confirmation"

        val title = remoteMessage.notification?.title ?: data["title"] ?: "BookMySpace Notification"
        val body = remoteMessage.notification?.body ?: data["body"] ?: data["message"] ?: ""

        val bookingId = data["booking_id"] ?: "b_${System.currentTimeMillis()}"
        val venueName = data["venue_name"] ?: "Booked Venue"
        val bookingDate = data["booking_date"] ?: "Today"
        val slotLabel = data["slot_label"] ?: "06:00 PM - 07:00 PM"
        val amount = data["amount"]?.toDoubleOrNull() ?: 1200.0
        val minutesRemaining = data["minutes_remaining"]?.toIntOrNull() ?: 60
        val status = data["status"] ?: "CONFIRMED"

        when (notificationType) {
            "booking_confirmation" -> {
                FCMNotificationManager.postBookingConfirmationNotification(
                    context = applicationContext,
                    bookingId = bookingId,
                    venueName = venueName,
                    bookingDate = bookingDate,
                    slotLabel = slotLabel,
                    totalAmount = amount
                )
            }
            "slot_reminder" -> {
                FCMNotificationManager.postUpcomingSlotReminderNotification(
                    context = applicationContext,
                    bookingId = bookingId,
                    venueName = venueName,
                    slotLabel = slotLabel,
                    minutesRemaining = minutesRemaining
                )
            }
            "booking_status_update" -> {
                FCMNotificationManager.postBookingStatusUpdateNotification(
                    context = applicationContext,
                    bookingId = bookingId,
                    venueName = venueName,
                    newStatus = status
                )
            }
            else -> {
                // Fallback for general notification
                FCMNotificationManager.postBookingConfirmationNotification(
                    context = applicationContext,
                    bookingId = bookingId,
                    venueName = venueName,
                    bookingDate = bookingDate,
                    slotLabel = slotLabel,
                    totalAmount = amount
                )
            }
        }
    }

    companion object {
        private const val TAG = "BookMySpaceFCM"
    }
}
