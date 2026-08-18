package com.bookmyspace.bookmyspace.data.model

enum class BookingStatus {
    AVAILABLE,
    HELD,
    PENDING,
    CONFIRMED,
    CANCELLED,
    COMPLETED
}

data class Booking(
    val id: String,
    val userId: String,
    val venueId: String,
    val venueName: String,
    val venueImageUrl: String,
    val slotLabel: String,
    val bookingDate: String, // YYYY-MM-DD
    val startTime: String,
    val endTime: String,
    val baseAmount: Double,
    val taxAmount: Double,
    val discountAmount: Double = 0.0,
    val totalAmount: Double,
    val couponCode: String? = null,
    val status: BookingStatus = BookingStatus.PENDING,
    val isPaid: Boolean = false,
    val holdId: String? = null,
    val holdExpiresAtEpochSec: Long? = null,
    val bookingRef: String = "BMS-${id.takeLast(6).uppercase()}",
    val isCheckedIn: Boolean = false,
    val checkInTime: String? = null,
    val checkInMethod: String? = null,
    val createdAt: String = "2026-08-06",
    val rating: Double? = null,
    val feedback: String? = null,
    val paymentRef: String? = null,
    val refundId: String? = null,
    val refundAmount: Double? = null,
    val refundStatus: String? = null
)

data class BookingHoldResponse(
    val success: Boolean,
    val holdId: String? = null,
    val bookingId: String? = null,
    val bookingRef: String? = null,
    val status: BookingStatus = BookingStatus.HELD,
    val expiresAtEpochSec: Long? = null,
    val errorCode: String? = null,
    val message: String
)

data class MaintenanceBlock(
    val id: String,
    val venueId: String,
    val venueName: String,
    val date: String, // YYYY-MM-DD or Today
    val slotTimeLabel: String, // e.g. "Morning (06:00 AM - 10:00 AM)"
    val reason: String,
    val notes: String = "",
    val createdAt: String = "2026-08-08"
)

