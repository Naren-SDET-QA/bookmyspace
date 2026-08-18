package com.bookmyspace.bookmyspace.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface VenueMarkerDao {
    @Query("SELECT * FROM venue_markers WHERE markerKey = :key AND expiresAt > :nowMillis LIMIT 1")
    suspend fun getValidMarkerByKey(key: String, nowMillis: Long = System.currentTimeMillis()): VenueMarkerEntity?

    @Query("SELECT markerPngData FROM venue_markers WHERE markerKey = :key AND expiresAt > :nowMillis LIMIT 1")
    suspend fun getValidMarkerPngByKey(key: String, nowMillis: Long = System.currentTimeMillis()): ByteArray?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMarker(marker: VenueMarkerEntity)

    @Query("UPDATE venue_markers SET lastAccessed = :nowMillis WHERE markerKey = :key")
    suspend fun updateLastAccessed(key: String, nowMillis: Long = System.currentTimeMillis())

    @Query("DELETE FROM venue_markers WHERE expiresAt < :nowMillis")
    suspend fun deleteExpiredMarkers(nowMillis: Long = System.currentTimeMillis()): Int

    @Query("DELETE FROM venue_markers WHERE markerKey IN (SELECT markerKey FROM venue_markers ORDER BY lastAccessed ASC LIMIT :limit)")
    suspend fun trimOldestMarkers(limit: Int): Int

    @Query("SELECT COUNT(*) FROM venue_markers")
    suspend fun getMarkerCount(): Int

    @Query("DELETE FROM venue_markers")
    suspend fun clearAllMarkers()
}
