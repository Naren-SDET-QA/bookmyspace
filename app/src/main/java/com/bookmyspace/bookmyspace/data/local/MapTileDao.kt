package com.bookmyspace.bookmyspace.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface MapTileDao {
    @Query("SELECT * FROM map_tiles WHERE tileKey = :tileKey LIMIT 1")
    suspend fun getTileByKey(tileKey: String): MapTileEntity?

    @Query("SELECT tileData FROM map_tiles WHERE tileKey = :tileKey AND expiresAt > :nowMillis LIMIT 1")
    suspend fun getValidTileDataByKey(tileKey: String, nowMillis: Long = System.currentTimeMillis()): ByteArray?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTile(tile: MapTileEntity)

    @Query("DELETE FROM map_tiles WHERE expiresAt < :nowMillis")
    suspend fun deleteExpiredTiles(nowMillis: Long = System.currentTimeMillis()): Int

    @Query("DELETE FROM map_tiles WHERE tileKey IN (SELECT tileKey FROM map_tiles ORDER BY cachedAt ASC LIMIT :limit)")
    suspend fun trimOldestTiles(limit: Int): Int

    @Query("SELECT COUNT(*) FROM map_tiles")
    suspend fun getTileCount(): Int

    @Query("DELETE FROM map_tiles")
    suspend fun clearAllTiles()
}
