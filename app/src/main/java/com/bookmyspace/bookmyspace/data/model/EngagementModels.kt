package com.bookmyspace.bookmyspace.data.model

data class Review(
    val id: String,
    val venueId: String,
    val userName: String,
    val rating: Double,
    val comment: String,
    val date: String,
    val bookingId: String? = null,
    val userEmail: String? = null,
    val tags: List<String> = emptyList(),
    val verifiedBooking: Boolean = true
)

data class NotificationItem(
    val id: String,
    val title: String,
    val message: String,
    val timestamp: String,
    val isRead: Boolean = false,
    val type: String = "booking" // booking, promo, system
)

data class SupportTicket(
    val id: String,
    val subject: String,
    val description: String,
    val category: String,
    val status: String = "Open", // Open, In Progress, Resolved
    val createdAt: String
)

data class AuditLogEntry(
    val id: String,
    val action: String,
    val userEmail: String,
    val details: String,
    val timestamp: String
)

data class OwnerMetric(
    val totalRevenue: Double,
    val totalBookings: Int,
    val activeVenuesCount: Int,
    val averageRating: Double
)

data class FirebaseAnalyticsEvent(
    val id: String,
    val name: String,
    val params: Map<String, String>,
    val timestamp: String,
    val category: String = "engagement" // engagement, booking_flow, auth, custom
)
