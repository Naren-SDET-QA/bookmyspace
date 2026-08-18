package com.bookmyspace.bookmyspace.data.model

/**
 * Standard identifier for major customizable app sections controlled by Admin.
 */
enum class AppSectionKey(
    val id: String,
    val title: String,
    val subtitle: String,
    val emoji: String,
    val iconName: String,
    val defaultEnabled: Boolean,
    val subCategories: List<String>,
    val quickOptions: List<String>
) {
    FUNCTION_HALLS_VENUES(
        id = "venues_function_halls",
        title = "Function Halls & Venues",
        subtitle = "Function halls, marriage halls, banquet spaces & lawns",
        emoji = "🏛️",
        iconName = "celebration",
        defaultEnabled = true,
        subCategories = listOf("function_hall", "banquet_hall", "marriage_hall", "party_lawn", "convention_center", "venue"),
        quickOptions = listOf("Function Hall", "Banquet Hall", "Wedding Venue", "Convention Center", "Party Lawn")
    ),
    HOTELS_ROOMS(
        id = "hotels_rooms",
        title = "Hotels & Rooms",
        subtitle = "Hotel stays, luxury suites & day-use rooms",
        emoji = "🏨",
        iconName = "hotel",
        defaultEnabled = true,
        subCategories = listOf("hotel_stay", "hotel", "room"),
        quickOptions = listOf("Hotel", "Rooms", "Deluxe Suite", "Flexi Day Stay")
    ),
    PG_HOSTELS(
        id = "pg_hostels",
        title = "PG & Hostels",
        subtitle = "Student & working professional co-living accommodations",
        emoji = "🏡",
        iconName = "house",
        defaultEnabled = true,
        subCategories = listOf("pg_hostel", "hostel", "co_living"),
        quickOptions = listOf("Men's PG", "Women's PG", "Co-Living", "Single Room", "Sharing PG")
    ),
    INSTITUTES_CLASSES(
        id = "institutes_classes",
        title = "Institutes & Classes",
        subtitle = "Coaching academies, dance studios & tuition centers",
        emoji = "🎓",
        iconName = "school",
        defaultEnabled = true,
        subCategories = listOf("institute", "class", "coaching"),
        quickOptions = listOf("Institute", "Classes", "Coaching", "Dance Studio", "Tuition Center")
    ),
    COURSES(
        id = "courses",
        title = "Courses & Training",
        subtitle = "Certifications, skill bootcamps & masterclasses",
        emoji = "📚",
        iconName = "menu_book",
        defaultEnabled = true,
        subCategories = listOf("course", "training", "workshop"),
        quickOptions = listOf("Crash Courses", "Online Bootcamps", "Weekend Workshops", "Certifications")
    ),
    EVENTS(
        id = "events",
        title = "Events & Workshops",
        subtitle = "Concerts, cultural gatherings, tech workshops & seminars",
        emoji = "🎟️",
        iconName = "event",
        defaultEnabled = true,
        subCategories = listOf("event", "seminar", "concert"),
        quickOptions = listOf("Live Concerts", "Seminars", "Cultural Fest", "Workshops")
    ),
    COWORKING_OTHER(
        id = "coworking_other",
        title = "Coworking & Workspaces",
        subtitle = "Hot desks, conference rooms & meeting spaces",
        emoji = "💼",
        iconName = "work",
        defaultEnabled = true,
        subCategories = listOf("meeting_room", "conference_room", "coworking", "badminton"),
        quickOptions = listOf("Meeting Room", "Conference Hall", "Hot Desk", "Sports Turf")
    );

    companion object {
        fun fromId(id: String): AppSectionKey? {
            return entries.find { it.id.equals(id, ignoreCase = true) }
        }
    }
}

/**
 * Data model for dynamically configured app sections stored in database & local preferences.
 */
data class AppSectionConfig(
    val sectionId: String,
    val title: String,
    val subtitle: String,
    val emoji: String,
    val iconName: String,
    val isEnabled: Boolean = true,
    val displayOrder: Int = 0,
    val subCategories: List<String> = emptyList(),
    val quickOptions: List<String> = emptyList()
) {
    companion object {
        fun defaultList(): List<AppSectionConfig> {
            return AppSectionKey.entries.mapIndexed { index, key ->
                AppSectionConfig(
                    sectionId = key.id,
                    title = key.title,
                    subtitle = key.subtitle,
                    emoji = key.emoji,
                    iconName = key.iconName,
                    isEnabled = key.defaultEnabled,
                    displayOrder = index,
                    subCategories = key.subCategories,
                    quickOptions = key.quickOptions
                )
            }
        }
    }
}
