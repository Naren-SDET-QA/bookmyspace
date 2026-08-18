package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.ConfigurableFieldDefinition
import com.bookmyspace.bookmyspace.data.model.ConfigurableFieldType
import com.bookmyspace.bookmyspace.data.model.ListingTargetCategory
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ListingFieldsConfigScreen(
    onNavigateBack: () -> Unit
) {
    val allFields by BookMySpaceRepository.configurableFields.collectAsState()
    var selectedCategory by remember { mutableStateOf(ListingTargetCategory.ALL) }
    var searchQuery by remember { mutableStateOf("") }
    var showAddEditDialog by remember { mutableStateOf(false) }
    var editingField by remember { mutableStateOf<ConfigurableFieldDefinition?>(null) }
    var showResetDialog by remember { mutableStateOf(false) }
    var snackbarMessage by remember { mutableStateOf<String?>(null) }

    val filteredFields = remember(allFields, selectedCategory, searchQuery) {
        allFields.filter { field ->
            val matchesCategory = selectedCategory == ListingTargetCategory.ALL || field.targetCategory == selectedCategory || field.targetCategory == ListingTargetCategory.ALL
            val matchesQuery = searchQuery.isBlank() ||
                    field.label.contains(searchQuery, ignoreCase = true) ||
                    field.name.contains(searchQuery, ignoreCase = true) ||
                    field.targetCategory.displayName.contains(searchQuery, ignoreCase = true)
            matchesCategory && matchesQuery
        }.sortedBy { it.displayOrder }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Listing Fields Configuration", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text("Centralized dynamic attributes engine", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = { showResetDialog = true },
                        modifier = Modifier.testTag("reset_fields_button")
                    ) {
                        Icon(Icons.Default.RestartAlt, contentDescription = "Reset Defaults")
                    }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = {
                    editingField = null
                    showAddEditDialog = true
                },
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text("Add New Field") },
                modifier = Modifier.testTag("add_configurable_field_fab")
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Category Filter Scrollable Tabs
            ScrollableTabRow(
                selectedTabIndex = ListingTargetCategory.entries.indexOf(selectedCategory),
                edgePadding = 12.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                ListingTargetCategory.entries.forEach { cat ->
                    val isSelected = selectedCategory == cat
                    val count = if (cat == ListingTargetCategory.ALL) allFields.size else allFields.count { it.targetCategory == cat || it.targetCategory == ListingTargetCategory.ALL }
                    Tab(
                        selected = isSelected,
                        onClick = { selectedCategory = cat },
                        text = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(cat.displayName, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                Spacer(modifier = Modifier.width(6.dp))
                                Surface(
                                    color = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                                    shape = CircleShape
                                ) {
                                    Text(
                                        text = "$count",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }
                    )
                }
            }

            // Search Bar & Stats Header
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Search field label, code or category...") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    trailingIcon = if (searchQuery.isNotEmpty()) {
                        {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Default.Clear, contentDescription = "Clear")
                            }
                        }
                    } else null,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("search_fields_input"),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )
            }

            // Fields List
            if (filteredFields.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = Icons.Default.Tune,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f),
                            modifier = Modifier.size(56.dp)
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            text = "No Configurable Fields Found",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Add a dynamic field for ${selectedCategory.displayName} to render without app updates.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = PaddingValues(bottom = 80.dp, top = 4.dp)
                ) {
                    itemsIndexed(filteredFields, key = { _, item -> item.id }) { index, field ->
                        ConfigurableFieldItemCard(
                            field = field,
                            canMoveUp = index > 0,
                            canMoveDown = index < filteredFields.size - 1,
                            onToggleActive = {
                                BookMySpaceRepository.toggleConfigurableFieldActive(field.id)
                                snackbarMessage = if (field.isActive) "Deactivated '${field.label}'" else "Activated '${field.label}'"
                            },
                            onMoveUp = {
                                val currentOrder = filteredFields.map { it.id }.toMutableList()
                                val i = currentOrder.indexOf(field.id)
                                if (i > 0) {
                                    val temp = currentOrder[i]
                                    currentOrder[i] = currentOrder[i - 1]
                                    currentOrder[i - 1] = temp
                                    BookMySpaceRepository.reorderConfigurableFields(currentOrder)
                                }
                            },
                            onMoveDown = {
                                val currentOrder = filteredFields.map { it.id }.toMutableList()
                                val i = currentOrder.indexOf(field.id)
                                if (i < currentOrder.size - 1) {
                                    val temp = currentOrder[i]
                                    currentOrder[i] = currentOrder[i + 1]
                                    currentOrder[i + 1] = temp
                                    BookMySpaceRepository.reorderConfigurableFields(currentOrder)
                                }
                            },
                            onEdit = {
                                editingField = field
                                showAddEditDialog = true
                            },
                            onDelete = {
                                BookMySpaceRepository.deleteConfigurableField(field.id)
                                snackbarMessage = "Deleted field '${field.label}'"
                            }
                        )
                    }
                }
            }
        }
    }

    // Add / Edit Dialog
    if (showAddEditDialog) {
        AddEditConfigurableFieldDialog(
            initialField = editingField,
            defaultCategory = if (selectedCategory == ListingTargetCategory.ALL) ListingTargetCategory.VENUE else selectedCategory,
            onDismiss = { showAddEditDialog = false },
            onSave = { fieldDef ->
                BookMySpaceRepository.saveConfigurableField(fieldDef)
                showAddEditDialog = false
                snackbarMessage = "Saved field '${fieldDef.label}' successfully"
            }
        )
    }

    // Reset Defaults Confirmation Dialog
    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            icon = { Icon(Icons.Default.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
            title = { Text("Reset to Standard Fields?") },
            text = { Text("This will restore default configurable fields for Venues, Function Halls, Hostels, Institutes, Classes, and Rooms.") },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.resetConfigurableFieldsToDefault()
                        showResetDialog = false
                        snackbarMessage = "Reset all fields to defaults"
                    }
                ) {
                    Text("Reset")
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun ConfigurableFieldItemCard(
    field: ConfigurableFieldDefinition,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onToggleActive: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (field.isActive) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (field.isActive) MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f) else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)
        ),
        modifier = Modifier
            .fillMaxWidth()
            .testTag("field_item_${field.name}")
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = CircleShape,
                        modifier = Modifier.size(26.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = "#${field.displayOrder}",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(
                            text = field.label,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp,
                            color = if (field.isActive) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "Key: ${field.name}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(
                        checked = field.isActive,
                        onCheckedChange = { onToggleActive() },
                        modifier = Modifier.testTag("switch_active_${field.name}")
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Badges row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // Category Chip
                Surface(
                    color = MaterialTheme.colorScheme.secondaryContainer,
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = field.targetCategory.displayName,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }

                // Type Chip
                Surface(
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = field.fieldType.displayName,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }

                // Required Badge
                Surface(
                    color = if (field.required) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.surfaceVariant,
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = if (field.required) "Required *" else "Optional",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (field.required) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }

            if (field.placeholder.isNotBlank() || field.defaultValue.isNotBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        if (field.placeholder.isNotBlank()) {
                            Text("Help Text: ${field.placeholder}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        if (field.defaultValue.isNotBlank()) {
                            Text("Default: ${field.defaultValue}", fontSize = 11.sp, fontWeight = FontWeight.Medium)
                        }
                    }
                }
            }

            if (field.options.isNotEmpty()) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "Options: ${field.options.joinToString(", ")}",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
            Spacer(modifier = Modifier.height(6.dp))

            // Action Buttons Row (Reorder, Edit, Delete)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row {
                    IconButton(
                        onClick = onMoveUp,
                        enabled = canMoveUp,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(Icons.Default.KeyboardArrowUp, contentDescription = "Move Up")
                    }
                    IconButton(
                        onClick = onMoveDown,
                        enabled = canMoveDown,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(Icons.Default.KeyboardArrowDown, contentDescription = "Move Down")
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    FilledTonalButton(
                        onClick = onEdit,
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                        modifier = Modifier.testTag("edit_field_${field.name}")
                    ) {
                        Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Edit", fontSize = 12.sp)
                    }

                    OutlinedButton(
                        onClick = onDelete,
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                        modifier = Modifier.testTag("delete_field_${field.name}")
                    ) {
                        Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(14.dp))
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddEditConfigurableFieldDialog(
    initialField: ConfigurableFieldDefinition?,
    defaultCategory: ListingTargetCategory,
    onDismiss: () -> Unit,
    onSave: (ConfigurableFieldDefinition) -> Unit
) {
    var name by remember { mutableStateOf(initialField?.name ?: "") }
    var label by remember { mutableStateOf(initialField?.label ?: "") }
    var fieldType by remember { mutableStateOf(initialField?.fieldType ?: ConfigurableFieldType.TEXT) }
    var targetCategory by remember { mutableStateOf(initialField?.targetCategory ?: defaultCategory) }
    var required by remember { mutableStateOf(initialField?.required ?: false) }
    var defaultValue by remember { mutableStateOf(initialField?.defaultValue ?: "") }
    var optionsText by remember { mutableStateOf(initialField?.options?.joinToString(", ") ?: "") }
    var placeholder by remember { mutableStateOf(initialField?.placeholder ?: "") }
    var displayOrderText by remember { mutableStateOf(initialField?.displayOrder?.toString() ?: "1") }
    var isActive by remember { mutableStateOf(initialField?.isActive ?: true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var expandedTypeDropdown by remember { mutableStateOf(false) }
    var expandedCatDropdown by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = if (initialField == null) "Add Configurable Field" else "Edit Field '${initialField.label}'",
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp
            )
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                if (errorMessage != null) {
                    Surface(
                        color = MaterialTheme.colorScheme.errorContainer,
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = errorMessage ?: "",
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            fontSize = 12.sp,
                            modifier = Modifier.padding(8.dp)
                        )
                    }
                }

                // Field Label
                OutlinedTextField(
                    value = label,
                    onValueChange = {
                        label = it
                        if (initialField == null && name.isBlank()) {
                            name = it.lowercase().replace(" ", "_").filter { ch -> ch.isLetterOrDigit() || ch == '_' }
                        }
                    },
                    label = { Text("Field Label *") },
                    placeholder = { Text("e.g. Room Type, Sharing Capacity, AC") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("field_label_input"),
                    shape = RoundedCornerShape(10.dp),
                    singleLine = true
                )

                // Field Key Name (Internal)
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it.lowercase().replace(" ", "_") },
                    label = { Text("Internal Key Name *") },
                    placeholder = { Text("e.g. room_type, food_available, capacity") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("field_name_input"),
                    shape = RoundedCornerShape(10.dp),
                    singleLine = true
                )

                // Target Category Dropdown
                ExposedDropdownMenuBox(
                    expanded = expandedCatDropdown,
                    onExpandedChange = { expandedCatDropdown = it },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    OutlinedTextField(
                        value = targetCategory.displayName,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Target Listing Category *") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedCatDropdown) },
                        modifier = Modifier
                            .menuAnchor()
                            .fillMaxWidth()
                            .testTag("target_category_selector"),
                        shape = RoundedCornerShape(10.dp)
                    )
                    ExposedDropdownMenu(
                        expanded = expandedCatDropdown,
                        onDismissRequest = { expandedCatDropdown = false }
                    ) {
                        ListingTargetCategory.entries.forEach { cat ->
                            DropdownMenuItem(
                                text = { Text(cat.displayName) },
                                onClick = {
                                    targetCategory = cat
                                    expandedCatDropdown = false
                                }
                            )
                        }
                    }
                }

                // Field Type Dropdown
                ExposedDropdownMenuBox(
                    expanded = expandedTypeDropdown,
                    onExpandedChange = { expandedTypeDropdown = it },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    OutlinedTextField(
                        value = fieldType.displayName,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Field Data Type *") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedTypeDropdown) },
                        modifier = Modifier
                            .menuAnchor()
                            .fillMaxWidth()
                            .testTag("field_type_selector"),
                        shape = RoundedCornerShape(10.dp)
                    )
                    ExposedDropdownMenu(
                        expanded = expandedTypeDropdown,
                        onDismissRequest = { expandedTypeDropdown = false }
                    ) {
                        ConfigurableFieldType.entries.forEach { type ->
                            DropdownMenuItem(
                                text = { Text(type.displayName) },
                                onClick = {
                                    fieldType = type
                                    expandedTypeDropdown = false
                                }
                            )
                        }
                    }
                }

                // Options (for Dropdown / Multi-Select)
                if (fieldType == ConfigurableFieldType.DROPDOWN || fieldType == ConfigurableFieldType.MULTI_SELECT) {
                    OutlinedTextField(
                        value = optionsText,
                        onValueChange = { optionsText = it },
                        label = { Text("Options (Comma Separated) *") },
                        placeholder = { Text("e.g. Single Room, Double Sharing, Triple Sharing") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("field_options_input"),
                        shape = RoundedCornerShape(10.dp),
                        minLines = 2
                    )
                }

                // Default Value
                OutlinedTextField(
                    value = defaultValue,
                    onValueChange = { defaultValue = it },
                    label = { Text("Default Value") },
                    placeholder = { Text("Default prefilled value") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("field_default_value_input"),
                    shape = RoundedCornerShape(10.dp),
                    singleLine = true
                )

                // Placeholder / Help text
                OutlinedTextField(
                    value = placeholder,
                    onValueChange = { placeholder = it },
                    label = { Text("Placeholder / Help Text") },
                    placeholder = { Text("Instructions shown to owners/users") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("field_placeholder_input"),
                    shape = RoundedCornerShape(10.dp),
                    singleLine = true
                )

                // Display Order
                OutlinedTextField(
                    value = displayOrderText,
                    onValueChange = { displayOrderText = it.filter { ch -> ch.isDigit() } },
                    label = { Text("Display Order") },
                    placeholder = { Text("1") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("field_order_input"),
                    shape = RoundedCornerShape(10.dp),
                    singleLine = true
                )

                // Required Toggle
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Mandatory / Required Field", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                    Switch(
                        checked = required,
                        onCheckedChange = { required = it },
                        modifier = Modifier.testTag("field_required_switch")
                    )
                }

                // Active Toggle
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Field Active & Enabled", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                    Switch(
                        checked = isActive,
                        onCheckedChange = { isActive = it },
                        modifier = Modifier.testTag("field_active_switch")
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (label.isBlank()) {
                        errorMessage = "Field label cannot be empty"
                        return@Button
                    }
                    if (name.isBlank()) {
                        errorMessage = "Internal key name cannot be empty"
                        return@Button
                    }
                    if ((fieldType == ConfigurableFieldType.DROPDOWN || fieldType == ConfigurableFieldType.MULTI_SELECT) && optionsText.isBlank()) {
                        errorMessage = "Please enter at least one option for ${fieldType.displayName}"
                        return@Button
                    }

                    val optionsList = optionsText.split(",").map { it.trim() }.filter { it.isNotBlank() }
                    val orderNum = displayOrderText.toIntOrNull() ?: 1

                    val newField = ConfigurableFieldDefinition(
                        id = initialField?.id ?: "",
                        name = name,
                        label = label,
                        fieldType = fieldType,
                        required = required,
                        defaultValue = defaultValue,
                        options = optionsList,
                        placeholder = placeholder,
                        displayOrder = orderNum,
                        isActive = isActive,
                        targetCategory = targetCategory
                    )
                    onSave(newField)
                },
                modifier = Modifier.testTag("save_configurable_field_button")
            ) {
                Text("Save Field")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
