package com.bookmyspace.bookmyspace.data.model

/**
 * Source of truth for the customer first-screen experience.
 *
 * The live customer app shows exactly these four sections. Search, Map,
 * Bol-ke-Book, 1-Tap, Help, filters and booking entry all read this catalog
 * instead of mixing property types.
 */
enum class CustomerSection(
    val id: String,
    val title: String,
    val subtitle: String,
    val emoji: String,
    val adminSectionKey: String,
    val listingTarget: ListingTargetCategory,
    val categorySlugs: Set<String>,
    val categories: List<CustomerSectionCategory>
) {
    FUNCTION_HALLS(
        id = "function_halls",
        title = "Function Halls",
        subtitle = "Marriage, Convention, Party, Community & Govt Halls",
        emoji = "🏛️",
        adminSectionKey = "venues_function_halls",
        listingTarget = ListingTargetCategory.FUNCTION_HALL,
        categorySlugs = setOf(
            "function_hall", "banquet_hall", "marriage_hall", "party_lawn",
            "convention_center", "community_hall", "govt_hall", "auditorium",
            "party_hall", "venues_function_halls"
        ),
        categories = listOf(
            CustomerSectionCategory("all", "All Halls", "✨", "Every function space"),
            CustomerSectionCategory("marriage_hall", "Marriage Hall", "💒", "Weddings & Receptions"),
            CustomerSectionCategory("convention_center", "Convention Hall", "🏛️", "Summits & Conferences"),
            CustomerSectionCategory("banquet_hall", "Party Hall / Banquet", "🍸", "Birthdays & Dinners"),
            CustomerSectionCategory("community_hall", "Community Hall", "🤝", "Family & Society Meets"),
            CustomerSectionCategory("govt_hall", "Government Hall", "🏢", "Official & Public Town Halls"),
            CustomerSectionCategory("party_lawn", "Open Lawn Ground", "🌳", "Outdoor Weddings & Lawns")
        )
    ),
    LODGE_ROOMS(
        id = "lodge_rooms",
        title = "Lodge / Rooms",
        subtitle = "Hotels, Lodges, Guest Houses & Day Rooms",
        emoji = "🏨",
        adminSectionKey = "hotels_rooms",
        listingTarget = ListingTargetCategory.ROOM,
        categorySlugs = setOf(
            "hotel_stay", "hotel", "lodge", "guest_house", "hourly_room",
            "resort", "homestay", "hotels_rooms", "room"
        ),
        categories = listOf(
            CustomerSectionCategory("all", "All Stays", "✨", "Every stay option"),
            CustomerSectionCategory("hotel", "Hotel", "🏨", "Luxury & Star Stays"),
            CustomerSectionCategory("lodge", "Lodge", "🛏️", "Budget & Short-stay Lodges"),
            CustomerSectionCategory("guest_house", "Guest House", "🏡", "Quiet & Homely Guest Rooms"),
            CustomerSectionCategory("hourly_room", "Hourly / Day Room", "⏱️", "Short Stay & Day Use"),
            CustomerSectionCategory("resort", "Resort / Homestay", "🌴", "Getaways & Nature Stays")
        )
    ),
    PG_HOSTELS(
        id = "pg_hostels",
        title = "PG / Hostels",
        subtitle = "Gents PG, Ladies PG, Hostels & Co-living",
        emoji = "🏠",
        adminSectionKey = "pg_hostels",
        listingTarget = ListingTargetCategory.PG_HOSTEL,
        categorySlugs = setOf(
            "pg_hostel", "hostel", "co_living", "gents_pg", "ladies_pg",
            "student_hostel", "pg_hostels", "pg"
        ),
        categories = listOf(
            CustomerSectionCategory("all", "All PG & Hostels", "✨", "Every PG option"),
            CustomerSectionCategory("gents_pg", "Gents PG", "👨", "Men's Stays with Food & WiFi"),
            CustomerSectionCategory("ladies_pg", "Ladies PG", "👩", "Women's Safe Secure Stays"),
            CustomerSectionCategory("student_hostel", "Student Hostel", "🎒", "College & Academy Hostels"),
            CustomerSectionCategory("co_living", "Co-living Spaces", "🤝", "Modern Shared Living"),
            CustomerSectionCategory("single_room", "Single Sharing Room", "🔑", "Private & Shared Rooms")
        )
    ),
    INSTITUTES_CLASSES(
        id = "institutes_classes",
        title = "Institutes / Classes",
        subtitle = "Coaching, Tuition, Computer, Dance, Music & Sports",
        emoji = "🎓",
        adminSectionKey = "institutes_classes",
        listingTarget = ListingTargetCategory.INSTITUTE,
        categorySlugs = setOf(
            "institute", "class", "coaching", "academy", "badminton",
            "sports_turf", "sports_ground", "dance", "music", "institutes_classes"
        ),
        categories = listOf(
            CustomerSectionCategory("all", "All Classes", "✨", "Every class & academy"),
            CustomerSectionCategory("coaching", "Coaching & Tuition", "📚", "School, College & Prep"),
            CustomerSectionCategory("computer_it", "Computer & IT Classes", "💻", "Coding, AI & Digital Skills"),
            CustomerSectionCategory("dance_academy", "Dance Academy", "💃", "Classical, Western & Zumba"),
            CustomerSectionCategory("music_class", "Music & Singing", "🎵", "Guitar, Keyboard & Vocals"),
            CustomerSectionCategory("sports_academy", "Sports Academy & Turfs", "🏸", "Badminton, Cricket & Fitness")
        )
    );

    companion object {
        fun fromId(id: String?): CustomerSection? {
            if (id.isNullOrBlank()) return null
            return entries.find {
                it.id.equals(id, ignoreCase = true) ||
                    it.adminSectionKey.equals(id, ignoreCase = true)
            }
        }

        fun fromAny(value: String?): CustomerSection? {
            if (value.isNullOrBlank()) return null
            fromId(value)?.let { return it }
            val lower = value.lowercase()
            return entries.find { section ->
                section.categorySlugs.any { it.equals(lower, ignoreCase = true) } ||
                    section.categories.any { it.id.equals(lower, ignoreCase = true) }
            }
        }
    }
}

data class CustomerSectionCategory(
    val id: String,
    val label: String,
    val emoji: String,
    val description: String = ""
)

object CustomerSectionCatalog {

    fun sectionForVenue(venue: Venue): CustomerSection? {
        val slug = venue.category?.slug?.lowercase().orEmpty()
        if (venue.pgDetails != null || slug in CustomerSection.PG_HOSTELS.categorySlugs) {
            return CustomerSection.PG_HOSTELS
        }
        if (venue.hotelDetails != null || slug in CustomerSection.LODGE_ROOMS.categorySlugs) {
            return CustomerSection.LODGE_ROOMS
        }
        if (slug in CustomerSection.INSTITUTES_CLASSES.categorySlugs) {
            return CustomerSection.INSTITUTES_CLASSES
        }
        if (slug in CustomerSection.FUNCTION_HALLS.categorySlugs) {
            return CustomerSection.FUNCTION_HALLS
        }
        return null
    }

    fun matchesVenue(
        venue: Venue,
        section: CustomerSection,
        categorySlug: String? = "all"
    ): Boolean {
        if (sectionForVenue(venue) != section) return false
        val selected = categorySlug?.lowercase()?.takeIf { it.isNotBlank() && it != "all" }
            ?: return true
        return matchesVenueCategory(venue, section, selected)
    }

    fun matchesInstitute(
        institute: InstituteProfile,
        categorySlug: String? = "all"
    ): Boolean {
        val selected = categorySlug?.lowercase()?.takeIf { it.isNotBlank() && it != "all" }
            ?: return true
        val haystack = (
            institute.categories + listOf(institute.name, institute.description)
            ).joinToString(" ").lowercase()
        return categoryTokens(CustomerSection.INSTITUTES_CLASSES, selected)
            .any { haystack.contains(it) }
    }

    fun matchesInstituteClass(
        item: InstituteClass,
        categorySlug: String? = "all"
    ): Boolean {
        val selected = categorySlug?.lowercase()?.takeIf { it.isNotBlank() && it != "all" }
            ?: return true
        val haystack = listOf(item.category, item.title, item.description, item.instituteName)
            .joinToString(" ")
            .lowercase()
        return categoryTokens(CustomerSection.INSTITUTES_CLASSES, selected)
            .any { haystack.contains(it) }
    }

    fun amenityFilters(section: CustomerSection): List<AmenityFilterSpec> {
        return when (section) {
            CustomerSection.FUNCTION_HALLS -> listOf(
                AmenityFilterSpec("parking", "Parking", "🅿️", listOf("parking", "valet", "car")),
                AmenityFilterSpec("wifi", "Wi-Fi", "📶", listOf("wifi", "wi-fi", "internet", "fiber")),
                AmenityFilterSpec("changing_rooms", "Changing Rooms", "🚿", listOf("changing", "shower", "washroom", "restroom", "dressing", "locker", "bath")),
                AmenityFilterSpec("ac", "Air Conditioned", "❄️", listOf("ac", "air condition", "centralized ac", "cooling")),
                AmenityFilterSpec("power_backup", "Power Backup", "⚡", listOf("power backup", "generator", "power", "electricity")),
                AmenityFilterSpec("catering", "In-House Food", "🍽️", listOf("cater", "kitchen", "food", "dining", "meal", "buffet", "snack")),
                AmenityFilterSpec("stage_sound", "Stage / Sound", "🎤", listOf("stage", "sound", "led", "audio", "mic", "dj"))
            )
            CustomerSection.LODGE_ROOMS -> listOf(
                AmenityFilterSpec("wifi", "Wi-Fi", "📶", listOf("wifi", "wi-fi", "internet")),
                AmenityFilterSpec("ac", "Air Conditioned", "❄️", listOf("ac", "air condition", "cooling")),
                AmenityFilterSpec("parking", "Parking", "🅿️", listOf("parking", "valet", "car")),
                AmenityFilterSpec("pool", "Swimming Pool", "🏊", listOf("pool", "swimming")),
                AmenityFilterSpec("rooms", "Suite / Rooms", "🛏️", listOf("room", "suite", "bedroom", "stay")),
                AmenityFilterSpec("breakfast", "Breakfast", "🍳", listOf("breakfast", "buffet"))
            )
            CustomerSection.PG_HOSTELS -> listOf(
                AmenityFilterSpec("wifi", "Wi-Fi", "📶", listOf("wifi", "wi-fi", "internet")),
                AmenityFilterSpec("food", "Food / Mess", "🍽️", listOf("meal", "food", "mess", "dining")),
                AmenityFilterSpec("ac", "Air Conditioned", "❄️", listOf("ac", "air condition")),
                AmenityFilterSpec("security", "CCTV / Security", "📹", listOf("cctv", "security", "biometric", "warden")),
                AmenityFilterSpec("parking", "Parking", "🅿️", listOf("parking", "car", "bike")),
                AmenityFilterSpec("laundry", "Laundry", "👕", listOf("laundry", "washing"))
            )
            CustomerSection.INSTITUTES_CLASSES -> listOf(
                AmenityFilterSpec("parking", "Parking", "🅿️", listOf("parking", "car")),
                AmenityFilterSpec("changing_rooms", "Changing Rooms", "🚿", listOf("changing", "shower", "locker")),
                AmenityFilterSpec("wifi", "Wi-Fi", "📶", listOf("wifi", "wi-fi", "internet")),
                AmenityFilterSpec("ac", "Air Conditioned", "❄️", listOf("ac", "air condition")),
                AmenityFilterSpec("lockers", "Lockers", "🔒", listOf("locker"))
            )
        }
    }

    fun bookingCtaLabel(section: CustomerSection?): String {
        return when (section) {
            CustomerSection.PG_HOSTELS -> "Reserve"
            CustomerSection.LODGE_ROOMS -> "Book Stay"
            CustomerSection.INSTITUTES_CLASSES -> "Enroll"
            CustomerSection.FUNCTION_HALLS -> "Book Now"
            null -> "Book Now"
        }
    }

    fun bookingScreenTitle(section: CustomerSection?): String {
        return when (section) {
            CustomerSection.PG_HOSTELS -> "Reserve PG"
            CustomerSection.LODGE_ROOMS -> "Book Stay"
            CustomerSection.INSTITUTES_CLASSES -> "Enroll / Book Class"
            else -> "Book Hall Slot"
        }
    }

    fun voiceTypeForSection(section: CustomerSection): String {
        return when (section) {
            CustomerSection.FUNCTION_HALLS -> "VENUE"
            CustomerSection.LODGE_ROOMS -> "HOTEL"
            CustomerSection.PG_HOSTELS -> "PG"
            CustomerSection.INSTITUTES_CLASSES -> "INSTITUTE"
        }
    }

    fun sectionForVoiceType(type: String?): CustomerSection? {
        return when (type?.uppercase()) {
            "VENUE" -> CustomerSection.FUNCTION_HALLS
            "HOTEL" -> CustomerSection.LODGE_ROOMS
            "PG" -> CustomerSection.PG_HOSTELS
            "INSTITUTE", "TURF" -> CustomerSection.INSTITUTES_CLASSES
            else -> null
        }
    }

    private fun matchesVenueCategory(
        venue: Venue,
        section: CustomerSection,
        categoryId: String
    ): Boolean {
        val slug = venue.category?.slug?.lowercase().orEmpty()
        val name = venue.name.lowercase()
        val desc = venue.description.lowercase()
        val pgType = venue.pgDetails?.pgType?.lowercase().orEmpty()
        val occupants = venue.pgDetails?.preferredOccupants?.lowercase().orEmpty()
        val hotelType = venue.hotelDetails?.propertyType?.lowercase().orEmpty()
        val roomTypes = venue.hotelDetails?.roomTypes?.joinToString(" ")?.lowercase().orEmpty()

        return when (section) {
            CustomerSection.FUNCTION_HALLS -> when (categoryId) {
                "marriage_hall" -> slug == "marriage_hall" || name.contains("wedding") || name.contains("marriage")
                "convention_center" -> slug == "convention_center" || name.contains("convention") || name.contains("conference")
                "banquet_hall" -> slug == "banquet_hall" || slug == "party_hall" || name.contains("banquet")
                "community_hall" -> slug == "community_hall" || name.contains("community")
                "govt_hall" -> slug == "govt_hall" || name.contains("government") || name.contains("town hall")
                "party_lawn" -> slug == "party_lawn" || name.contains("lawn")
                else -> slug == categoryId || slug.contains(categoryId)
            }
            CustomerSection.LODGE_ROOMS -> when (categoryId) {
                "hotel" -> slug == "hotel_stay" || hotelType.contains("hotel")
                "lodge" -> slug == "lodge" || name.contains("lodge") || hotelType.contains("lodge")
                "guest_house" -> slug == "guest_house" || name.contains("guest") || hotelType.contains("guest")
                "hourly_room" -> slug == "hourly_room" || venue.hotelDetails?.allowsFlexiStay == true ||
                    roomTypes.contains("flexi") || roomTypes.contains("day") || roomTypes.contains("hour")
                "resort" -> slug == "resort" || slug == "homestay" || name.contains("resort") || name.contains("homestay")
                else -> slug == categoryId || slug.contains(categoryId)
            }
            CustomerSection.PG_HOSTELS -> when (categoryId) {
                "gents_pg" -> pgType.contains("gent") || pgType.contains("men") || occupants.contains("men")
                "ladies_pg" -> pgType.contains("lad") || pgType.contains("women") || occupants.contains("women") || occupants.contains("female")
                "student_hostel" -> name.contains("hostel") || occupants.contains("student") || pgType.contains("hostel")
                "co_living" -> pgType.contains("co-living") || pgType.contains("coliving") || slug.contains("co_living")
                "single_room" -> venue.pgDetails?.sharingOptions?.any {
                    it.typeName.contains("single", ignoreCase = true)
                } == true
                else -> slug == categoryId || slug.contains(categoryId)
            }
            CustomerSection.INSTITUTES_CLASSES -> {
                val haystack = "$slug $name $desc"
                categoryTokens(section, categoryId).any { haystack.contains(it) }
            }
        }
    }

    private fun categoryTokens(section: CustomerSection, categoryId: String): List<String> {
        return when (section to categoryId) {
            CustomerSection.INSTITUTES_CLASSES to "coaching" -> listOf("coaching", "tuition", "academic", "school")
            CustomerSection.INSTITUTES_CLASSES to "computer_it" -> listOf("computer", "coding", "python", "stem", "robot", "tech")
            CustomerSection.INSTITUTES_CLASSES to "dance_academy" -> listOf("dance", "zumba")
            CustomerSection.INSTITUTES_CLASSES to "music_class" -> listOf("music", "guitar", "vocal", "piano", "singing")
            CustomerSection.INSTITUTES_CLASSES to "sports_academy" -> listOf("sport", "badminton", "cricket", "turf", "fitness", "football")
            else -> listOf(categoryId.replace('_', ' '))
        }
    }
}

data class AmenityFilterSpec(
    val id: String,
    val label: String,
    val emoji: String,
    val keywords: List<String>
)
