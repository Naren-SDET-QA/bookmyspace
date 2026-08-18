package com.bookmyspace.bookmyspace.data.model

/**
 * Types of configurable fields supported across all BookMySpace listing types.
 */
enum class ConfigurableFieldType(val displayName: String) {
    TEXT("Text"),
    NUMBER("Number"),
    DROPDOWN("Dropdown"),
    MULTI_SELECT("Multi-Select"),
    CHECKBOX("Checkbox / Toggle"),
    DATE("Date"),
    TIME("Time"),
    IMAGE("Image / Photo URL"),
    URL("Web / Social Link")
}

/**
 * Target listing category to which a configurable field definition applies.
 */
enum class ListingTargetCategory(val code: String, val displayName: String) {
    ALL("all", "All Listing Types"),
    VENUE("venue", "Venues & Spaces"),
    FUNCTION_HALL("function_hall", "Function Halls & Banquets"),
    ROOM("room", "Rooms & Workspaces"),
    PG_HOSTEL("pg_hostel", "PG & Hostels"),
    INSTITUTE("institute", "Institutes & Academies"),
    CLASS("class", "Classes & Batches"),
    COURSE("course", "Courses & Workshops");

    companion object {
        fun fromCode(code: String): ListingTargetCategory {
            return entries.find { it.code.equals(code, ignoreCase = true) } ?: ALL
        }
    }
}

/**
 * Centralized dynamic field definition configured by Admin or authorized owners.
 */
data class ConfigurableFieldDefinition(
    val id: String,
    val name: String, // Internal unique key (e.g., "room_type", "food_available", "capacity")
    val label: String, // Display label (e.g., "Room Type", "Food Available", "Hall Capacity")
    val fieldType: ConfigurableFieldType,
    val required: Boolean = false,
    val defaultValue: String = "",
    val options: List<String> = emptyList(), // For DROPDOWN and MULTI_SELECT
    val placeholder: String = "", // Help text or placeholder
    val displayOrder: Int = 0,
    val isActive: Boolean = true,
    val targetCategory: ListingTargetCategory = ListingTargetCategory.ALL,
    val createdBy: String = "admin",
    val createdAt: Long = System.currentTimeMillis()
)

/**
 * Persisted custom field value for a specific listing entity.
 */
data class ListingCustomFieldValue(
    val listingId: String,
    val fieldId: String,
    val fieldName: String,
    val value: String
)
