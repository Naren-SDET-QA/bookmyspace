package com.bookmyspace.bookmyspace.ui.components

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.Color as AndroidColor
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.map.DefaultMapConfiguration
import com.bookmyspace.bookmyspace.map.MapAndMarkerCacheManager
import com.bookmyspace.bookmyspace.util.VenueImageResolver
import com.bookmyspace.bookmyspace.util.PerformanceTracer
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

/**
 * REAL Interactive OpenStreetMap / MapLibre Map View Composable.
 * Renders actual OpenStreetMap map tiles with pan, pinch zoom, dynamic theme-colored venue markers,
 * camera animation, and selected venue preview card.
 */
@Composable
fun RealMapViewComponent(
    venues: List<Venue>,
    selectedVenueId: String? = null,
    onVenueSelect: (Venue) -> Unit = {},
    onNavigateToVenueDetails: (String) -> Unit = {},
    modifier: Modifier = Modifier,
    initialCenterLat: Double = DefaultMapConfiguration.DEFAULT_LATITUDE,
    initialCenterLng: Double = DefaultMapConfiguration.DEFAULT_LONGITUDE,
    initialZoom: Double = DefaultMapConfiguration.DEFAULT_ZOOM,
    isDarkTheme: Boolean = isSystemInDarkTheme()
) {
    val context = LocalContext.current

    // Initialize osmdroid configuration
    LaunchedEffect(Unit) {
        Configuration.getInstance().userAgentValue = DefaultMapConfiguration.DEFAULT_USER_AGENT
    }

    var activeVenue by remember(selectedVenueId, venues) {
        mutableStateOf(venues.firstOrNull { it.id == selectedVenueId } ?: venues.firstOrNull())
    }

    var currentZoom by remember { mutableDoubleStateOf(initialZoom) }
    var mapViewInstance by remember { mutableStateOf<MapView?>(null) }

    // Dynamic Theme Color Integers (updates when active theme or dark mode changes)
    val primaryColorInt = MaterialTheme.colorScheme.primary.toArgb()
    val onPrimaryColorInt = MaterialTheme.colorScheme.onPrimary.toArgb()
    val secondaryColorInt = MaterialTheme.colorScheme.secondary.toArgb()
    val onSecondaryColorInt = MaterialTheme.colorScheme.onSecondary.toArgb()
    val surfaceColorInt = MaterialTheme.colorScheme.surface.toArgb()
    val outlineColorInt = MaterialTheme.colorScheme.outline.toArgb()

    val cacheManager = remember { MapAndMarkerCacheManager.getInstance(context) }

    // Animate map camera to active venue once when activeVenue selection changes
    LaunchedEffect(activeVenue?.id) {
        activeVenue?.let { v ->
            mapViewInstance?.let { mv ->
                PerformanceTracer.traceMapRender("AnimateMapCamera") {
                    android.util.Log.d("MapDebug", "RealMapViewComponent: Animating camera to venue ${v.name} (${v.latitude}, ${v.longitude})")
                    mv.controller.animateTo(GeoPoint(v.latitude, v.longitude))
                }
            }
        }
    }

    // Safely manage overlays and markers without main-thread allocation loops
    LaunchedEffect(venues, activeVenue?.id, primaryColorInt, mapViewInstance) {
        val mapView = mapViewInstance ?: return@LaunchedEffect
        PerformanceTracer.traceMapRender("UpdateVenueMarkers") {
            android.util.Log.d("MapDebug", "RealMapViewComponent: Updating ${venues.size} venue markers on map")
            
            // Generate/retrieve all venue marker bitmaps off the UI thread
            val markersList = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {
                venues.map { venue ->
                    val isSelected = venue.id == activeVenue?.id
                    val cacheKey = "${venue.id}_${isSelected}_${venue.pricingBaseAmount}_${primaryColorInt}_${onPrimaryColorInt}_${secondaryColorInt}_${onSecondaryColorInt}_${surfaceColorInt}_${outlineColorInt}"
                    
                    val bitmap = cacheManager.getOrGenerateMarker(
                        key = cacheKey,
                        venueId = venue.id,
                        isSelected = isSelected,
                        priceAmount = venue.pricingBaseAmount,
                        generator = {
                            createDynamicThemeMapMarkerBitmap(
                                context = context,
                                priceAmount = venue.pricingBaseAmount,
                                isSelected = isSelected,
                                primaryColorInt = primaryColorInt,
                                onPrimaryColorInt = onPrimaryColorInt,
                                secondaryColorInt = secondaryColorInt,
                                onSecondaryColorInt = onSecondaryColorInt,
                                surfaceColorInt = surfaceColorInt,
                                outlineColorInt = outlineColorInt
                            )
                        }
                    )
                    Triple(venue, isSelected, bitmap)
                }
            }

            // Batched main-thread overlay assignment
            mapView.overlays.clear()
            markersList.forEach { (venue, isSelected, cachedBitmap) ->
                val marker = Marker(mapView).apply {
                    position = GeoPoint(venue.latitude, venue.longitude)
                    title = venue.name
                    snippet = "₹%,d • ${venue.fullAddress}".format(venue.pricingBaseAmount.toInt())
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    icon = BitmapDrawable(context.resources, cachedBitmap)

                    setOnMarkerClickListener { _, _ ->
                        if (activeVenue?.id != venue.id) {
                            activeVenue = venue
                            onVenueSelect(venue)
                        }
                        true
                    }
                }
                mapView.overlays.add(marker)
            }

            mapView.invalidate()
        }
    }

    Card(
        modifier = modifier
            .fillMaxWidth()
            .shadow(6.dp, shape = RoundedCornerShape(16.dp)),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            // MapComponent rendering REAL OpenStreetMap tiles with lifecycle support
            MapComponent(
                centerLatitude = activeVenue?.latitude ?: initialCenterLat,
                centerLongitude = activeVenue?.longitude ?: initialCenterLng,
                zoomLevel = currentZoom,
                onMapReady = { mapViewInstance = it },
                onMapUpdate = {},
                modifier = Modifier.fillMaxSize()
            )

            // Top Info Watermark
            Surface(
                color = Color.Black.copy(alpha = 0.7f),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(12.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Map,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "OpenStreetMap • ${venues.size} Real Map Markers",
                        fontSize = 11.sp,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // Map Zoom Controls
            Column(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
            ) {
                FloatingActionButton(
                    onClick = {
                        mapViewInstance?.let {
                            it.controller.zoomIn()
                            currentZoom = it.zoomLevelDouble
                        }
                    },
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = "Zoom In", modifier = Modifier.size(18.dp))
                }
                Spacer(modifier = Modifier.height(6.dp))
                FloatingActionButton(
                    onClick = {
                        mapViewInstance?.let {
                            it.controller.zoomOut()
                            currentZoom = it.zoomLevelDouble
                        }
                    },
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(Icons.Default.Remove, contentDescription = "Zoom Out", modifier = Modifier.size(18.dp))
                }
            }

            // Selected Venue Preview Card (Bottom Floating Overlay)
            activeVenue?.let { venue ->
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .padding(12.dp)
                        .clickable { onNavigateToVenueDetails(venue.id) },
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surface,
                    shadowElevation = 8.dp
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Venue Image Thumbnail using Coil
                        AsyncImage(
                            model = VenueImageResolver.resolveCoverImage(venue),
                            contentDescription = venue.name,
                            modifier = Modifier
                                .size(68.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.surfaceVariant)
                        )

                        Spacer(modifier = Modifier.width(12.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = venue.name,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = "${venue.fullAddress} • ${venue.distanceKm} km",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Surface(
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                    shape = RoundedCornerShape(6.dp)
                                ) {
                                    Text(
                                        text = "★ ${venue.avgRating}",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "₹%,d".format(venue.pricingBaseAmount.toInt()),
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontSize = 13.sp
                                )
                            }
                        }

                        Spacer(modifier = Modifier.width(8.dp))

                        Column(horizontalAlignment = Alignment.End) {
                            Button(
                                onClick = { onNavigateToVenueDetails(venue.id) },
                                shape = RoundedCornerShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                            ) {
                                Text("Details", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            OutlinedIconButton(
                                onClick = {
                                    launchGoogleMapsDirections(context, venue.latitude, venue.longitude, venue.name)
                                },
                                modifier = Modifier.size(32.dp),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Icon(
                                    Icons.Default.Directions,
                                    contentDescription = "Get Directions",
                                    tint = Color(0xFFD84315),
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Generates a custom vector-style Map Pin Drawable dynamically themed with Jetpack Compose
 * [MaterialTheme.colorScheme] tokens. Updates seamlessly whenever the active theme or preset changes.
 */
fun createDynamicThemeMapMarkerBitmap(
    context: Context,
    priceAmount: Double,
    isSelected: Boolean,
    primaryColorInt: Int,
    onPrimaryColorInt: Int,
    secondaryColorInt: Int,
    onSecondaryColorInt: Int,
    surfaceColorInt: Int,
    outlineColorInt: Int
): Bitmap {
    val priceText = when {
        priceAmount >= 1000 -> "₹%.1fk".format(priceAmount / 1000.0).replace(".0k", "k")
        else -> "₹%.0f".format(priceAmount)
    }

    val width = if (isSelected) 150 else 115
    val height = if (isSelected) 84 else 64
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)

    val pinBgColor = if (isSelected) secondaryColorInt else primaryColorInt
    val pinTextColor = if (isSelected) onSecondaryColorInt else onPrimaryColorInt

    // 1. Selection Halo Ring
    if (isSelected) {
        val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = pinBgColor
            alpha = 70
            style = Paint.Style.FILL
        }
        canvas.drawCircle(width / 2f, height - 10f, 20f, haloPaint)
    }

    // 2. Pill Container (Price Badge)
    val badgeHeight = height - 18f
    val rect = RectF(4f, 4f, width - 4f, badgeHeight)
    val radius = badgeHeight / 2f

    val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = pinBgColor
        style = Paint.Style.FILL
    }

    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = surfaceColorInt
        style = Paint.Style.STROKE
        strokeWidth = if (isSelected) 5f else 3.5f
    }

    canvas.drawRoundRect(rect, radius, radius, bgPaint)
    canvas.drawRoundRect(rect, radius, radius, borderPaint)

    // 3. Price Label
    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = pinTextColor
        textSize = if (isSelected) 24f else 19f
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    val textY = rect.centerY() - ((textPaint.descent() + textPaint.ascent()) / 2)
    canvas.drawText(priceText, rect.centerX(), textY, textPaint)

    // 4. Downward Pin Pointer Triangle
    val pointerPath = Path().apply {
        moveTo(width / 2f - 10f, badgeHeight)
        lineTo(width / 2f + 10f, badgeHeight)
        lineTo(width / 2f, height - 2f)
        close()
    }
    canvas.drawPath(pointerPath, bgPaint)
    canvas.drawPath(pointerPath, borderPaint)

    return bitmap
}

fun createDynamicThemeMapMarker(
    context: Context,
    priceAmount: Double,
    isSelected: Boolean,
    primaryColorInt: Int,
    onPrimaryColorInt: Int,
    secondaryColorInt: Int,
    onSecondaryColorInt: Int,
    surfaceColorInt: Int,
    outlineColorInt: Int
): Drawable {
    val bitmap = createDynamicThemeMapMarkerBitmap(
        context, priceAmount, isSelected, primaryColorInt, onPrimaryColorInt,
        secondaryColorInt, onSecondaryColorInt, surfaceColorInt, outlineColorInt
    )
    return BitmapDrawable(context.resources, bitmap)
}
