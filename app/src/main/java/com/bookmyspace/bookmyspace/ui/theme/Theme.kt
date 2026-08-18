package com.bookmyspace.bookmyspace.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import kotlin.math.abs
import kotlin.math.pow

enum class ThemeMode {
    SYSTEM_DEFAULT,
    LIGHT,
    DARK
}

val LocalThemePreset = staticCompositionLocalOf { ThemePreset.ROYAL_PURPLE }

fun parseHexToColor(hex: String): Color? {
    return try {
        val cleanHex = hex.trim().removePrefix("#")
        val colorInt = when (cleanHex.length) {
            6 -> (0xFF000000 or cleanHex.toLong(16)).toInt()
            8 -> cleanHex.toLong(16).toInt()
            else -> return null
        }
        Color(colorInt)
    } catch (e: Exception) {
        null
    }
}

fun Color.toHsl(): FloatArray {
    val r = red
    val g = green
    val b = blue
    val max = maxOf(r, maxOf(g, b))
    val min = minOf(r, minOf(g, b))
    var h = 0f
    var s = 0f
    val l = (max + min) / 2f

    if (max != min) {
        val d = max - min
        s = if (l > 0.5f) d / (2f - max - min) else d / (max + min)
        h = when (max) {
            r -> (g - b) / d + (if (g < b) 6f else 0f)
            g -> (b - r) / d + 2f
            else -> (r - g) / d + 4f
        }
        h /= 6f
    }
    return floatArrayOf(h * 360f, s, l)
}

fun hslToColor(h: Float, s: Float, l: Float, alpha: Float = 1f): Color {
    val normalizedH = ((h % 360f) + 360f) % 360f
    val c = (1f - abs(2f * l - 1f)) * s
    val x = c * (1f - abs((normalizedH / 60f) % 2f - 1f))
    val m = l - c / 2f

    val (r1, g1, b1) = when {
        normalizedH < 60f -> Triple(c, x, 0f)
        normalizedH < 120f -> Triple(x, c, 0f)
        normalizedH < 180f -> Triple(0f, c, x)
        normalizedH < 240f -> Triple(0f, x, c)
        normalizedH < 300f -> Triple(x, 0f, c)
        else -> Triple(c, 0f, x)
    }

    return Color(
        red = (r1 + m).coerceIn(0f, 1f),
        green = (g1 + m).coerceIn(0f, 1f),
        blue = (b1 + m).coerceIn(0f, 1f),
        alpha = alpha
    )
}

fun Color.calculateLuminance(): Float {
    fun sRGB(v: Float) = if (v <= 0.03928f) v / 12.92f else ((v + 0.055f) / 1.055f).pow(2.4f)
    return 0.2126f * sRGB(red) + 0.7152f * sRGB(green) + 0.0722f * sRGB(blue)
}

fun generateBookMySpaceColorScheme(seedColor: Color, isDark: Boolean): ColorScheme {
    val hsl = seedColor.toHsl()
    val hue = hsl[0]
    val sat = hsl[1].coerceIn(0.20f, 0.95f)

    return if (!isDark) {
        // Light Mode Dynamic Accessibility Tokens
        val primaryLight = hslToColor(hue, sat, 0.38f) // Ensure high contrast on white/light bg
        val onPrimary = if (primaryLight.calculateLuminance() > 0.45f) Color(0xFF0F172A) else Color.White
        val primaryContainer = hslToColor(hue, sat * 0.35f, 0.92f)
        val onPrimaryContainer = hslToColor(hue, sat * 0.90f, 0.18f)

        val secHue = (hue + 30f) % 360f
        val secondary = hslToColor(secHue, sat * 0.65f, 0.42f)
        val onSecondary = Color.White
        val secondaryContainer = hslToColor(secHue, sat * 0.30f, 0.91f)
        val onSecondaryContainer = hslToColor(secHue, sat * 0.85f, 0.20f)

        val tertHue = (hue + 140f) % 360f
        val tertiary = hslToColor(tertHue, sat * 0.75f, 0.42f)
        val onTertiary = Color.White
        val tertiaryContainer = hslToColor(tertHue, sat * 0.30f, 0.92f)
        val onTertiaryContainer = hslToColor(tertHue, sat * 0.85f, 0.18f)

        lightColorScheme(
            primary = primaryLight,
            onPrimary = onPrimary,
            primaryContainer = primaryContainer,
            onPrimaryContainer = onPrimaryContainer,
            secondary = secondary,
            onSecondary = onSecondary,
            secondaryContainer = secondaryContainer,
            onSecondaryContainer = onSecondaryContainer,
            tertiary = tertiary,
            onTertiary = onTertiary,
            tertiaryContainer = tertiaryContainer,
            onTertiaryContainer = onTertiaryContainer,
            background = Color(0xFFF8FAFC),
            onBackground = Color(0xFF0F172A),
            surface = Color(0xFFFFFFFF),
            onSurface = Color(0xFF0F172A),
            surfaceVariant = Color(0xFFF1F5F9),
            onSurfaceVariant = Color(0xFF334155),
            outline = Color(0xFFCBD5E1),
            outlineVariant = Color(0xFFE2E8F0),
            error = Color(0xFFDC2626),
            onError = Color.White,
            errorContainer = Color(0xFFFEE2E2),
            onErrorContainer = Color(0xFF991B1B)
        )
    } else {
        // Dark Mode Dynamic Accessibility Tokens
        val primaryDark = hslToColor(hue, sat * 0.85f, 0.62f) // Vibrant pop on dark bg
        val onPrimary = Color(0xFF08101D)
        val primaryContainer = hslToColor(hue, sat * 0.60f, 0.22f)
        val onPrimaryContainer = hslToColor(hue, sat * 0.50f, 0.88f)

        val secHue = (hue + 30f) % 360f
        val secondary = hslToColor(secHue, sat * 0.75f, 0.60f)
        val onSecondary = Color(0xFF08101D)
        val secondaryContainer = hslToColor(secHue, sat * 0.55f, 0.20f)
        val onSecondaryContainer = hslToColor(secHue, sat * 0.50f, 0.88f)

        val tertHue = (hue + 140f) % 360f
        val tertiary = hslToColor(tertHue, sat * 0.80f, 0.65f)
        val onTertiary = Color(0xFF08101D)
        val tertiaryContainer = hslToColor(tertHue, sat * 0.55f, 0.20f)
        val onTertiaryContainer = hslToColor(tertHue, sat * 0.50f, 0.88f)

        darkColorScheme(
            primary = primaryDark,
            onPrimary = onPrimary,
            primaryContainer = primaryContainer,
            onPrimaryContainer = onPrimaryContainer,
            secondary = secondary,
            onSecondary = onSecondary,
            secondaryContainer = secondaryContainer,
            onSecondaryContainer = onSecondaryContainer,
            tertiary = tertiary,
            onTertiary = onTertiary,
            tertiaryContainer = tertiaryContainer,
            onTertiaryContainer = onTertiaryContainer,
            background = Color(0xFF08111D),
            onBackground = Color(0xFFF8FAFC),
            surface = Color(0xFF101B2B),
            onSurface = Color(0xFFF8FAFC),
            surfaceVariant = Color(0xFF19273C),
            onSurfaceVariant = Color(0xFFCBD5E1),
            outline = Color(0xFF475569),
            outlineVariant = Color(0xFF334155),
            error = Color(0xFFEF4444),
            onError = Color.White,
            errorContainer = Color(0xFF7F1D1D),
            onErrorContainer = Color(0xFFFEE2E2)
        )
    }
}

@Composable
fun BookMySpaceTheme(
    themeMode: ThemeMode = ThemeMode.SYSTEM_DEFAULT,
    themePreset: ThemePreset = ThemePreset.ROYAL_PURPLE,
    customPrimaryHex: String = "#673AB7",
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val isDark = when (themeMode) {
        ThemeMode.SYSTEM_DEFAULT -> darkTheme
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

    val seedColor = if (themePreset == ThemePreset.CUSTOM) {
        parseHexToColor(customPrimaryHex) ?: themePreset.primaryLight
    } else {
        if (isDark) themePreset.primaryDark else themePreset.primaryLight
    }

    val colorScheme = generateBookMySpaceColorScheme(seedColor, isDark)

    CompositionLocalProvider(LocalThemePreset provides themePreset) {
        MaterialTheme(
            colorScheme = colorScheme,
            content = content
        )
    }
}
