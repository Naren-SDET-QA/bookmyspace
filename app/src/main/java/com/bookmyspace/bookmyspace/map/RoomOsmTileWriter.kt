package com.bookmyspace.bookmyspace.map

import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Log
import android.util.LruCache
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.local.MapTileEntity
import com.bookmyspace.bookmyspace.util.PerformanceTracer
import com.bookmyspace.bookmyspace.util.TraceCategory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.osmdroid.tileprovider.modules.IFilesystemCache
import org.osmdroid.tileprovider.tilesource.ITileSource
import org.osmdroid.util.MapTileIndex
import java.io.InputStream

/**
 * High-performance Persistent Room + Memory-backed osmdroid Tile Writer implementation of [IFilesystemCache].
 * Uses an L1 in-memory LRU byte cache for 0ms tile retrieval and async background Room DB persistence.
 * Prevents main thread disk freezes and eliminates redundant map tile downloads.
 */
class RoomOsmTileWriter(
    private val roomDb: BookMySpaceRoomDatabase
) : IFilesystemCache {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val TAG = "RoomOsmTileWriter"

    // Ultra-fast L1 In-Memory Byte Cache for tile downloads and rendered tiles
    private val memoryTileCache = object : LruCache<String, ByteArray>(600) {
        override fun sizeOf(key: String, value: ByteArray): Int {
            return value.size / 1024
        }
    }

    override fun saveFile(
        pTileSource: ITileSource?,
        pMapTileIndex: Long,
        pStream: InputStream?,
        pExpirationTime: Long?
    ): Boolean {
        if (pTileSource == null || pStream == null) return false

        val zoom = MapTileIndex.getZoom(pMapTileIndex)
        val x = MapTileIndex.getX(pMapTileIndex)
        val y = MapTileIndex.getY(pMapTileIndex)
        val sourceName = pTileSource.name()
        val tileKey = "${sourceName}_${zoom}_${x}_${y}"

        try {
            val bytes = pStream.readBytes()
            if (bytes.isEmpty()) return false

            // 1. Instantly store in L1 Memory Cache (0ms hit for next frame)
            memoryTileCache.put(tileKey, bytes)

            // 2. Persist to L2 Room Database asynchronously in background IO
            val ttl = pExpirationTime ?: (System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L)
            val tileEntity = MapTileEntity(
                tileKey = tileKey,
                tileSource = sourceName,
                zoomLevel = zoom,
                tileX = x,
                tileY = y,
                tileData = bytes,
                cachedAt = System.currentTimeMillis(),
                expiresAt = ttl
            )

            scope.launch {
                PerformanceTracer.traceAsyncSection("RoomInsertMapTile", TraceCategory.ROOM_QUERY) {
                    try {
                        roomDb.mapTileDao().insertTile(tileEntity)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error saving tile $tileKey to Room: ${e.message}")
                    }
                }
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error reading tile stream for $tileKey: ${e.message}")
            return false
        }
    }

    override fun exists(pTileSource: ITileSource?, pMapTileIndex: Long): Boolean {
        if (pTileSource == null) return false
        val zoom = MapTileIndex.getZoom(pMapTileIndex)
        val x = MapTileIndex.getX(pMapTileIndex)
        val y = MapTileIndex.getY(pMapTileIndex)
        val tileKey = "${pTileSource.name()}_${zoom}_${x}_${y}"

        // Fast L1 Memory Cache check (0ms)
        if (memoryTileCache.get(tileKey) != null) {
            return true
        }

        // L2 Room Database check
        return try {
            runBlocking(Dispatchers.IO) {
                val data = roomDb.mapTileDao().getValidTileDataByKey(tileKey)
                if (data != null && data.isNotEmpty()) {
                    memoryTileCache.put(tileKey, data)
                    true
                } else false
            }
        } catch (e: Exception) {
            false
        }
    }

    override fun loadTile(pTileSource: ITileSource?, pMapTileIndex: Long): Drawable? {
        if (pTileSource == null) return null
        val zoom = MapTileIndex.getZoom(pMapTileIndex)
        val x = MapTileIndex.getX(pMapTileIndex)
        val y = MapTileIndex.getY(pMapTileIndex)
        val tileKey = "${pTileSource.name()}_${zoom}_${x}_${y}"

        // 1. Check Fast L1 Memory Cache (0ms hit)
        val memBytes = memoryTileCache.get(tileKey)
        if (memBytes != null && memBytes.isNotEmpty()) {
            val bitmap = BitmapFactory.decodeByteArray(memBytes, 0, memBytes.size)
            if (bitmap != null) {
                return BitmapDrawable(null, bitmap)
            }
        }

        // 2. Check L2 Room Database
        return try {
            runBlocking(Dispatchers.IO) {
                val data = roomDb.mapTileDao().getValidTileDataByKey(tileKey)
                if (data != null && data.isNotEmpty()) {
                    memoryTileCache.put(tileKey, data)
                    val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size)
                    if (bitmap != null) {
                        BitmapDrawable(null, bitmap)
                    } else null
                } else null
            }
        } catch (e: Exception) {
            null
        }
    }

    override fun onDetach() {
        memoryTileCache.evictAll()
        Log.d(TAG, "RoomOsmTileWriter detached.")
    }

    override fun remove(pTileSource: ITileSource?, pMapTileIndex: Long): Boolean {
        if (pTileSource == null) return false
        val zoom = MapTileIndex.getZoom(pMapTileIndex)
        val x = MapTileIndex.getX(pMapTileIndex)
        val y = MapTileIndex.getY(pMapTileIndex)
        val tileKey = "${pTileSource.name()}_${zoom}_${x}_${y}"
        memoryTileCache.remove(tileKey)
        return true
    }

    override fun getExpirationTimestamp(pTileSource: ITileSource?, pMapTileIndex: Long): Long {
        return System.currentTimeMillis() + (7 * 24 * 60 * 60 * 1000L)
    }

    fun purgeExpiredAndTrim(maxTileCount: Int = 3000) {
        scope.launch {
            try {
                val deletedExpired = roomDb.mapTileDao().deleteExpiredTiles()
                val totalCount = roomDb.mapTileDao().getTileCount()
                if (totalCount > maxTileCount) {
                    val trimCount = totalCount - maxTileCount
                    val trimmed = roomDb.mapTileDao().trimOldestTiles(trimCount)
                    Log.i(TAG, "🧹 Evicted $deletedExpired expired and $trimmed excess map tiles (Total remaining: ${totalCount - trimmed})")
                } else if (deletedExpired > 0) {
                    Log.i(TAG, "🧹 Evicted $deletedExpired expired map tiles from Room DB")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Eviction failed: ${e.message}")
            }
        }
    }
}
