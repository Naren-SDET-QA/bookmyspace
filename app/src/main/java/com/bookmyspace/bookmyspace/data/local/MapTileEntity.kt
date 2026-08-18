package com.bookmyspace.bookmyspace.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "map_tiles")
data class MapTileEntity(
    @PrimaryKey val tileKey: String, // e.g. "MAPNIK/zoom/x/y"
    val tileSource: String,
    val zoomLevel: Int,
    val tileX: Int,
    val tileY: Int,
    val tileData: ByteArray,
    val cachedAt: Long = System.currentTimeMillis(),
    val expiresAt: Long = System.currentTimeMillis() + (7 * 24 * 60 * 60 * 1000L) // 7 days TTL
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as MapTileEntity
        return tileKey == other.tileKey
    }

    override fun hashCode(): Int {
        return tileKey.hashCode()
    }
}
