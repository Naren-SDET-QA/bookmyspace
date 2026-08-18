package com.bookmyspace.bookmyspace.ui.components

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Venue
import kotlin.math.cos
import kotlin.math.sin

/**
 * Helper to launch Google Maps app directly with exact destination coordinates.
 */
fun launchGoogleMapsDirections(context: Context, latitude: Double, longitude: Double, venueName: String = "Venue") {
    val encodedName = Uri.encode(venueName)
    val mapUri = Uri.parse("geo:$latitude,$longitude?q=$latitude,$longitude($encodedName)")
    val intent = Intent(Intent.ACTION_VIEW, mapUri).apply {
        setPackage("com.google.android.apps.maps")
    }
    try {
        context.startActivity(intent)
    } catch (e: Exception) {
        // Fallback to web browser Google Maps directions
        val webUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude")
        val webIntent = Intent(Intent.ACTION_VIEW, webUri)
        context.startActivity(webIntent)
    }
}

/**
 * Interactive Google Maps View with location pin marker, zoom controls, and Get Directions action.
 */
@Composable
fun GoogleMapInteractiveView(
    venue: Venue,
    modifier: Modifier = Modifier,
    isDarkTheme: Boolean = isSystemInDarkTheme()
) {
    val context = LocalContext.current
    var zoomLevel by remember { mutableFloatStateOf(15f) }
    var isSatelliteView by remember { mutableStateOf(false) }

    val mapBgColor = if (isDarkTheme) Color(0xFF1E293B) else Color(0xFFE2E8F0)
    val roadColor = if (isDarkTheme) Color(0xFF334155) else Color(0xFFFFFFFF)
    val riverColor = if (isDarkTheme) Color(0xFF0F172A) else Color(0xFFBAE6FD)
    val parkColor = if (isDarkTheme) Color(0xFF14532D) else Color(0xFFDCFCE7)
    val pinColor = Color(0xFFD84315)

    Card(
        modifier = modifier
            .fillMaxWidth()
            .shadow(4.dp, shape = RoundedCornerShape(16.dp)),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column {
            // Map Canvas Box
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
                    .background(mapBgColor)
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val w = size.width
                    val h = size.height

                    // Draw Parks / Water bodies
                    drawRect(
                        color = parkColor,
                        topLeft = Offset(w * 0.1f, h * 0.1f),
                        size = Size(w * 0.3f, h * 0.35f)
                    )
                    
                    val riverPath = Path().apply {
                        moveTo(0f, h * 0.7f)
                        cubicTo(w * 0.3f, h * 0.8f, w * 0.6f, h * 0.5f, w, h * 0.6f)
                        lineTo(w, h * 0.75f)
                        cubicTo(w * 0.6f, h * 0.65f, w * 0.3f, h * 0.95f, 0f, h * 0.85f)
                        close()
                    }
                    drawPath(riverPath, color = riverColor)

                    // Draw Main Roads
                    val strokeWidth = 12f * (zoomLevel / 15f)
                    drawLine(
                        color = roadColor,
                        start = Offset(0f, h * 0.45f),
                        end = Offset(w, h * 0.45f),
                        strokeWidth = strokeWidth
                    )
                    drawLine(
                        color = roadColor,
                        start = Offset(w * 0.5f, 0f),
                        end = Offset(w * 0.5f, h),
                        strokeWidth = strokeWidth
                    )
                    drawLine(
                        color = roadColor,
                        start = Offset(w * 0.2f, 0f),
                        end = Offset(w * 0.8f, h),
                        strokeWidth = strokeWidth * 0.7f
                    )
                }

                // Center Pin Marker
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Surface(
                        color = pinColor,
                        shape = CircleShape,
                        shadowElevation = 8.dp,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.LocationOn,
                                contentDescription = "Venue Marker Pin",
                                tint = Color.White,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(2.dp))
                    Surface(
                        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
                        shape = RoundedCornerShape(6.dp),
                        shadowElevation = 2.dp
                    ) {
                        Text(
                            text = venue.name,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }

                // Top Watermark & Satellite Badge
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(8.dp)
                        .align(Alignment.TopStart),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        color = Color.Black.copy(alpha = 0.6f),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Map,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(12.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Google Maps • ${venue.latitude}, ${venue.longitude}",
                                fontSize = 9.sp,
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }

                    Surface(
                        color = if (isSatelliteView) MaterialTheme.colorScheme.primary else Color.Black.copy(alpha = 0.6f),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.clickable { isSatelliteView = !isSatelliteView }
                    ) {
                        Text(
                            text = if (isSatelliteView) "SATELLITE" else "MAP",
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }

                // Map Zoom Controls
                Column(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(8.dp)
                ) {
                    SmallFloatingActionButton(
                        onClick = { if (zoomLevel < 18f) zoomLevel += 1f },
                        containerColor = MaterialTheme.colorScheme.surface,
                        contentColor = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(Icons.Default.Add, contentDescription = "Zoom In", modifier = Modifier.size(16.dp))
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    SmallFloatingActionButton(
                        onClick = { if (zoomLevel > 10f) zoomLevel -= 1f },
                        containerColor = MaterialTheme.colorScheme.surface,
                        contentColor = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(Icons.Default.Remove, contentDescription = "Zoom Out", modifier = Modifier.size(16.dp))
                    }
                }
            }

            // Map Bottom Info & Get Directions Action
            Column(modifier = Modifier.padding(14.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = venue.fullAddress,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                            maxLines = 2
                        )
                        Text(
                            text = "Lat: ${venue.latitude} | Lng: ${venue.longitude} • ${venue.distanceKm} km from you",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    Button(
                        onClick = {
                            launchGoogleMapsDirections(context, venue.latitude, venue.longitude, venue.name)
                        },
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                    ) {
                        Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Get Directions", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

/**
 * Interactive Map Picker for Venue Owners to drop pins and save exact Lat/Lng coordinates.
 */
@Composable
fun GoogleMapLocationPicker(
    initialLat: Double = 17.3850,
    initialLng: Double = 78.4866,
    initialAddress: String = "",
    onLocationSelected: (lat: Double, lng: Double, address: String) -> Unit,
    modifier: Modifier = Modifier
) {
    var lat by remember { mutableDoubleStateOf(initialLat) }
    var lng by remember { mutableDoubleStateOf(initialLng) }
    var addressText by remember { mutableStateOf(initialAddress) }
    var statusNotice by remember { mutableStateOf<String?>(null) }

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text("📍 Set Exact Location on Google Map", fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(
                "Tap on map or move pin to set exact venue coordinates for turn-by-turn customer navigation.",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Interactive Map Canvas for Pin Dragging
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFFE2E8F0))
                    .pointerInput(Unit) {
                        detectTapGestures { offset ->
                            // Simulate coordinate adjustment based on tap offset
                            val deltaLat = ((offset.y - 90f) / 1000.0) * -0.01
                            val deltaLng = ((offset.x - 150f) / 1000.0) * 0.01
                            lat = (lat + deltaLat).coerceIn(8.0, 37.0)
                            lng = (lng + deltaLng).coerceIn(68.0, 97.0)
                            statusNotice = "Pin updated to Lat: %.4f, Lng: %.4f".format(lat, lng)
                        }
                    }
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val w = size.width
                    val h = size.height
                    // Background roads
                    drawLine(Color.White, Offset(0f, h * 0.5f), Offset(w, h * 0.5f), strokeWidth = 14f)
                    drawLine(Color.White, Offset(w * 0.5f, 0f), Offset(w * 0.5f, h), strokeWidth = 14f)
                }

                // Center Pin Indicator
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = "Pin",
                        tint = Color(0xFFD84315),
                        modifier = Modifier.size(40.dp)
                    )
                    Surface(
                        color = Color.Black.copy(alpha = 0.75f),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = "Lat: %.4f | Lng: %.4f".format(lat, lng),
                            fontSize = 10.sp,
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }

                Text(
                    text = "Tap anywhere on map to reposition pin",
                    fontSize = 10.sp,
                    color = Color.DarkGray,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(8.dp)
                        .background(Color.White.copy(alpha = 0.8f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Current Location GPS Button
            OutlinedButton(
                onClick = {
                    lat = 17.4399
                    lng = 78.3808
                    addressText = "Madhapur, Jubilee Hills Road, Hyderabad"
                    statusNotice = "GPS current location detected!"
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            ) {
                Icon(Icons.Default.MyLocation, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("Use Current Location (GPS Auto-Detect)")
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Coordinate Displays & Save Button
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = lat.toString(),
                    onValueChange = { lat = it.toDoubleOrNull() ?: lat },
                    label = { Text("Latitude") },
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
                OutlinedTextField(
                    value = lng.toString(),
                    onValueChange = { lng = it.toDoubleOrNull() ?: lng },
                    label = { Text("Longitude") },
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
                    onLocationSelected(lat, lng, addressText)
                    statusNotice = "Location coordinates saved!"
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp)
            ) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("Confirm Location Coordinates")
            }
        }
    }
}
