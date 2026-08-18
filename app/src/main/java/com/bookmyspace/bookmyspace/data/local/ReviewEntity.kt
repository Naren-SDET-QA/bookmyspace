package com.bookmyspace.bookmyspace.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "reviews")
data class ReviewEntity(
    @PrimaryKey val id: String,
    val venueId: String,
    val userName: String,
    val rating: Double,
    val comment: String,
    val date: String,
    val bookingId: String? = null,
    val userEmail: String? = null,
    val tags: String = "",
    val verifiedBooking: Boolean = true
)
