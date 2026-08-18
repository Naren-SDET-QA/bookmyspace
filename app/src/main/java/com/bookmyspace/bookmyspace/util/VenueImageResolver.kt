package com.bookmyspace.bookmyspace.util

import com.bookmyspace.bookmyspace.data.model.Venue

/**
 * Resolves venue image URLs according to strict priority logic:
 * 1. Owner-uploaded cover image
 * 2. Owner-uploaded gallery
 * 3. Server-provided venue image
 * 4. Category-specific DEV placeholder/fallback
 * 5. Generic final fallback
 */
object VenueImageResolver {

    // High quality category specific DEV placeholder images
    private val FUNCTION_HALL_DEV_IMAGES = listOf(
        "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=800&q=80", // Wedding Banquet
        "https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=800&q=80", // Royal Hall
        "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=800&q=80", // Convention Hall
        "https://images.unsplash.com/photo-1527529482837-4698179dc6ce?auto=format&fit=crop&w=800&q=80"  // Grand Reception
    )

    private val HOTEL_DEV_IMAGES = listOf(
        "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80", // Luxury Hotel Exterior
        "https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=800&q=80", // Deluxe Room
        "https://images.unsplash.com/photo-1578683010236-d716f9a3f461?auto=format&fit=crop&w=800&q=80", // Suite Room
        "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=800&q=80"  // Hotel Lobby
    )

    private val PG_DEV_IMAGES = listOf(
        "https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&w=800&q=80", // Modern PG Room
        "https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?auto=format&fit=crop&w=800&q=80", // Shared Bedroom
        "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80", // Study & Work Lounge
        "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80"  // Dining & Kitchen
    )

    private val MEETING_ROOM_DEV_IMAGES = listOf(
        "https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&q=80", // Conference Room
        "https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=800&q=80", // Board Room
        "https://images.unsplash.com/photo-1517502884422-41eaead166d4?auto=format&fit=crop&w=800&q=80"  // Training Lounge
    )

    private val SPORTS_DEV_IMAGES = listOf(
        "https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=800&q=80", // Football Turf
        "https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=800&q=80", // Cricket Ground
        "https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=800&q=80"  // Badminton / Indoor Court
    )

    private const val GENERIC_FALLBACK = "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=800&q=80"

    /**
     * Priority:
     * 1. Owner cover image (if non-empty & valid)
     * 2. Owner gallery first image
     * 3. Category DEV placeholder
     * 4. Generic fallback
     */
    fun resolveCoverImage(venue: Venue): String {
        // Priority 1: Check cover image explicitly set
        val cover = venue.images.firstOrNull { it.isCover }?.url
        if (!cover.isNullOrBlank() && !isUnsplashGeneric(cover)) {
            return cover
        }

        // Priority 2: Check any image in gallery
        val firstImg = venue.images.firstOrNull()?.url
        if (!firstImg.isNullOrBlank() && !isUnsplashGeneric(firstImg)) {
            return firstImg
        }

        // Priority 3: Category specific DEV placeholder
        return getCategoryPlaceholder(venue.category?.name, venue.id.hashCode())
    }

    /**
     * Returns full gallery list combining owner photos and category fallbacks.
     */
    fun resolveGalleryImages(venue: Venue): List<String> {
        val ownerImages = venue.images.map { it.url }.filter { it.isNotBlank() }
        if (ownerImages.isNotEmpty() && ownerImages.none { isUnsplashGeneric(it) }) {
            return ownerImages
        }

        val placeholders = getCategoryPlaceholderList(venue.category?.name)
        return if (ownerImages.isNotEmpty()) ownerImages + placeholders else placeholders
    }

    private fun isUnsplashGeneric(url: String): Boolean {
        return url == GENERIC_FALLBACK
    }

    fun getCategoryPlaceholder(categoryName: String?, seed: Int = 0): String {
        val list = getCategoryPlaceholderList(categoryName)
        val index = kotlin.math.abs(seed) % list.size
        return list[index]
    }

    fun getCategoryPlaceholderList(categoryName: String?): List<String> {
        val name = categoryName?.lowercase() ?: ""
        return when {
            name.contains("function") || name.contains("hall") || name.contains("wedding") || name.contains("banquet") -> FUNCTION_HALL_DEV_IMAGES
            name.contains("hotel") || name.contains("stay") || name.contains("resort") -> HOTEL_DEV_IMAGES
            name.contains("pg") || name.contains("coliving") || name.contains("hostel") -> PG_DEV_IMAGES
            name.contains("meeting") || name.contains("conference") || name.contains("office") -> MEETING_ROOM_DEV_IMAGES
            name.contains("sport") || name.contains("turf") || name.contains("ground") || name.contains("court") -> SPORTS_DEV_IMAGES
            else -> FUNCTION_HALL_DEV_IMAGES
        }
    }
}
