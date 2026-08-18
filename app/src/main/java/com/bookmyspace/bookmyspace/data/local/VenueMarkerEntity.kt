package com.bookmyspace.bookmyspace.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "venue_markers")
data class VenueMarkerEntity(
    @PrimaryKey val markerKey: String, // e.g. "venueId_isSelected_price_colors"
    val venueId: String,
    val isSelected: Boolean,
    val priceAmount: Double,
    val markerPngData: ByteArray,
    val cachedAt: Long = System.currentTimeMillis(),
    val lastAccessed: Long = System.currentTimeMillis(),
    val expiresAt: Long = System.currentTimeMillis() + (3 * 24 * 60 * 60 * 1000L) // 3 days TTL
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as VenueMarkerEntity
        return markerKey == other.markerKey
    }

    override fun hashCode(): Int {
        return markerKey.hashCode()
    }
}
