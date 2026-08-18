package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.ConfigurableFieldDefinition
import com.bookmyspace.bookmyspace.data.model.ConfigurableFieldType
import com.bookmyspace.bookmyspace.data.model.ListingTargetCategory
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

/**
 * Dynamically renders configurable input fields based on category definitions.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun DynamicConfigurableFieldsForm(
    targetCategory: ListingTargetCategory,
    values: Map<String, String>,
    onValuesChange: (Map<String, String>) -> Unit,
    modifier: Modifier = Modifier,
    isOwner: Boolean = false
) {
    val allFields by BookMySpaceRepository.configurableFields.collectAsState()
    val fields = remember(allFields, targetCategory) {
        BookMySpaceRepository.getConfigurableFieldsForCategory(targetCategory, activeOnly = true)
    }

    if (fields.isEmpty()) {
        return
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Surface(
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Tune,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(10.dp))
                Column {
                    Text(
                        text = "Configurable Attributes (${targetCategory.displayName})",
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "Dynamic fields configured by administrators for ${targetCategory.displayName}",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        fields.forEach { field ->
            val currentValue = values[field.name] ?: field.defaultValue

            when (field.fieldType) {
                ConfigurableFieldType.TEXT -> {
                    OutlinedTextField(
                        value = currentValue,
                        onValueChange = { newValue ->
                            onValuesChange(values + (field.name to newValue))
                        },
                        label = {
                            Text(field.label + if (field.required) " *" else "")
                        },
                        placeholder = { Text(field.placeholder.ifBlank { "Enter ${field.label}" }) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("dynamic_field_${field.name}"),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                }

                ConfigurableFieldType.NUMBER -> {
                    OutlinedTextField(
                        value = currentValue,
                        onValueChange = { newValue ->
                            val cleanNumber = newValue.filter { it.isDigit() || it == '.' }
                            onValuesChange(values + (field.name to cleanNumber))
                        },
                        label = {
                            Text(field.label + if (field.required) " *" else "")
                        },
                        placeholder = { Text(field.placeholder.ifBlank { "Enter number" }) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("dynamic_field_${field.name}"),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                }

                ConfigurableFieldType.DROPDOWN -> {
                    var expanded by remember { mutableStateOf(false) }
                    ExposedDropdownMenuBox(
                        expanded = expanded,
                        onExpandedChange = { expanded = it },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedTextField(
                            value = currentValue.ifBlank { field.defaultValue },
                            onValueChange = {},
                            readOnly = true,
                            label = { Text(field.label + if (field.required) " *" else "") },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                            modifier = Modifier
                                .menuAnchor()
                                .fillMaxWidth()
                                .testTag("dynamic_field_${field.name}"),
                            shape = RoundedCornerShape(12.dp)
                        )
                        ExposedDropdownMenu(
                            expanded = expanded,
                            onDismissRequest = { expanded = false }
                        ) {
                            field.options.forEach { option ->
                                DropdownMenuItem(
                                    text = { Text(option) },
                                    onClick = {
                                        onValuesChange(values + (field.name to option))
                                        expanded = false
                                    }
                                )
                            }
                        }
                    }
                }

                ConfigurableFieldType.MULTI_SELECT -> {
                    val selectedOptions = remember(currentValue) {
                        if (currentValue.isBlank()) emptyList() else currentValue.split(",").map { it.trim() }
                    }

                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = field.label + if (field.required) " *" else "",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            field.options.forEach { option ->
                                val isSelected = selectedOptions.contains(option)
                                FilterChip(
                                    selected = isSelected,
                                    onClick = {
                                        val newSelected = if (isSelected) {
                                            selectedOptions - option
                                        } else {
                                            selectedOptions + option
                                        }
                                        onValuesChange(values + (field.name to newSelected.joinToString(",")))
                                    },
                                    label = { Text(option, fontSize = 12.sp) },
                                    leadingIcon = if (isSelected) {
                                        { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                                    } else null
                                )
                            }
                        }
                    }
                }

                ConfigurableFieldType.CHECKBOX -> {
                    val isChecked = currentValue.equals("true", ignoreCase = true) || currentValue == "1"
                    Card(
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = field.label + if (field.required) " *" else "",
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 13.sp
                                )
                                if (field.placeholder.isNotBlank()) {
                                    Text(
                                        text = field.placeholder,
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            Switch(
                                checked = isChecked,
                                onCheckedChange = { checked ->
                                    onValuesChange(values + (field.name to checked.toString()))
                                },
                                modifier = Modifier.testTag("dynamic_switch_${field.name}")
                            )
                        }
                    }
                }

                ConfigurableFieldType.DATE -> {
                    OutlinedTextField(
                        value = currentValue,
                        onValueChange = { newValue ->
                            onValuesChange(values + (field.name to newValue))
                        },
                        label = { Text(field.label + if (field.required) " *" else "") },
                        placeholder = { Text(field.placeholder.ifBlank { "YYYY-MM-DD" }) },
                        leadingIcon = { Icon(Icons.Default.CalendarToday, contentDescription = null) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("dynamic_field_${field.name}"),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                }

                ConfigurableFieldType.TIME -> {
                    OutlinedTextField(
                        value = currentValue,
                        onValueChange = { newValue ->
                            onValuesChange(values + (field.name to newValue))
                        },
                        label = { Text(field.label + if (field.required) " *" else "") },
                        placeholder = { Text(field.placeholder.ifBlank { "e.g. 10:00 AM - 06:00 PM" }) },
                        leadingIcon = { Icon(Icons.Default.Schedule, contentDescription = null) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("dynamic_field_${field.name}"),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                }

                ConfigurableFieldType.IMAGE -> {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        OutlinedTextField(
                            value = currentValue,
                            onValueChange = { newValue ->
                                onValuesChange(values + (field.name to newValue))
                            },
                            label = { Text(field.label + if (field.required) " *" else "") },
                            placeholder = { Text(field.placeholder.ifBlank { "https://..." }) },
                            leadingIcon = { Icon(Icons.Default.Image, contentDescription = null) },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("dynamic_field_${field.name}"),
                            shape = RoundedCornerShape(12.dp),
                            singleLine = true
                        )
                        if (currentValue.isNotBlank()) {
                            Spacer(modifier = Modifier.height(6.dp))
                            Card(
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(100.dp)
                            ) {
                                AsyncImage(
                                    model = currentValue,
                                    contentDescription = field.label,
                                    modifier = Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Crop
                                )
                            }
                        }
                    }
                }

                ConfigurableFieldType.URL -> {
                    OutlinedTextField(
                        value = currentValue,
                        onValueChange = { newValue ->
                            onValuesChange(values + (field.name to newValue))
                        },
                        label = { Text(field.label + if (field.required) " *" else "") },
                        placeholder = { Text(field.placeholder.ifBlank { "https://..." }) },
                        leadingIcon = { Icon(Icons.Default.Link, contentDescription = null) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("dynamic_field_${field.name}"),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                }
            }
        }
    }
}

/**
 * Dynamically displays configurable field values on public listing detail screens.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DynamicListingFieldsDisplay(
    targetCategory: ListingTargetCategory,
    values: Map<String, String>,
    modifier: Modifier = Modifier
) {
    val allFields by BookMySpaceRepository.configurableFields.collectAsState()
    val fields = remember(allFields, targetCategory) {
        BookMySpaceRepository.getConfigurableFieldsForCategory(targetCategory, activeOnly = true)
    }

    val activePopulatedFields = fields.filter { field ->
        val v = values[field.name] ?: field.defaultValue
        v.isNotBlank() && v != "false"
    }

    if (activePopulatedFields.isEmpty()) return

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
        modifier = modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Checklist,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Facility & Property Specifications",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer,
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = targetCategory.displayName,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                activePopulatedFields.forEach { field ->
                    val rawVal = values[field.name] ?: field.defaultValue
                    val isBool = field.fieldType == ConfigurableFieldType.CHECKBOX || rawVal.equals("true", ignoreCase = true)

                    Surface(
                        color = MaterialTheme.colorScheme.surface,
                        shape = RoundedCornerShape(10.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = if (isBool) Icons.Default.CheckCircle else Icons.Default.Info,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Column {
                                Text(
                                    text = field.label,
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontWeight = FontWeight.Medium
                                )
                                if (!isBool || rawVal != "true") {
                                    Text(
                                        text = rawVal,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
