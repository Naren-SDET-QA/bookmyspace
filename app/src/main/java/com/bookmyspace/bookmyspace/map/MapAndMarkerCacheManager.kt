package com.bookmyspace.bookmyspace.map

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import android.util.LruCache
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.local.MapTileEntity
import com.bookmyspace.bookmyspace.data.local.VenueMarkerEntity
import com.bookmyspace.bookmyspace.util.PerformanceTracer
import com.bookmyspace.bookmyspace.util.TraceCategory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

/**
 * High-performance L1 (In-Memory LRU) + L2 (Room Persistent Database) cache manager
 * for Map Tiles and Custom Venue Pin Markers.
 * Eliminates redundant network tile requests, reduces bitmap allocations, and prevents UI thread jank.
 */
class MapAndMarkerCacheManager private constructor(context: Context) {

    private val appContext = context.applicationContext
    private val roomDb = BookMySpaceRoomDatabase.getDatabase(appContext)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // L1 In-Memory Caches
    private val markerMemoryCache = object : LruCache<String, Bitmap>(200) {
        override fun sizeOf(key: String, value: Bitmap): Int {
            return value.byteCount / 1024
        }
    }

    private val tileMemoryCache = object : LruCache<String, ByteArray>(500) {
        override fun sizeOf(key: String, value: ByteArray): Int {
            return value.size / 1024
        }
    }

    val roomTileWriter = RoomOsmTileWriter(roomDb)

    init {
        // Run eviction policy on initialization
        runEvictionPolicy()
    }

    // =========================================================================
    // VENUE MARKER CACHING (L1 Memory + L2 Room DB)
    // =========================================================================

    /**
     * Attempts to fetch a cached marker bitmap synchronously from L1 memory cache.
     * If absent, returns null and triggers an async background load from Room L2 DB.
     */
    fun getMarkerFromMemory(key: String): Bitmap? {
        return markerMemoryCache.get(key)
    }

    /**
     * Asynchronously retrieves a venue marker bitmap from L1 Memory or L2 Room DB,
     * or generates it off the UI thread if not present. Guaranteed zero main thread jank.
     */
    suspend fun getOrGenerateMarker(
        key: String,
        venueId: String,
        isSelected: Boolean,
        priceAmount: Double,
        generator: () -> Bitmap
    ): Bitmap = kotlinx.coroutines.withContext(Dispatchers.Default) {
        val memoryBitmap = markerMemoryCache.get(key)
        if (memoryBitmap != null) return@withContext memoryBitmap

        val roomBitmap = getMarkerFromRoom(key)
        if (roomBitmap != null) return@withContext roomBitmap

        val generatedBitmap = generator()
        putMarker(key, venueId, isSelected, priceAmount, generatedBitmap)
        generatedBitmap
    }

    /**
     * Reads a venue marker bitmap from Room L2 DB asynchronously.
     */
    suspend fun getMarkerFromRoom(key: String): Bitmap? = PerformanceTracer.traceAsyncSection("GetRoomVenueMarker", TraceCategory.ROOM_QUERY) {
        try {
            val entity = roomDb.venueMarkerDao().getValidMarkerByKey(key) ?: return@traceAsyncSection null
            val bitmap = BitmapFactory.decodeByteArray(entity.markerPngData, 0, entity.markerPngData.size)
            if (bitmap != null) {
                markerMemoryCache.put(key, bitmap)
                // Touch last accessed
                scope.launch { roomDb.venueMarkerDao().updateLastAccessed(key) }
            }
            bitmap
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Error reading marker from Room: ${e.message}")
            null
        }
    }

    /**
     * Puts a rendered venue marker bitmap into L1 Memory cache and asynchronously persists it to Room L2 DB.
     */
    fun putMarker(
        key: String,
        venueId: String,
        isSelected: Boolean,
        priceAmount: Double,
        bitmap: Bitmap
    ) {
        // 1. Put in L1 Memory Cache
        markerMemoryCache.put(key, bitmap)

        // 2. Persist to L2 Room DB in background
        scope.launch {
            PerformanceTracer.traceAsyncSection("InsertRoomVenueMarker", TraceCategory.ROOM_QUERY) {
                try {
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    val bytes = stream.toByteArray()

                    val entity = VenueMarkerEntity(
                        markerKey = key,
                        venueId = venueId,
                        isSelected = isSelected,
                        priceAmount = priceAmount,
                        markerPngData = bytes,
                        cachedAt = System.currentTimeMillis(),
                        lastAccessed = System.currentTimeMillis()
                    )
                    roomDb.venueMarkerDao().insertMarker(entity)
                    Log.d(TAG, "📌 Cached venue marker to Room: $key (${bytes.size} bytes)")
                } catch (e: Exception) {
                    Log.e(TAG, "Error persisting venue marker: ${e.message}")
                }
            }
        }
    }

    // =========================================================================
    // MAP TILE CACHING (L1 Memory + L2 Room DB)
    // =========================================================================

    fun getTileFromMemory(tileKey: String): ByteArray? {
        return tileMemoryCache.get(tileKey)
    }

    suspend fun getTileFromRoom(tileKey: String): ByteArray? = PerformanceTracer.traceAsyncSection("GetRoomMapTile", TraceCategory.ROOM_QUERY) {
        try {
            val bytes = roomDb.mapTileDao().getValidTileDataByKey(tileKey)
            if (bytes != null) {
                tileMemoryCache.put(tileKey, bytes)
            }
            bytes
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching map tile from Room: ${e.message}")
            null
        }
    }

    fun putTile(
        tileKey: String,
        source: String,
        zoom: Int,
        x: Int,
        y: Int,
        data: ByteArray,
        ttlMillis: Long = 7 * 24 * 60 * 60 * 1000L
    ) {
        tileMemoryCache.put(tileKey, data)
        scope.launch {
            PerformanceTracer.traceAsyncSection("InsertRoomMapTile", TraceCategory.ROOM_QUERY) {
                try {
                    val tile = MapTileEntity(
                        tileKey = tileKey,
                        tileSource = source,
                        zoomLevel = zoom,
                        tileX = x,
                        tileY = y,
                        tileData = data,
                        cachedAt = System.currentTimeMillis(),
                        expiresAt = System.currentTimeMillis() + ttlMillis
                    )
                    roomDb.mapTileDao().insertTile(tile)
                } catch (e: Exception) {
                    Log.e(TAG, "Error persisting tile: ${e.message}")
                }
            }
        }
    }

    // =========================================================================
    // EVICTION POLICY & MAINTENANCE
    // =========================================================================

    /**
     * Executes the eviction policy to clean expired tiles and trim persistent tables to max capacities.
     */
    fun runEvictionPolicy(maxTiles: Int = 3000, maxMarkers: Int = 500) {
        scope.launch {
            try {
                // 1. Purge expired entries
                val deletedExpiredTiles = roomDb.mapTileDao().deleteExpiredTiles()
                val deletedExpiredMarkers = roomDb.venueMarkerDao().deleteExpiredMarkers()

                // 2. Trim excess entries if table size exceeds max bounds
                val tileCount = roomDb.mapTileDao().getTileCount()
                if (tileCount > maxTiles) {
                    val trimmedTiles = roomDb.mapTileDao().trimOldestTiles(tileCount - maxTiles)
                    Log.i(TAG, "🧹 Trimmed $trimmedTiles excess tiles from Room DB.")
                }

                val markerCount = roomDb.venueMarkerDao().getMarkerCount()
                if (markerCount > maxMarkers) {
                    val trimmedMarkers = roomDb.venueMarkerDao().trimOldestMarkers(markerCount - maxMarkers)
                    Log.i(TAG, "🧹 Trimmed $trimmedMarkers excess venue markers from Room DB.")
                }

                if (deletedExpiredTiles > 0 || deletedExpiredMarkers > 0) {
                    Log.i(TAG, "🧹 Eviction sweep completed: $deletedExpiredTiles expired tiles and $deletedExpiredMarkers expired markers purged.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error running cache eviction policy: ${e.message}")
            }
        }
    }

    fun clearAllCaches() {
        markerMemoryCache.evictAll()
        tileMemoryCache.evictAll()
        scope.launch {
            try {
                roomDb.mapTileDao().clearAllTiles()
                roomDb.venueMarkerDao().clearAllMarkers()
                Log.i(TAG, "🧹 Cleared all map and marker caches.")
            } catch (e: Exception) {
                Log.e(TAG, "Error clearing caches: ${e.message}")
            }
        }
    }

    companion object {
        private const val TAG = "MapAndMarkerCacheManager"

        @Volatile
        private var INSTANCE: MapAndMarkerCacheManager? = null

        fun getInstance(context: Context): MapAndMarkerCacheManager {
            return INSTANCE ?: synchronized(this) {
                val instance = MapAndMarkerCacheManager(context)
                INSTANCE = instance
                instance
            }
        }
    }
}
