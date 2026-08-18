package com.bookmyspace.bookmyspace.ui.theme

import androidx.compose.ui.graphics.Color

enum class ThemePreset(
    val id: String,
    val displayName: String,
    val description: String,
    val primaryLight: Color,
    val primaryDark: Color,
    val seedHex: String,
    val previewColors: List<Color>
) {
    ROYAL_PURPLE(
        id = "royal_purple",
        displayName = "Royal Purple (Brand Classic)",
        description = "Majestic regal purple with vibrant violet highlights.",
        primaryLight = Color(0xFF4F46E5),
        primaryDark = Color(0xFF818CF8),
        seedHex = "#4F46E5",
        previewColors = listOf(Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFFEEEDFE))
    ),
    ELECTRIC_TEAL(
        id = "electric_teal",
        displayName = "Electric Teal (BookMySpace Modern)",
        description = "Sleek minty teal paired with deep navy contrast.",
        primaryLight = Color(0xFF00897B),
        primaryDark = Color(0xFF00C9A7),
        seedHex = "#00C9A7",
        previewColors = listOf(Color(0xFF00C9A7), Color(0xFF00897B), Color(0xFFCCF7F0))
    ),
    MIDNIGHT_NAVY(
        id = "midnight_navy",
        displayName = "Midnight Navy & Sapphire",
        description = "High-contrast sapphire blue with deep space navy background.",
        primaryLight = Color(0xFF1D4ED8),
        primaryDark = Color(0xFF3B82F6),
        seedHex = "#2563EB",
        previewColors = listOf(Color(0xFF2563EB), Color(0xFF1E3A8A), Color(0xFFDBEAFE))
    ),
    EMERALD_LUXURY(
        id = "emerald_luxury",
        displayName = "Emerald Garden & Estate",
        description = "Sophisticated emerald green for grand banquet halls and lawns.",
        primaryLight = Color(0xFF047857),
        primaryDark = Color(0xFF10B981),
        seedHex = "#059669",
        previewColors = listOf(Color(0xFF059669), Color(0xFF065F46), Color(0xFFD1FAE5))
    ),
    CRIMSON_PASSION(
        id = "crimson_passion",
        displayName = "Crimson Passion & Ruby",
        description = "Vibrant ruby red designed for night celebrations and galas.",
        primaryLight = Color(0xFFBE123C),
        primaryDark = Color(0xFFF43F5E),
        seedHex = "#E11D48",
        previewColors = listOf(Color(0xFFE11D48), Color(0xFF881337), Color(0xFFFFE4E6))
    ),
    SUNSET_AMBER(
        id = "sunset_amber",
        displayName = "Sunset Amber & Saffron",
        description = "Warm saffron gold tones inspired by festive occasions.",
        primaryLight = Color(0xFFD97706),
        primaryDark = Color(0xFFF59E0B),
        seedHex = "#F59E0B",
        previewColors = listOf(Color(0xFFF59E0B), Color(0xFF78350F), Color(0xFFFEF3C7))
    ),
    SAPPHIRE_RESORT(
        id = "sapphire_resort",
        displayName = "Sapphire Resort & Ocean",
        description = "Refreshing ocean blue tailored for luxury resort stays.",
        primaryLight = Color(0xFF0369A1),
        primaryDark = Color(0xFF38BDF8),
        seedHex = "#0284C7",
        previewColors = listOf(Color(0xFF0284C7), Color(0xFF0C4A6E), Color(0xFFE0F2FE))
    ),
    ROSE_GOLD(
        id = "rose_gold",
        displayName = "Rose Gold & Blush",
        description = "Chic magenta pink and warm rose gold aesthetics.",
        primaryLight = Color(0xFFBE185D),
        primaryDark = Color(0xFFF472B6),
        seedHex = "#DB2777",
        previewColors = listOf(Color(0xFFDB2777), Color(0xFF831843), Color(0xFFFCE7F3))
    ),
    CYBER_NEON(
        id = "cyber_neon",
        displayName = "Cyber Neon Violet",
        description = "Futuristic deep violet with neon cyan accents.",
        primaryLight = Color(0xFF7C3AED),
        primaryDark = Color(0xFFA78BFA),
        seedHex = "#8B5CF6",
        previewColors = listOf(Color(0xFF8B5CF6), Color(0xFF4C1D95), Color(0xFFEDE9FE))
    ),
    FOREST_CANOPY(
        id = "forest_canopy",
        displayName = "Forest Canopy & Eco",
        description = "Natural deep forest green with vibrant leaf accents.",
        primaryLight = Color(0xFF15803D),
        primaryDark = Color(0xFF4ADE80),
        seedHex = "#166534",
        previewColors = listOf(Color(0xFF166534), Color(0xFF14532D), Color(0xFFDCFCE7))
    ),
    NORDIC_SLATE(
        id = "nordic_slate",
        displayName = "Nordic Slate Minimalist",
        description = "Subtle, professional slate grey and steel blue.",
        primaryLight = Color(0xFF334155),
        primaryDark = Color(0xFF94A3B8),
        seedHex = "#475569",
        previewColors = listOf(Color(0xFF475569), Color(0xFF0F172A), Color(0xFFE2E8F0))
    ),
    CUSTOM(
        id = "custom",
        displayName = "Custom Primary Accent",
        description = "Choose any custom primary seed color with auto-generated accessibility tokens.",
        primaryLight = Color(0xFF673AB7),
        primaryDark = Color(0xFF9575CD),
        seedHex = "#673AB7",
        previewColors = listOf(Color(0xFF673AB7), Color(0xFF00C9A7), Color(0xFFFF6B4A))
    );

    companion object {
        fun fromId(id: String): ThemePreset = values().find { it.id == id } ?: ROYAL_PURPLE
    }
}
