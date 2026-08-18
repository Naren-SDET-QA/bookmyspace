package com.bookmyspace.bookmyspace.data.model

/**
 * Type of administrative settlement in India
 */
enum class SettlementType(val label: String) {
    METRO_CITY("Metropolitan City"),
    CITY("City / Corporation"),
    TOWN("Town / Municipality"),
    VILLAGE("Village / Gram Panchayat")
}

/**
 * Level in the India Location Hierarchy
 */
enum class LocationHierarchyLevel(val displayName: String, val stepOrder: Int) {
    COUNTRY("Country", 1),
    STATE("State / UT", 2),
    DISTRICT("District", 3),
    MANDAL("Mandal / Taluk / Tehsil", 4),
    CITY_TOWN("City / Town / Village", 5),
    AREA("Area / Locality / Landmark", 6)
}

/**
 * 1. Country Node (e.g., India)
 */
data class Country(
    val id: String = "IN",
    val code: String = "IND",
    val name: String = "India",
    val phoneCode: String = "+91",
    val currency: String = "INR",
    val isActive: Boolean = true
)

/**
 * 2. State / Union Territory Node (e.g., Andhra Pradesh, Telangana)
 */
data class State(
    val id: String, // e.g. "IN-AP", "IN-TG", "IN-KA"
    val countryId: String = "IN",
    val code: String, // e.g. "AP", "TG", "KA", "TN", "MH"
    val name: String, // e.g. "Andhra Pradesh", "Telangana"
    val capitalCity: String,
    val latitude: Double,
    val longitude: Double,
    val displayOrder: Int = 1,
    val isActive: Boolean = true
)

/**
 * 3. District Node (e.g., Prakasam, Hyderabad, Krishna, Visakhapatnam, Rangareddy)
 */
data class District(
    val id: String, // e.g. "DIST_AP_PRAKASAM", "DIST_TG_HYDERABAD"
    val stateId: String,
    val name: String, // e.g. "Prakasam", "Hyderabad", "NTR (Vijayawada)", "Visakhapatnam"
    val code: String, // e.g. "PKM", "HYD", "VJA", "VSKP"
    val headquarters: String,
    val latitude: Double,
    val longitude: Double,
    val isActive: Boolean = true
)

/**
 * 4. Mandal / Taluk / Tehsil Node (e.g., Ongole Mandal, Singarayakonda, Serilingampally, Khairatabad)
 */
data class Mandal(
    val id: String, // e.g. "MANDAL_AP_ONGOLE", "MANDAL_TG_SERILINGAMPALLY"
    val districtId: String,
    val stateId: String,
    val name: String, // e.g. "Ongole Mandal", "Chirala", "Serilingampally", "Secunderabad"
    val code: String,
    val latitude: Double,
    val longitude: Double,
    val isActive: Boolean = true
)

/**
 * 5. City / Town / Village Node (e.g., Ongole, Vijayawada, Hyderabad, Warangal)
 */
data class CityTown(
    val id: String, // e.g. "CITY_AP_ONGOLE", "CITY_TG_HYDERABAD"
    val mandalId: String,
    val districtId: String,
    val stateId: String,
    val name: String, // e.g. "Ongole", "Hyderabad", "Chirala", "Vijayawada"
    val type: SettlementType = SettlementType.CITY,
    val postalCode: String = "",
    val latitude: Double,
    val longitude: Double,
    val isActive: Boolean = true
)

/**
 * 6. Area / Locality / Neighborhood Node (e.g., Kurnool Road, Lawyerpet, Gachibowli, HITEC City)
 */
data class LocationArea(
    val id: String, // e.g. "AREA_AP_ONGOLE_LAWYERPET", "AREA_TG_HYD_GACHIBOWLI"
    val cityTownId: String,
    val mandalId: String,
    val districtId: String,
    val stateId: String,
    val name: String, // e.g. "Lawyerpet", "Gachibowli", "Jubilee Hills", "Benz Circle"
    val postalCode: String = "",
    val landmark: String = "",
    val latitude: Double,
    val longitude: Double,
    val isPopular: Boolean = false,
    val isActive: Boolean = true
)

/**
 * Complete Hierarchical Location Descriptor attached to Listings and User Context
 */
data class LocationHierarchy(
    val countryId: String = "IN",
    val stateId: String = "IN-TG",
    val districtId: String = "DIST_TG_HYDERABAD",
    val mandalId: String = "MANDAL_TG_SERILINGAMPALLY",
    val cityTownId: String = "CITY_TG_HYDERABAD",
    val areaId: String? = "AREA_TG_HYD_GACHIBOWLI",
    
    val countryName: String = "India",
    val stateName: String = "Telangana",
    val districtName: String = "Hyderabad",
    val mandalName: String = "Serilingampally",
    val cityName: String = "Hyderabad",
    val areaName: String = "Gachibowli",
    val postalCode: String = "500032",
    
    val latitude: Double = 17.4401,
    val longitude: Double = 78.3489
) {
    val cityTownName: String
        get() = cityName
    /**
     * Compact label for AppBar and Cards
     * e.g. "Gachibowli, Hyderabad" or "Ongole, Prakasam"
     */
    val shortLabel: String
        get() = when {
            areaName.isNotBlank() && areaName != cityName -> "$areaName, $cityName"
            cityName.isNotBlank() -> "$cityName, $stateName"
            districtName.isNotBlank() -> "$districtName, $stateName"
            else -> stateName
        }

    /**
     * Formal Breadcrumb format requested:
     * 📍 Andhra Pradesh → Prakasam → Ongole
     */
    val breadcrumbLabel: String
        get() {
            val parts = mutableListOf<String>()
            if (stateName.isNotBlank()) parts.add(stateName)
            if (districtName.isNotBlank() && districtName != cityName) parts.add(districtName)
            if (mandalName.isNotBlank() && mandalName != cityName && mandalName != "$cityName Mandal") parts.add(mandalName)
            if (cityName.isNotBlank()) parts.add(cityName)
            if (areaName.isNotBlank() && areaName != cityName) parts.add(areaName)
            return if (parts.isNotEmpty()) parts.distinct().joinToString(" → ") else "India"
        }

    /**
     * Full formatted address line
     */
    val fullAddressText: String
        get() = listOf(areaName, cityName, mandalName, districtName, stateName, postalCode)
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(", ")
}

/**
 * Filter radius options for nearby listings
 */
enum class LocationSearchRadius(val distanceKm: Double, val displayName: String) {
    EXACT_AREA(0.0, "Exact Area Only"),
    RADIUS_5_KM(5.0, "Within 5 km"),
    RADIUS_10_KM(10.0, "Within 10 km"),
    RADIUS_25_KM(25.0, "Within 25 km (Mandal/City)"),
    RADIUS_50_KM(50.0, "Within 50 km (District)"),
    ENTIRE_STATE(500.0, "Entire State");

    companion object {
        fun fromKm(km: Double): LocationSearchRadius {
            return entries.minByOrNull { kotlin.math.abs(it.distanceKm - km) } ?: RADIUS_10_KM
        }
    }
}
