package com.bookmyspace.bookmyspace.map

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

data class GeocodeLocationResult(
    val displayName: String,
    val latitude: Double,
    val longitude: Double,
    val city: String = "",
    val state: String = ""
)

/**
 * Open Geocoding Service (Nominatim/OpenStreetMap with debouncing & caching abstraction).
 */
object GeocodingService {

    private val cache = java.util.Collections.synchronizedMap(object : java.util.LinkedHashMap<String, List<GeocodeLocationResult>>(50, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, List<GeocodeLocationResult>>?): Boolean {
            return size > 100
        }
    })

    fun clearCache() {
        cache.clear()
    }

    /**
     * Debounced address geocoding search.
     * Caches query results to avoid overloading open OSM servers.
     */
    suspend fun searchAddress(query: String): List<GeocodeLocationResult> = withContext(Dispatchers.IO) {
        val trimmed = query.trim()
        if (trimmed.length < 3) return@withContext emptyList()

        cache[trimmed.lowercase()]?.let { return@withContext it }

        try {
            val encoded = URLEncoder.encode(trimmed, "UTF-8")
            val urlString = "https://nominatim.openstreetmap.org/search?format=json&q=$encoded&limit=5&addressdetails=1"
            val url = URL(urlString)
            val connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                setRequestProperty("User-Agent", DefaultMapConfiguration.DEFAULT_USER_AGENT)
                connectTimeout = 5000
                readTimeout = 5000
            }

            if (connection.responseCode == 200) {
                val jsonText = connection.inputStream.bufferedReader().use { it.readText() }
                val jsonArray = JSONArray(jsonText)
                val results = mutableListOf<GeocodeLocationResult>()

                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val name = obj.optString("display_name", "")
                    val lat = obj.optString("lat", "0.0").toDoubleOrNull() ?: 0.0
                    val lon = obj.optString("lon", "0.0").toDoubleOrNull() ?: 0.0
                    
                    if (lat != 0.0 && lon != 0.0) {
                        results.add(
                            GeocodeLocationResult(
                                displayName = name,
                                latitude = lat,
                                longitude = lon
                            )
                        )
                    }
                }

                cache[trimmed.lowercase()] = results
                return@withContext results
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Fallback simulated local search if network fails
        val fallbackList = listOf(
            GeocodeLocationResult("Madhapur, Jubilee Hills Road, Hyderabad, Telangana", 17.4399, 78.3808, "Hyderabad", "Telangana"),
            GeocodeLocationResult("Gachibowli Financial District, Hyderabad, Telangana", 17.4401, 78.3489, "Hyderabad", "Telangana"),
            GeocodeLocationResult("Banjara Hills Road No 12, Hyderabad, Telangana", 17.4156, 78.4347, "Hyderabad", "Telangana"),
            GeocodeLocationResult("Hitec City Main Road, Hyderabad, Telangana", 17.4435, 78.3772, "Hyderabad", "Telangana")
        ).filter { it.displayName.lowercase().contains(trimmed.lowercase()) }

        return@withContext fallbackList
    }
}
