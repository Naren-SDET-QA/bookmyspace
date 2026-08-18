package com.bookmyspace.bookmyspace.map

/**
 * Clean Map Provider & Configuration abstraction layer.
 * Allows switching tile server providers (e.g. OpenStreetMap, MapLibre Vector Styles, Stamen, Carto)
 * without modifying application business logic or UI components.
 */
interface MapProvider {
    val providerId: String
    val providerName: String
    val tileServerUrl: String
    val userAgent: String
    val maxZoom: Float
    val minZoom: Float
    val attribution: String
}

object DefaultMapConfiguration {
    const val DEFAULT_USER_AGENT = "BookMySpace-Android/1.0 (https://bookmyspace.app)"
    const val OSM_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    const val DEFAULT_LATITUDE = 17.3850
    const val DEFAULT_LONGITUDE = 78.4866
    const val DEFAULT_ZOOM = 15.0
    const val MIN_ZOOM = 4.0
    const val MAX_ZOOM = 19.0
}

class OsmTileMapProvider : MapProvider {
    override val providerId: String = "osm_tile_provider"
    override val providerName: String = "OpenStreetMap / MapLibre Tiles"
    override val tileServerUrl: String = DefaultMapConfiguration.OSM_TILE_URL
    override val userAgent: String = DefaultMapConfiguration.DEFAULT_USER_AGENT
    override val maxZoom: Float = DefaultMapConfiguration.MAX_ZOOM.toFloat()
    override val minZoom: Float = DefaultMapConfiguration.MIN_ZOOM.toFloat()
    override val attribution: String = "© OpenStreetMap contributors"
}

/**
 * Service to manage current location and distance calculations.
 */
object LocationService {
    /**
     * Calculates distance between two Lat/Lng coordinates in kilometers using Haversine formula.
     */
    fun calculateDistanceKm(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ): Double {
        val r = 6371.0 // Earth radius in kilometers
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return Math.round(r * c * 10.0) / 10.0
    }
}
