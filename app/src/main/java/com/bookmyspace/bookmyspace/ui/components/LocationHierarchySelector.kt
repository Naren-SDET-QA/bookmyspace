package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Top App Bar Location Header Bar
 * Formats: 📍 State → District → Mandal → City → Area
 */
@Composable
fun LocationHierarchyHeaderBar(
    currentLocation: LocationHierarchy,
    selectedRadius: LocationSearchRadius = LocationSearchRadius.RADIUS_25_KM,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("location_hierarchy_header_btn")
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = "Location Pin",
                        tint = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                }

                Spacer(modifier = Modifier.width(10.dp))

                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = currentLocation.shortLabel,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.Default.KeyboardArrowDown,
                            contentDescription = "Change Location",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        )
                    }

                    Text(
                        text = "${currentLocation.breadcrumbLabel} (${selectedRadius.displayName})",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                modifier = Modifier.padding(start = 4.dp)
            ) {
                Text(
                    text = "Change",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }
    }
}

/**
 * Interactive Modal Dialog for Location Detection and Hierarchy Selection
 * Supports:
 * - 1-Tap GPS Detect Location
 * - Direct Search Across State/District/Mandal/City/Area
 * - Step-by-Step Cascade: Country -> State -> District -> Mandal -> City -> Area
 * - Radius Selection
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LocationHierarchySelectorDialog(
    currentLocation: LocationHierarchy,
    currentRadius: LocationSearchRadius,
    onLocationSelected: (LocationHierarchy, LocationSearchRadius) -> Unit,
    onDismiss: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()
    var isGpsDetecting by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedRadius by remember { mutableStateOf(currentRadius) }

    // Hierarchy Selection Tab / Mode: "QUICK" or "HIERARCHY"
    var activeTab by remember { mutableStateOf("QUICK") }

    // Step state for HIERARCHY navigation
    var stepStateId by remember { mutableStateOf(currentLocation.stateId) }
    var stepDistrictId by remember { mutableStateOf(currentLocation.districtId) }
    var stepMandalId by remember { mutableStateOf(currentLocation.mandalId) }
    var stepCityId by remember { mutableStateOf(currentLocation.cityTownId) }
    var stepAreaId by remember { mutableStateOf(currentLocation.areaId) }

    val searchResults = remember(searchQuery) {
        if (searchQuery.isNotBlank()) {
            IndiaLocationMasterData.searchLocations(searchQuery)
        } else emptyList()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 16.dp)
            .testTag("location_hierarchy_dialog"),
        title = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Explore,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Select Location",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 19.sp
                    )
                }
                IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "Close", modifier = Modifier.size(18.dp))
                }
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 520.dp)
            ) {
                // 1-Tap GPS Location Button
                Button(
                    onClick = {
                        isGpsDetecting = true
                        coroutineScope.launch {
                            delay(600) // Simulated GPS fix
                            // Use Hyderabad or Ongole GPS Centroid based on toggle or nearest
                            val resolved = IndiaLocationMasterData.findNearestLocation(17.4401, 78.3489)
                            isGpsDetecting = false
                            onLocationSelected(resolved, selectedRadius)
                            onDismiss()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("gps_detect_location_btn"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    if (isGpsDetecting) {
                        CircularProgressIndicator(
                            color = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Detecting Nearest Location...", fontSize = 13.sp)
                    } else {
                        Icon(Icons.Default.MyLocation, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Use My Current GPS Location", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Search Box
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Search Area, Mandal, City, District...", fontSize = 13.sp) },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp)) },
                    trailingIcon = {
                        if (searchQuery.isNotEmpty()) {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Default.Clear, contentDescription = "Clear", modifier = Modifier.size(16.dp))
                            }
                        }
                    },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("location_search_input"),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search)
                )

                Spacer(modifier = Modifier.height(10.dp))

                // Radius Selector Chips
                Text(
                    text = "Discovery Radius",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(LocationSearchRadius.entries) { radius ->
                        val isSelected = radius == selectedRadius
                        FilterChip(
                            selected = isSelected,
                            onClick = { selectedRadius = radius },
                            label = { Text(radius.displayName, fontSize = 11.sp) },
                            shape = RoundedCornerShape(16.dp),
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = MaterialTheme.colorScheme.primary,
                                selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                            )
                        )
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Mode Tabs: Quick Popular / Hierarchy Cascade
                TabRow(
                    selectedTabIndex = if (activeTab == "QUICK") 0 else 1,
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp))
                ) {
                    Tab(
                        selected = activeTab == "QUICK",
                        onClick = { activeTab = "QUICK" },
                        text = { Text("Popular Cities", fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                    )
                    Tab(
                        selected = activeTab == "HIERARCHY",
                        onClick = { activeTab = "HIERARCHY" },
                        text = { Text("Browse Hierarchy", fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // If user typed in search query, show live search matches
                if (searchQuery.isNotBlank()) {
                    Text(
                        text = "Search Results (${searchResults.size})",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        items(searchResults) { loc ->
                            Surface(
                                onClick = {
                                    onLocationSelected(loc, selectedRadius)
                                    onDismiss()
                                },
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.Place,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Column {
                                        Text(
                                            text = loc.shortLabel,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.sp
                                        )
                                        Text(
                                            text = loc.breadcrumbLabel,
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        }
                    }
                } else if (activeTab == "QUICK") {
                    // Quick popular presets
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        item {
                            Text(
                                text = "Andhra Pradesh & Telangana Highlights:",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        items(IndiaLocationMasterData.POPULAR_LOCATION_PRESETS) { preset ->
                            val isCurrent = preset.stateId == currentLocation.stateId &&
                                    preset.districtId == currentLocation.districtId &&
                                    preset.cityTownId == currentLocation.cityTownId &&
                                    (preset.areaId == currentLocation.areaId || currentLocation.areaId == null)

                            Surface(
                                onClick = {
                                    onLocationSelected(preset, selectedRadius)
                                    onDismiss()
                                },
                                shape = RoundedCornerShape(10.dp),
                                color = if (isCurrent) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
                                border = BorderStroke(
                                    1.dp,
                                    if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
                                ),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        Icon(
                                            imageVector = if (isCurrent) Icons.Default.CheckCircle else Icons.Default.LocationCity,
                                            contentDescription = null,
                                            tint = if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                            modifier = Modifier.size(18.dp)
                                        )
                                        Spacer(modifier = Modifier.width(10.dp))
                                        Column {
                                            Text(
                                                text = preset.shortLabel,
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 13.sp,
                                                color = if (isCurrent) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface
                                            )
                                            Text(
                                                text = preset.breadcrumbLabel,
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }

                                    if (isCurrent) {
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = MaterialTheme.colorScheme.primary
                                        ) {
                                            Text(
                                                text = "ACTIVE",
                                                fontSize = 9.sp,
                                                fontWeight = FontWeight.ExtraBold,
                                                color = MaterialTheme.colorScheme.onPrimary,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Step-by-Step Hierarchy Drilldown: State -> District -> Mandal -> City -> Area
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // 1. State Selector
                        item {
                            Text("1. Select State / UT:", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                items(IndiaLocationMasterData.STATES) { state ->
                                    val isSelected = state.id == stepStateId
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = {
                                            stepStateId = state.id
                                            val firstDist = IndiaLocationMasterData.getDistrictsForState(state.id).firstOrNull()
                                            stepDistrictId = firstDist?.id ?: ""
                                            val firstMandal = IndiaLocationMasterData.getMandalsForDistrict(stepDistrictId).firstOrNull()
                                            stepMandalId = firstMandal?.id ?: ""
                                            val firstCity = IndiaLocationMasterData.getCitiesForMandal(stepMandalId).firstOrNull()
                                                ?: IndiaLocationMasterData.getCitiesForDistrict(stepDistrictId).firstOrNull()
                                            stepCityId = firstCity?.id ?: ""
                                            stepAreaId = null
                                        },
                                        label = { Text(state.name, fontSize = 11.sp) },
                                        leadingIcon = if (isSelected) {
                                            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                                        } else null
                                    )
                                }
                            }
                        }

                        // 2. District Selector
                        item {
                            Text("2. Select District:", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            val dists = IndiaLocationMasterData.getDistrictsForState(stepStateId)
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                items(dists) { dist ->
                                    val isSelected = dist.id == stepDistrictId
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = {
                                            stepDistrictId = dist.id
                                            val firstMandal = IndiaLocationMasterData.getMandalsForDistrict(dist.id).firstOrNull()
                                            stepMandalId = firstMandal?.id ?: ""
                                            val firstCity = IndiaLocationMasterData.getCitiesForMandal(stepMandalId).firstOrNull()
                                                ?: IndiaLocationMasterData.getCitiesForDistrict(dist.id).firstOrNull()
                                            stepCityId = firstCity?.id ?: ""
                                            stepAreaId = null
                                        },
                                        label = { Text(dist.name, fontSize = 11.sp) },
                                        leadingIcon = if (isSelected) {
                                            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                                        } else null
                                    )
                                }
                            }
                        }

                        // 3. Mandal Selector
                        item {
                            Text("3. Select Mandal / Taluk:", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            val mandals = IndiaLocationMasterData.getMandalsForDistrict(stepDistrictId)
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                items(mandals) { mandal ->
                                    val isSelected = mandal.id == stepMandalId
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = {
                                            stepMandalId = mandal.id
                                            val firstCity = IndiaLocationMasterData.getCitiesForMandal(mandal.id).firstOrNull()
                                            stepCityId = firstCity?.id ?: ""
                                            stepAreaId = null
                                        },
                                        label = { Text(mandal.name, fontSize = 11.sp) },
                                        leadingIcon = if (isSelected) {
                                            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                                        } else null
                                    )
                                }
                            }
                        }

                        // 4. City / Town Selector
                        item {
                            Text("4. Select City / Town / Village:", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            val cities = IndiaLocationMasterData.getCitiesForMandal(stepMandalId).ifEmpty {
                                IndiaLocationMasterData.getCitiesForDistrict(stepDistrictId)
                            }
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                items(cities) { city ->
                                    val isSelected = city.id == stepCityId
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = {
                                            stepCityId = city.id
                                            stepAreaId = null
                                        },
                                        label = { Text(city.name, fontSize = 11.sp) },
                                        leadingIcon = if (isSelected) {
                                            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                                        } else null
                                    )
                                }
                            }
                        }

                        // 5. Area Selector
                        item {
                            Text("5. Select Area / Locality (Optional):", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(4.dp))
                            val areas = IndiaLocationMasterData.getAreasForCity(stepCityId).ifEmpty {
                                IndiaLocationMasterData.getAreasForMandal(stepMandalId)
                            }
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                // Option for Entire City / All Areas
                                Surface(
                                    onClick = {
                                        val built = IndiaLocationMasterData.buildHierarchy(
                                            stateId = stepStateId,
                                            districtId = stepDistrictId,
                                            mandalId = stepMandalId,
                                            cityTownId = stepCityId,
                                            areaId = null
                                        )
                                        onLocationSelected(built, selectedRadius)
                                        onDismiss()
                                    },
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.secondaryContainer,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        modifier = Modifier.padding(10.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Icon(Icons.Default.Public, contentDescription = null, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text("Select Entire City (All Areas in City)", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                    }
                                }

                                areas.forEach { area ->
                                    Surface(
                                        onClick = {
                                            val built = IndiaLocationMasterData.buildHierarchy(
                                                stateId = stepStateId,
                                                districtId = stepDistrictId,
                                                mandalId = stepMandalId,
                                                cityTownId = stepCityId,
                                                areaId = area.id
                                            )
                                            onLocationSelected(built, selectedRadius)
                                            onDismiss()
                                        },
                                        shape = RoundedCornerShape(8.dp),
                                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Row(
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Column {
                                                Text(area.name, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                                                if (area.landmark.isNotBlank()) {
                                                    Text(area.landmark, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                                }
                                            }
                                            if (area.postalCode.isNotBlank()) {
                                                Text(area.postalCode, fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val built = IndiaLocationMasterData.buildHierarchy(
                        stateId = stepStateId,
                        districtId = stepDistrictId,
                        mandalId = stepMandalId,
                        cityTownId = stepCityId,
                        areaId = stepAreaId
                    )
                    onLocationSelected(built, selectedRadius)
                    onDismiss()
                }
            ) {
                Text("Apply Location", fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

/**
 * Dropdown Cascade Form Component for Listing Owners
 * Allows owners when creating or editing a listing to pick:
 * Country -> State -> District -> Mandal -> City -> Area
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerLocationHierarchySelector(
    selectedHierarchy: LocationHierarchy?,
    onHierarchyChanged: (LocationHierarchy) -> Unit,
    modifier: Modifier = Modifier
) {
    var stateId by remember(selectedHierarchy) { mutableStateOf(selectedHierarchy?.stateId ?: "IN-TG") }
    var districtId by remember(selectedHierarchy) { mutableStateOf(selectedHierarchy?.districtId ?: "DIST_TG_HYDERABAD") }
    var mandalId by remember(selectedHierarchy) { mutableStateOf(selectedHierarchy?.mandalId ?: "MANDAL_TG_SERILINGAMPALLY") }
    var cityId by remember(selectedHierarchy) { mutableStateOf(selectedHierarchy?.cityTownId ?: "CITY_TG_HYDERABAD") }
    var areaId by remember(selectedHierarchy) { mutableStateOf(selectedHierarchy?.areaId ?: "AREA_TG_HYD_GACHIBOWLI") }

    var expandedState by remember { mutableStateOf(false) }
    var expandedDistrict by remember { mutableStateOf(false) }
    var expandedMandal by remember { mutableStateOf(false) }
    var expandedCity by remember { mutableStateOf(false) }
    var expandedArea by remember { mutableStateOf(false) }

    val availableStates = IndiaLocationMasterData.STATES
    val availableDistricts = remember(stateId) { IndiaLocationMasterData.getDistrictsForState(stateId) }
    val availableMandals = remember(districtId) { IndiaLocationMasterData.getMandalsForDistrict(districtId) }
    val availableCities = remember(mandalId, districtId) {
        IndiaLocationMasterData.getCitiesForMandal(mandalId).ifEmpty {
            IndiaLocationMasterData.getCitiesForDistrict(districtId)
        }
    }
    val availableAreas = remember(cityId, mandalId) {
        IndiaLocationMasterData.getAreasForCity(cityId).ifEmpty {
            IndiaLocationMasterData.getAreasForMandal(mandalId)
        }
    }

    val currentState = availableStates.firstOrNull { it.id == stateId }
    val currentDistrict = availableDistricts.firstOrNull { it.id == districtId }
    val currentMandal = availableMandals.firstOrNull { it.id == mandalId }
    val currentCity = availableCities.firstOrNull { it.id == cityId }
    val currentArea = availableAreas.firstOrNull { it.id == areaId }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.PinDrop, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = "India Location Hierarchy (Official Master IDs)",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
        }

        // 1. State Dropdown
        ExposedDropdownMenuBox(
            expanded = expandedState,
            onExpandedChange = { expandedState = !expandedState }
        ) {
            OutlinedTextField(
                value = currentState?.name ?: "Select State",
                onValueChange = {},
                readOnly = true,
                label = { Text("State / UT *") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedState) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            )
            ExposedDropdownMenu(
                expanded = expandedState,
                onDismissRequest = { expandedState = false }
            ) {
                availableStates.forEach { st ->
                    DropdownMenuItem(
                        text = { Text(st.name) },
                        onClick = {
                            stateId = st.id
                            expandedState = false
                            val d = IndiaLocationMasterData.getDistrictsForState(st.id).firstOrNull()
                            districtId = d?.id ?: ""
                            val m = IndiaLocationMasterData.getMandalsForDistrict(districtId).firstOrNull()
                            mandalId = m?.id ?: ""
                            val c = IndiaLocationMasterData.getCitiesForMandal(mandalId).firstOrNull() ?: IndiaLocationMasterData.getCitiesForDistrict(districtId).firstOrNull()
                            cityId = c?.id ?: ""
                            val a = IndiaLocationMasterData.getAreasForCity(cityId).firstOrNull()
                            areaId = a?.id ?: ""
                            val built = IndiaLocationMasterData.buildHierarchy(stateId, districtId, mandalId, cityId, areaId)
                            onHierarchyChanged(built)
                        }
                    )
                }
            }
        }

        // 2. District Dropdown
        ExposedDropdownMenuBox(
            expanded = expandedDistrict,
            onExpandedChange = { expandedDistrict = !expandedDistrict }
        ) {
            OutlinedTextField(
                value = currentDistrict?.name ?: "Select District",
                onValueChange = {},
                readOnly = true,
                label = { Text("District *") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedDistrict) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            )
            ExposedDropdownMenu(
                expanded = expandedDistrict,
                onDismissRequest = { expandedDistrict = false }
            ) {
                availableDistricts.forEach { dist ->
                    DropdownMenuItem(
                        text = { Text(dist.name) },
                        onClick = {
                            districtId = dist.id
                            expandedDistrict = false
                            val m = IndiaLocationMasterData.getMandalsForDistrict(dist.id).firstOrNull()
                            mandalId = m?.id ?: ""
                            val c = IndiaLocationMasterData.getCitiesForMandal(mandalId).firstOrNull() ?: IndiaLocationMasterData.getCitiesForDistrict(dist.id).firstOrNull()
                            cityId = c?.id ?: ""
                            val a = IndiaLocationMasterData.getAreasForCity(cityId).firstOrNull()
                            areaId = a?.id ?: ""
                            val built = IndiaLocationMasterData.buildHierarchy(stateId, districtId, mandalId, cityId, areaId)
                            onHierarchyChanged(built)
                        }
                    )
                }
            }
        }

        // 3. Mandal Dropdown
        ExposedDropdownMenuBox(
            expanded = expandedMandal,
            onExpandedChange = { expandedMandal = !expandedMandal }
        ) {
            OutlinedTextField(
                value = currentMandal?.name ?: "Select Mandal",
                onValueChange = {},
                readOnly = true,
                label = { Text("Mandal / Taluk *") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedMandal) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            )
            ExposedDropdownMenu(
                expanded = expandedMandal,
                onDismissRequest = { expandedMandal = false }
            ) {
                availableMandals.forEach { m ->
                    DropdownMenuItem(
                        text = { Text(m.name) },
                        onClick = {
                            mandalId = m.id
                            expandedMandal = false
                            val c = IndiaLocationMasterData.getCitiesForMandal(m.id).firstOrNull() ?: IndiaLocationMasterData.getCitiesForDistrict(districtId).firstOrNull()
                            cityId = c?.id ?: ""
                            val a = IndiaLocationMasterData.getAreasForCity(cityId).firstOrNull()
                            areaId = a?.id ?: ""
                            val built = IndiaLocationMasterData.buildHierarchy(stateId, districtId, mandalId, cityId, areaId)
                            onHierarchyChanged(built)
                        }
                    )
                }
            }
        }

        // 4. City / Town Dropdown
        ExposedDropdownMenuBox(
            expanded = expandedCity,
            onExpandedChange = { expandedCity = !expandedCity }
        ) {
            OutlinedTextField(
                value = currentCity?.name ?: "Select City",
                onValueChange = {},
                readOnly = true,
                label = { Text("City / Town / Village *") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedCity) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            )
            ExposedDropdownMenu(
                expanded = expandedCity,
                onDismissRequest = { expandedCity = false }
            ) {
                availableCities.forEach { c ->
                    DropdownMenuItem(
                        text = { Text(c.name) },
                        onClick = {
                            cityId = c.id
                            expandedCity = false
                            val a = IndiaLocationMasterData.getAreasForCity(c.id).firstOrNull()
                            areaId = a?.id ?: ""
                            val built = IndiaLocationMasterData.buildHierarchy(stateId, districtId, mandalId, cityId, areaId)
                            onHierarchyChanged(built)
                        }
                    )
                }
            }
        }

        // 5. Area / Locality Dropdown
        ExposedDropdownMenuBox(
            expanded = expandedArea,
            onExpandedChange = { expandedArea = !expandedArea }
        ) {
            OutlinedTextField(
                value = currentArea?.name ?: "Select Area / Locality",
                onValueChange = {},
                readOnly = true,
                label = { Text("Area / Locality / Landmark") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedArea) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            )
            ExposedDropdownMenu(
                expanded = expandedArea,
                onDismissRequest = { expandedArea = false }
            ) {
                availableAreas.forEach { a ->
                    DropdownMenuItem(
                        text = { Text("${a.name} (${a.postalCode})") },
                        onClick = {
                            areaId = a.id
                            expandedArea = false
                            val built = IndiaLocationMasterData.buildHierarchy(stateId, districtId, mandalId, cityId, areaId)
                            onHierarchyChanged(built)
                        }
                    )
                }
            }
        }

        // Selected Breadcrumb Preview
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(10.dp)) {
                Text(
                    text = "Hierarchy Path:",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "📍 ${currentState?.name} → ${currentDistrict?.name} → ${currentMandal?.name} → ${currentCity?.name} → ${currentArea?.name ?: "All Area"}",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}
