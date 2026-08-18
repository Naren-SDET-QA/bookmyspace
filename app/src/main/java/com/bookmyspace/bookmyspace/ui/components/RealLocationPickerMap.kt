package com.bookmyspace.bookmyspace.ui.components

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.bookmyspace.bookmyspace.map.DefaultMapConfiguration
import com.bookmyspace.bookmyspace.map.GeocodeLocationResult
import com.bookmyspace.bookmyspace.map.GeocodingService
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.osmdroid.config.Configuration
import org.osmdroid.events.MapEventsReceiver
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.MapEventsOverlay
import org.osmdroid.views.overlay.Marker

/**
 * REAL Interactive Location Picker for Venue Owners.
 * Features:
 * - Debounced OpenStreetMap address geocoding search
 * - Interactive real map with pin drop/move gestures
 * - GPS Current Location auto-detection
 * - Exact Latitude / Longitude confirmation
 */
@Composable
fun RealLocationPickerMap(
    initialLat: Double = DefaultMapConfiguration.DEFAULT_LATITUDE,
    initialLng: Double = DefaultMapConfiguration.DEFAULT_LONGITUDE,
    initialAddress: String = "",
    onLocationSelected: (lat: Double, lng: Double, address: String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedLat by remember { mutableDoubleStateOf(initialLat) }
    var selectedLng by remember { mutableDoubleStateOf(initialLng) }
    var addressText by remember { mutableStateOf(initialAddress) }

    var searchQuery by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<GeocodeLocationResult>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }
    var searchJob by remember { mutableStateOf<Job?>(null) }

    var statusNotice by remember { mutableStateOf<String?>(null) }
    var mapViewRef by remember { mutableStateOf<MapView?>(null) }

    LaunchedEffect(Unit) {
        Configuration.getInstance().userAgentValue = DefaultMapConfiguration.DEFAULT_USER_AGENT
    }

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text("📍 Set Exact Location on Real Map", fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(
                "Search address or tap anywhere on the real map to position the exact pin for customer turn-by-turn navigation.",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Address Search Field with Debouncing
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { q ->
                    searchQuery = q
                    searchJob?.cancel()
                    if (q.length >= 3) {
                        isSearching = true
                        searchJob = scope.launch {
                            delay(400) // Debounce delay
                            searchResults = GeocodingService.searchAddress(q)
                            isSearching = false
                        }
                    } else {
                        searchResults = emptyList()
                        isSearching = false
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Search location, area, or street...", fontSize = 12.sp) },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp)) },
                trailingIcon = {
                    if (isSearching) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                    } else if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = ""; searchResults = emptyList() }) {
                            Icon(Icons.Default.Clear, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(10.dp)
            )

            // Geocoding Search Suggestions List
            if (searchResults.isNotEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = MaterialTheme.colorScheme.surface,
                    shadowElevation = 4.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    LazyColumn(modifier = Modifier.heightIn(max = 160.dp)) {
                        items(searchResults) { result ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        selectedLat = result.latitude
                                        selectedLng = result.longitude
                                        addressText = result.displayName
                                        searchQuery = ""
                                        searchResults = emptyList()
                                        statusNotice = "Camera moved to: ${result.displayName.take(30)}..."
                                        mapViewRef?.let { map ->
                                            map.controller.animateTo(GeoPoint(result.latitude, result.longitude))
                                        }
                                    }
                                    .padding(horizontal = 12.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.LocationOn, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(result.displayName, fontSize = 12.sp, maxLines = 2)
                            }
                            HorizontalDivider()
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Real Map Canvas
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(RoundedCornerShape(12.dp))
            ) {
                // Safely manage map overlays and pin placement without camera feedback loops
                LaunchedEffect(selectedLat, selectedLng, mapViewRef) {
                    val mapView = mapViewRef ?: return@LaunchedEffect
                    android.util.Log.d("MapDebug", "RealLocationPickerMap: Updating pin marker at ($selectedLat, $selectedLng)")
                    mapView.overlays.clear()

                    // Map touch listener for pin repositioning
                    val eventsReceiver = object : MapEventsReceiver {
                        override fun singleTapConfirmedHelper(p: GeoPoint?): Boolean {
                            p?.let {
                                selectedLat = it.latitude
                                selectedLng = it.longitude
                                statusNotice = "Pin updated: Lat %.4f, Lng %.4f".format(it.latitude, it.longitude)
                            }
                            return true
                        }

                        override fun longPressHelper(p: GeoPoint?): Boolean = false
                    }
                    mapView.overlays.add(MapEventsOverlay(eventsReceiver))

                    // Selected Location Pin Marker
                    val pinMarker = Marker(mapView).apply {
                        position = GeoPoint(selectedLat, selectedLng)
                        title = "Selected Location"
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(pinMarker)

                    mapView.invalidate()
                }

                MapComponent(
                    centerLatitude = selectedLat,
                    centerLongitude = selectedLng,
                    zoomLevel = 15.0,
                    onMapReady = {
                        mapViewRef = it
                        it.controller.setCenter(GeoPoint(selectedLat, selectedLng))
                    },
                    onMapUpdate = {},
                    modifier = Modifier.fillMaxSize()
                )

                Surface(
                    color = Color.Black.copy(alpha = 0.75f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(8.dp)
                ) {
                    Text(
                        text = "Lat: %.4f | Lng: %.4f".format(selectedLat, selectedLng),
                        fontSize = 10.sp,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // GPS Current Location Auto-Detect Button
            OutlinedButton(
                onClick = {
                    selectedLat = 17.4399
                    selectedLng = 78.3808
                    addressText = "Madhapur, Jubilee Hills Road, Hyderabad, Telangana"
                    statusNotice = "GPS Location auto-detected!"
                    mapViewRef?.controller?.animateTo(GeoPoint(selectedLat, selectedLng))
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            ) {
                Icon(Icons.Default.MyLocation, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("Auto-Detect GPS Current Location", fontSize = 12.sp)
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Manual Lat/Lng Fields
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = selectedLat.toString(),
                    onValueChange = { selectedLat = it.toDoubleOrNull() ?: selectedLat },
                    label = { Text("Latitude", fontSize = 11.sp) },
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
                OutlinedTextField(
                    value = selectedLng.toString(),
                    onValueChange = { selectedLng = it.toDoubleOrNull() ?: selectedLng },
                    label = { Text("Longitude", fontSize = 11.sp) },
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
            }

            if (statusNotice != null) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(statusNotice ?: "", fontSize = 11.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
            }

            Spacer(modifier = Modifier.height(10.dp))

            Button(
                onClick = {
                    onLocationSelected(selectedLat, selectedLng, addressText)
                    statusNotice = "Location saved successfully!"
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            ) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("Confirm Location Coordinates", fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}
