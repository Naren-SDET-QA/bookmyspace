package com.bookmyspace.bookmyspace.data.model

data class VenueCategory(
    val id: String,
    val slug: String,
    val name: String,
    val iconName: String = "sports"
)

data class VenueImage(
    val id: String,
    val url: String,
    val altText: String = "",
    val isCover: Boolean = false
)

data class VenueFacility(
    val facility: String,
    val isAvailable: Boolean = true
)

data class VenueOperatingHours(
    val dayOfWeek: Int, // 0 = Mon, 6 = Sun
    val opensAt: String,
    val closesAt: String,
    val isClosed: Boolean = false
)

data class VenuePackage(
    val id: String,
    val name: String,
    val priceAmount: Double,
    val description: String,
    val itemsIncluded: List<String> = emptyList(),
    val vegPlatePrice: Double = 0.0,
    val nonVegPlatePrice: Double = 0.0
)

data class VenueAddon(
    val id: String,
    val name: String,
    val priceAmount: Double,
    val description: String = ""
)

data class PgSharingOption(
    val id: String,
    val typeName: String,
    val monthlyRent: Double,
    val depositAmount: Double,
    val isAvailable: Boolean = true,
    val roomFeatures: List<String> = emptyList()
)

data class PgDetails(
    val pgType: String = "Co-living",
    val sharingOptions: List<PgSharingOption> = emptyList(),
    val gateLockTime: String = "10:30 PM",
    val noticePeriodDays: Int = 30,
    val securityDepositMonths: Double = 1.0,
    val mealPlan: String = "3 Meals Daily Included (Veg & Non-Veg)",
    val preferredOccupants: String = "Students & Working Professionals",
    val electricityCharges: String = "Sub-metered at ₹8/unit",
    val maintenanceFee: Double = 0.0
)

data class HotelDetails(
    val starRating: Int = 4, // 3, 4, 5
    val propertyType: String = "4-Star Luxury Boutique Hotel",
    val roomTypes: List<String> = listOf("Deluxe King Room", "Executive Business Suite", "Flexi Day Stay"),
    val checkInTime: String = "12:00 PM",
    val checkOutTime: String = "11:00 AM",
    val allowsFlexiStay: Boolean = true
)

data class TimeSlot(
    val id: String,
    val venueId: String,
    val label: String,
    val startTime: String,
    val endTime: String,
    val priceAmount: Double,
    val isAvailable: Boolean = true
)

data class ContactSettings(
    val showCall: Boolean = false,
    val showWhatsapp: Boolean = false,
    val showChat: Boolean = false,
    val showOwnerContact: Boolean = false,
    val contactBookMySpace: Boolean = true,
    val allowPostBookingDirectContact: Boolean = false
)

data class Venue(
    val id: String,
    val name: String,
    val slug: String = "",
    val description: String = "",
    val addressLine1: String = "",
    val city: String = "Hyderabad",
    val state: String = "Telangana",
    val latitude: Double = 17.3850,
    val longitude: Double = 78.4866,
    val capacity: Int = 500,
    val minGuests: Int = 100,
    val maxGuests: Int = 1200,
    val distanceKm: Double = 2.4,
    val pricingBaseAmount: Double = 75000.0,
    val taxRate: Double = 18.0,
    val parkingCapacity: Int = 150,
    val foodOptions: String = "In-house & External Catering",
    val rules: String = "No firecrackers after 10 PM. Outside caterers permitted with NOC. Alcohol permitted with temporary license.",
    val isVerified: Boolean = true,
    val isActive: Boolean = true,
    val avgRating: Double = 4.8,
    val ratingCount: Int = 324,
    val category: VenueCategory? = null,
    val images: List<VenueImage> = emptyList(),
    val facilities: List<VenueFacility> = emptyList(),
    val packages: List<VenuePackage> = emptyList(),
    val addons: List<VenueAddon> = emptyList(),
    val pgDetails: PgDetails? = null,
    val hotelDetails: HotelDetails? = null,
    val operatingHours: List<VenueOperatingHours> = emptyList(),
    val timeSlots: List<TimeSlot> = emptyList(),
    val contactPhone: String = "98765-43210",
    val contactWhatsapp: String = "919876543210",
    val contactSettings: ContactSettings = ContactSettings(),
    val isSaved: Boolean = false,
    val locationHierarchy: LocationHierarchy? = null
) {
    val coverImageUrl: String
        get() = images.firstOrNull { it.isCover }?.url
            ?: images.firstOrNull()?.url
            ?: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3"

    val fullAddress: String
        get() = locationHierarchy?.fullAddressText
            ?: listOf(addressLine1, city, state).filter { it.isNotBlank() }.joinToString(", ")
}

enum class VenueSortBy {
    RELEVANCE,
    PRICE_LOW_HIGH,
    PRICE_HIGH_LOW,
    RATING,
    DISTANCE
}

data class VenueSearchQuery(
    val query: String = "",
    val categorySlug: String? = null,
    val city: String? = null,
    val minPrice: Double? = null,
    val maxPrice: Double? = null,
    val radiusKm: Double? = null,
    val minGuests: Int? = null,
    val eventType: String? = null,
    val propertyType: String? = null, // "VENUE", "PG", "HOTEL"
    val pgType: String? = null,
    val roomSharingType: String? = null,
    val minStarRating: Int? = null,
    val hotelRoomType: String? = null,
    val sortBy: VenueSortBy = VenueSortBy.RELEVANCE
)
