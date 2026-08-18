package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.theme.ThemeMode
import com.bookmyspace.bookmyspace.ui.theme.ThemePreset
import com.bookmyspace.bookmyspace.ui.theme.parseHexToColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemeCustomizerScreen(
    onNavigateBack: () -> Unit
) {
    val themeMode by BookMySpaceRepository.themeMode.collectAsState()
    val selectedThemePreset by BookMySpaceRepository.selectedThemePreset.collectAsState()
    val customPrimaryColorHex by BookMySpaceRepository.customPrimaryColorHex.collectAsState()

    var customHexInput by remember(customPrimaryColorHex) { mutableStateOf(customPrimaryColorHex) }
    var hexError by remember { mutableStateOf(false) }

    val quickPaletteSwatches = remember {
        listOf(
            "#673AB7", // Royal Purple
            "#00C9A7", // Electric Teal
            "#2563EB", // Sapphire Navy
            "#059669", // Emerald Green
            "#E11D48", // Crimson Red
            "#F59E0B", // Sunset Amber
            "#0284C7", // Ocean Blue
            "#DB2777", // Rose Gold
            "#8B5CF6", // Cyber Violet
            "#166534", // Forest Green
            "#475569", // Nordic Slate
            "#FF6B4A"  // Coral Saffron
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Theme & Color Engine",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                        Text(
                            text = "Dynamic Color Schemes & Accessibility",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("theme_customizer_back_button")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            BookMySpaceRepository.setThemePreset(ThemePreset.ROYAL_PURPLE)
                            BookMySpaceRepository.setThemeMode(ThemeMode.SYSTEM_DEFAULT)
                        }
                    ) {
                        Text("Reset Brand")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item { Spacer(modifier = Modifier.height(4.dp)) }

            // 1. Live Interactive Preview Card
            item {
                Text(
                    text = "LIVE INTERACTIVE PREVIEW",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.5.sp,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.height(6.dp))
                LiveThemePreviewCard()
            }

            // 2. Light / Dark / System Mode Selector
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(16.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        1.dp,
                        MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.BrightnessAuto,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = "Appearance Mode",
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                        SingleChoiceSegmentedButtonRow(
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("appearance_mode_segmented_row")
                        ) {
                            SegmentedButton(
                                selected = themeMode == ThemeMode.SYSTEM_DEFAULT,
                                onClick = { BookMySpaceRepository.setThemeMode(ThemeMode.SYSTEM_DEFAULT) },
                                shape = SegmentedButtonDefaults.itemShape(index = 0, count = 3),
                                icon = { Icon(Icons.Default.BrightnessAuto, contentDescription = null, modifier = Modifier.size(14.dp)) }
                            ) {
                                Text("System", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            }
                            SegmentedButton(
                                selected = themeMode == ThemeMode.LIGHT,
                                onClick = { BookMySpaceRepository.setThemeMode(ThemeMode.LIGHT) },
                                shape = SegmentedButtonDefaults.itemShape(index = 1, count = 3),
                                icon = { Icon(Icons.Default.LightMode, contentDescription = null, modifier = Modifier.size(14.dp)) }
                            ) {
                                Text("Light", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            }
                            SegmentedButton(
                                selected = themeMode == ThemeMode.DARK,
                                onClick = { BookMySpaceRepository.setThemeMode(ThemeMode.DARK) },
                                shape = SegmentedButtonDefaults.itemShape(index = 2, count = 3),
                                icon = { Icon(Icons.Default.DarkMode, contentDescription = null, modifier = Modifier.size(14.dp)) }
                            ) {
                                Text("Dark", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }

            // 3. Custom Primary Accent Selector
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(16.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        1.dp,
                        MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                    )
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.ColorLens,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(18.dp)
                                )
                                Text(
                                    text = "Custom Primary Accent",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp
                                )
                            }

                            if (selectedThemePreset == ThemePreset.CUSTOM) {
                                Surface(
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                    shape = RoundedCornerShape(8.dp)
                                ) {
                                    Text(
                                        text = "ACTIVE",
                                        fontSize = 9.5.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "Tap a seed swatch or enter a custom hex code. Material 3 accessible contrast tokens will be dynamically synthesized:",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        // Quick Swatches Row
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(quickPaletteSwatches) { hex ->
                                val swatchColor = parseHexToColor(hex) ?: Color.Gray
                                val isSelected = selectedThemePreset == ThemePreset.CUSTOM &&
                                        customPrimaryColorHex.equals(hex, ignoreCase = true)

                                Box(
                                    modifier = Modifier
                                        .size(38.dp)
                                        .clip(CircleShape)
                                        .background(swatchColor)
                                        .border(
                                            width = if (isSelected) 3.dp else 1.dp,
                                            color = if (isSelected) MaterialTheme.colorScheme.onSurface else Color.Transparent,
                                            shape = CircleShape
                                        )
                                        .clickable {
                                            customHexInput = hex
                                            hexError = false
                                            BookMySpaceRepository.setCustomPrimaryColor(hex)
                                        },
                                    contentAlignment = Alignment.Center
                                ) {
                                    if (isSelected) {
                                        Icon(
                                            imageVector = Icons.Default.Check,
                                            contentDescription = null,
                                            tint = Color.White,
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        // Hex Code Input Field
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            val parsedColor = parseHexToColor(customHexInput)
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(parsedColor ?: MaterialTheme.colorScheme.primary)
                                    .border(1.dp, MaterialTheme.colorScheme.outline, CircleShape)
                            )

                            OutlinedTextField(
                                value = customHexInput,
                                onValueChange = { input ->
                                    customHexInput = input
                                    val valid = parseHexToColor(input) != null
                                    hexError = !valid
                                    if (valid) {
                                        BookMySpaceRepository.setCustomPrimaryColor(input)
                                    }
                                },
                                label = { Text("Custom Hex Code (#RRGGBB)", fontSize = 11.sp) },
                                isError = hexError,
                                singleLine = true,
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("custom_hex_text_field"),
                                shape = RoundedCornerShape(12.dp)
                            )

                            Button(
                                onClick = {
                                    val color = parseHexToColor(customHexInput)
                                    if (color != null) {
                                        BookMySpaceRepository.setCustomPrimaryColor(customHexInput)
                                        hexError = false
                                    } else {
                                        hexError = true
                                    }
                                },
                                shape = RoundedCornerShape(12.dp),
                                enabled = parseHexToColor(customHexInput) != null
                            ) {
                                Text("Apply", fontSize = 12.sp)
                            }
                        }

                        if (hexError) {
                            Text(
                                text = "Please enter a valid 6-character hex code (e.g. #673AB7)",
                                color = MaterialTheme.colorScheme.error,
                                fontSize = 10.sp,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                        }
                    }
                }
            }

            // 4. Curated Theme Presets Gallery (12 Themes)
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "12 CURATED THEME PRESETS",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 0.5.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Surface(
                        color = MaterialTheme.colorScheme.secondaryContainer,
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "${ThemePreset.values().size - 1} Ready Presets",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            items(ThemePreset.values().filter { it != ThemePreset.CUSTOM }) { preset ->
                ThemePresetItemCard(
                    preset = preset,
                    isSelected = selectedThemePreset == preset,
                    onSelect = { BookMySpaceRepository.setThemePreset(preset) }
                )
            }

            item { Spacer(modifier = Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun ThemePresetItemCard(
    preset: ThemePreset,
    isSelected: Boolean,
    onSelect: () -> Unit
) {
    val borderColor by animateColorAsState(
        targetValue = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
        label = "borderColor"
    )

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect() }
            .testTag("theme_preset_${preset.id}"),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.25f) else MaterialTheme.colorScheme.surface
        ),
        shape = RoundedCornerShape(16.dp),
        border = androidx.compose.foundation.BorderStroke(if (isSelected) 2.dp else 1.dp, borderColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.weight(1f)
            ) {
                // Color Palette Circles
                Row(horizontalArrangement = Arrangement.spacedBy((-6).dp)) {
                    preset.previewColors.forEach { color ->
                        Box(
                            modifier = Modifier
                                .size(22.dp)
                                .clip(CircleShape)
                                .background(color)
                                .border(1.5.dp, Color.White, CircleShape)
                        )
                    }
                }

                Column {
                    Text(
                        text = preset.displayName,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.5.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = preset.description,
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2
                    )
                }
            }

            RadioButton(
                selected = isSelected,
                onClick = onSelect,
                colors = RadioButtonDefaults.colors(
                    selectedColor = MaterialTheme.colorScheme.primary
                )
            )
        }
    }
}

@Composable
private fun LiveThemePreviewCard() {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("live_theme_preview_card"),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 3.dp),
        shape = RoundedCornerShape(16.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Top Badge Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Verified,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(12.dp)
                        )
                        Text(
                            text = "PREVIEW BANQUET HALL",
                            fontSize = 9.5.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                Surface(
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = "★ 4.9 (120 reviews)",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            Text(
                text = "The Royal Sapphire Convention Centre",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.padding(top = 2.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(12.dp)
                )
                Text(
                    text = "Banjara Hills, Hyderabad • Capacity: 800 Guests",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Amenity Chips Preview
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("Air Conditioned", "High-speed WiFi", "Valet Parking").forEach { tag ->
                    Surface(
                        color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.6f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = tag,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(10.dp))

            // Price & Primary CTA Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Slot Starting Rate",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = "₹25,000",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = " + 18% GST",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    OutlinedButton(
                        onClick = {},
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Text("Enquire", fontSize = 11.sp)
                    }

                    Button(
                        onClick = {},
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text("Book Now", fontSize = 11.sp)
                    }
                }
            }
        }
    }
}
