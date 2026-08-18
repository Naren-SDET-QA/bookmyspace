package com.bookmyspace.bookmyspace.ui.screens

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color as AndroidColor
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.toArgb
import com.bookmyspace.bookmyspace.data.model.CustomerSection
import com.bookmyspace.bookmyspace.data.model.CustomerSectionCatalog
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.map.DefaultMapConfiguration
import com.bookmyspace.bookmyspace.map.MapAndMarkerCacheManager
import com.bookmyspace.bookmyspace.ui.components.MapComponent
import com.bookmyspace.bookmyspace.ui.components.RatingBadge
import com.bookmyspace.bookmyspace.ui.components.VenueFilterBottomSheet
import com.bookmyspace.bookmyspace.ui.components.VenueImageCarousel
import com.bookmyspace.bookmyspace.ui.components.VenueMapSkeleton
import com.bookmyspace.bookmyspace.ui.components.createDynamicThemeMapMarker
import com.bookmyspace.bookmyspace.ui.components.createDynamicThemeMapMarkerBitmap
import com.bookmyspace.bookmyspace.ui.components.defaultAmenityFilterOptions
import com.bookmyspace.bookmyspace.util.PerformanceTracer
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import kotlin.math.*

/**
 * Dedicated Interactive Venue Map Screen powered by osmdroid (OpenStreetMap).
 * Displays available venues on an interactive tile map near user location with pins,
 * category filtering, distance calculations, zoom controls, and interactive venue preview cards.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VenueMapScreen(
    onNavigateToVenue: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val allVenues: List<Venue> by BookMySpaceRepository.venues.collectAsState()

    // Default user location (Hitec City, Hyderabad - central venue hub)
    val userLocation = remember { GeoPoint(17.4483, 78.3915) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedCategoryFilter by remember { mutableStateOf("all") }
    var radiusKmFilter by remember { mutableIntStateOf(25) }
    var selectedTileSource by remember { mutableStateOf("Standard") }

    var activeVenue by remember { mutableStateOf<Venue?>(null) }
    var mapViewInstance by remember { mutableStateOf<MapView?>(null) }
    var showRadiusDropdown by remember { mutableStateOf(false) }
    var showFilterBottomSheet by remember { mutableStateOf(false) }
    var minPriceFilter by remember { mutableFloatStateOf(0f) }
    var maxPriceFilter by remember { mutableFloatStateOf(100000f) }
    var minRatingFilter by remember { mutableFloatStateOf(0f) }
    var selectedAmenitiesFilter by remember { mutableStateOf<Set<String>>(emptySet()) }

    // Dynamic Theme Color Integers for osmdroid pins
    val primaryColorInt = MaterialTheme.colorScheme.primary.toArgb()
    val onPrimaryColorInt = MaterialTheme.colorScheme.onPrimary.toArgb()
    val secondaryColorInt = MaterialTheme.colorScheme.secondary.toArgb()
    val onSecondaryColorInt = MaterialTheme.colorScheme.onSecondary.toArgb()
    val surfaceColorInt = MaterialTheme.colorScheme.surface.toArgb()
    val outlineColorInt = MaterialTheme.colorScheme.outline.toArgb()

    val selectedSection by BookMySpaceRepository.selectedCustomerSection.collectAsState()
    val selectedSectionCategory by BookMySpaceRepository.selectedCustomerCategorySlug.collectAsState()

    val categoryChips = remember(selectedSection) {
        if (selectedSection == null) {
            CustomerSection.entries.map { QuickFilterChip(it.id, it.title, it.emoji) }
        } else {
            selectedSection!!.categories.map { QuickFilterChip(it.id, it.label, it.emoji) }
        }
    }

    LaunchedEffect(selectedSection, selectedSectionCategory) {
        if (selectedSection != null && selectedCategoryFilter == "all") {
            selectedCategoryFilter = selectedSectionCategory
        }
    }

    // Filter venues based on user search query, category filter, radius distance, price range, min rating & amenities
    val filteredVenues: List<Venue> = remember(allVenues, searchQuery, selectedCategoryFilter, radiusKmFilter, userLocation, minPriceFilter, maxPriceFilter, minRatingFilter, selectedAmenitiesFilter, selectedSection) {
        allVenues.filter { v: Venue ->
            val distKm = calculateDistanceKm(userLocation.latitude, userLocation.longitude, v.latitude, v.longitude)
            val matchesRadius = distKm <= radiusKmFilter

            val matchesSearch = searchQuery.isBlank() ||
                    v.name.contains(searchQuery, ignoreCase = true) ||
                    v.description.contains(searchQuery, ignoreCase = true) ||
                    v.city.contains(searchQuery, ignoreCase = true) ||
                    v.fullAddress.contains(searchQuery, ignoreCase = true)

            val matchesCategory = if (selectedSection != null) {
                CustomerSectionCatalog.matchesVenue(v, selectedSection!!, selectedCategoryFilter)
            } else {
                val chipSection = CustomerSection.fromId(selectedCategoryFilter)
                if (chipSection != null) {
                    CustomerSectionCatalog.matchesVenue(v, chipSection, "all")
                } else {
                    false
                }
            }

            val matchesPrice = v.pricingBaseAmount >= minPriceFilter && v.pricingBaseAmount <= maxPriceFilter
            val matchesRating = minRatingFilter == 0f || v.avgRating >= minRatingFilter
            val matchesAmenities = selectedAmenitiesFilter.isEmpty() || selectedAmenitiesFilter.all { amenityId ->
                val option = defaultAmenityFilterOptions.find { it.id == amenityId }
                if (option == null) true
                else option.keywords.any { kw ->
                    v.facilities.any { f -> f.facility.contains(kw, ignoreCase = true) && f.isAvailable } ||
                            v.description.contains(kw, ignoreCase = true)
                }
            }

            matchesRadius && matchesSearch && matchesCategory && matchesPrice && matchesRating && matchesAmenities
        }
    }

    val cacheManager = remember { MapAndMarkerCacheManager.getInstance(context) }

    // Auto-select first venue if activeVenue is null or not in current filtered list
    LaunchedEffect(filteredVenues) {
        if (activeVenue == null || filteredVenues.none { it.id == activeVenue?.id }) {
            activeVenue = filteredVenues.firstOrNull()
        }
    }    // Animate map camera smoothly when activeVenue selection changes
    LaunchedEffect(activeVenue?.id) {
        activeVenue?.let { venue ->
            mapViewInstance?.let { mv ->
                PerformanceTracer.traceMapRender("AnimateMapScreenCamera") {
                    android.util.Log.d("MapDebug", "VenueMapScreen: Animating camera to venue ${venue.name} (${venue.latitude}, ${venue.longitude})")
                    mv.controller.animateTo(GeoPoint(venue.latitude, venue.longitude))
                }
            }
        }
    }

    // Safely update map overlays and tile sources when filtered venues, active selection, or theme changes
    LaunchedEffect(filteredVenues, activeVenue?.id, selectedTileSource, userLocation, primaryColorInt, mapViewInstance) {
        val mv = mapViewInstance ?: return@LaunchedEffect
        PerformanceTracer.traceMapRender("UpdateVenueMapScreenMarkers") {
            android.util.Log.d("MapDebug", "VenueMapScreen: Updating ${filteredVenues.size} venue markers")
            mv.overlays.clear()

            // Tile source switch
            if (selectedTileSource == "Topo") {
                mv.setTileSource(TileSourceFactory.USGS_SAT)
            } else {
                mv.setTileSource(TileSourceFactory.MAPNIK)
            }

            // 📍 User Location Marker ("You are here" blue pulsing pin)
            val userMarker = Marker(mv).apply {
                position = userLocation
                title = "Your Current Location"
                snippet = "Near Hitec City, Hyderabad"
                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)

                val userIcon = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(AndroidColor.parseColor("#2196F3"))
                    setStroke(6, AndroidColor.WHITE)
                    setSize(56, 56)
                }
                icon = userIcon
            }
            mv.overlays.add(userMarker)

            // 🏟️ Markers for all filtered venues generated off UI thread
            val markersList = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {
                filteredVenues.map { venue: Venue ->
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

            markersList.forEach { (venue, isSelected, cachedBitmap) ->
                val marker = Marker(mv).apply {
                    position = GeoPoint(venue.latitude, venue.longitude)
                    title = venue.name
                    snippet = "₹%,d • ${venue.fullAddress}".format(venue.pricingBaseAmount.toInt())
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    icon = BitmapDrawable(context.resources, cachedBitmap)

                    setOnMarkerClickListener { _, _ ->
                        if (activeVenue?.id != venue.id) {
                            activeVenue = venue
                        }
                        true
                    }
                }
                mv.overlays.add(marker)
            }

            mv.invalidate()
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .testTag("venue_map_screen_root")
    ) {
        // 1. Interactive osmdroid Map Canvas
        MapComponent(
            centerLatitude = activeVenue?.latitude ?: userLocation.latitude,
            centerLongitude = activeVenue?.longitude ?: userLocation.longitude,
            zoomLevel = DefaultMapConfiguration.DEFAULT_ZOOM,
            onMapReady = { mv ->
                mapViewInstance = mv
            },
            onMapUpdate = {},
            modifier = Modifier.fillMaxSize()
        )

        // 2. Top Header Controls (Search Bar & Quick Category Filters)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .background(
                    color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f)
                )
                .padding(bottom = 8.dp)
        ) {
            // Search Input Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Search venues on map...", fontSize = 13.sp) },
                    leadingIcon = {
                        Icon(
                            Icons.Default.Search,
                            contentDescription = "Search",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp)
                        )
                    },
                    trailingIcon = {
                        if (searchQuery.isNotEmpty()) {
                            IconButton(onClick = { searchQuery = "" }) {
                                Icon(Icons.Default.Close, contentDescription = "Clear search", modifier = Modifier.size(18.dp))
                            }
                        }
                    },
                    singleLine = true,
                    shape = RoundedCornerShape(24.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surface,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surface
                    ),
                    modifier = Modifier
                        .weight(1f)
                        .height(50.dp)
                        .testTag("map_search_input")
                )

                Spacer(modifier = Modifier.width(8.dp))

                // Radius Filter Menu Button
                Box {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(20.dp),
                        modifier = Modifier
                            .height(50.dp)
                            .clickable { showRadiusDropdown = true }
                            .testTag("map_radius_filter_button")
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.NearMe,
                                contentDescription = "Radius",
                                tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "${radiusKmFilter}km",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        }
                    }

                    DropdownMenu(
                        expanded = showRadiusDropdown,
                        onDismissRequest = { showRadiusDropdown = false }
                    ) {
                        listOf(5, 10, 25, 50, 100).forEach { r ->
                            DropdownMenuItem(
                                text = { Text("Within $r km", fontSize = 13.sp) },
                                onClick = {
                                    radiusKmFilter = r
                                    showRadiusDropdown = false
                                },
                                leadingIcon = {
                                    if (radiusKmFilter == r) {
                                        Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                                    }
                                }
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.width(6.dp))

                // Bottom Sheet Filter Button
                val activeMapFilterCount = (if (minPriceFilter > 0f || maxPriceFilter < 100000f) 1 else 0) +
                        (if (minRatingFilter > 0f) 1 else 0) +
                        selectedAmenitiesFilter.size

                Surface(
                    color = if (activeMapFilterCount > 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier
                        .height(50.dp)
                        .clickable { showFilterBottomSheet = true }
                        .testTag("map_filter_bottom_sheet_button")
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.FilterList,
                            contentDescription = "Filters",
                            tint = if (activeMapFilterCount > 0) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(18.dp)
                        )
                        if (activeMapFilterCount > 0) {
                            Spacer(modifier = Modifier.width(4.dp))
                            Surface(
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.size(18.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Text(
                                        text = "$activeMapFilterCount",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Category Filter Chips
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.testTag("map_category_chips")
            ) {
                items(categoryChips, key = { it.id }) { chip ->
                    val isSelected = selectedCategoryFilter == chip.id
                    FilterChip(
                        selected = isSelected,
                        onClick = {
                            if (selectedSection == null) {
                                CustomerSection.fromId(chip.id)?.let {
                                    BookMySpaceRepository.setSelectedCustomerSection(it)
                                }
                                selectedCategoryFilter = "all"
                            } else {
                                selectedCategoryFilter = chip.id
                                BookMySpaceRepository.setSelectedCustomerCategory(chip.id)
                            }
                        },
                        label = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(chip.emoji, fontSize = 13.sp)
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = chip.label,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                                )
                            }
                        },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primary,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                        ),
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier.height(32.dp)
                    )
                }
            }
        }

        // 3. Floating Action Map Control Buttons (Recenter, Zoom In, Zoom Out, Tile Toggle)
        Column(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 16.dp)
                .offset(y = (-40).dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SmallFloatingActionButton(
                onClick = {
                    mapViewInstance?.let { mv ->
                        mv.controller.animateTo(userLocation)
                        mv.controller.setZoom(14.0)
                    }
                },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.primary,
                modifier = Modifier.testTag("recenter_my_location_button")
            ) {
                Icon(Icons.Default.MyLocation, contentDescription = "Recenter to My Location")
            }

            SmallFloatingActionButton(
                onClick = {
                    mapViewInstance?.let { mv ->
                        mv.controller.zoomIn()
                    }
                },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.testTag("zoom_in_button")
            ) {
                Icon(Icons.Default.Add, contentDescription = "Zoom In")
            }

            SmallFloatingActionButton(
                onClick = {
                    mapViewInstance?.let { mv ->
                        mv.controller.zoomOut()
                    }
                },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.testTag("zoom_out_button")
            ) {
                Icon(Icons.Default.Remove, contentDescription = "Zoom Out")
            }

            SmallFloatingActionButton(
                onClick = {
                    selectedTileSource = if (selectedTileSource == "Standard") "Topo" else "Standard"
                },
                containerColor = if (selectedTileSource == "Topo") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
                contentColor = if (selectedTileSource == "Topo") MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.testTag("tile_switcher_button")
            ) {
                Icon(Icons.Default.Layers, contentDescription = "Toggle Map Style")
            }
        }

        // Top-Left Watermark Badge
        Surface(
            color = Color.Black.copy(alpha = 0.75f),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 16.dp, top = 120.dp)
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Map,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "${filteredVenues.size} Available Spaces Nearby",
                    fontSize = 11.sp,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        // 4. Bottom Selected Venue Interactive Preview Card
        AnimatedVisibility(
            visible = activeVenue != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            activeVenue?.let { venue ->
                val distanceKm = calculateDistanceKm(
                    userLocation.latitude,
                    userLocation.longitude,
                    venue.latitude,
                    venue.longitude
                )

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .shadow(12.dp, shape = RoundedCornerShape(20.dp))
                        .testTag("active_venue_preview_card"),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        // Venue Image Header Carousel
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(160.dp)
                        ) {
                            VenueImageCarousel(
                                venue = venue,
                                height = 160.dp,
                                showCaptions = false,
                                showFullscreenButton = false,
                                showNavButtons = false,
                                onImageClick = { onNavigateToVenue(venue.id) }
                            )

                            // Save Favorite Bookmark Button
                            IconButton(
                                onClick = { BookMySpaceRepository.toggleSaved(venue.id) },
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .padding(8.dp)
                                    .background(Color.Black.copy(alpha = 0.5f), CircleShape)
                            ) {
                                Icon(
                                    imageVector = if (venue.isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                                    contentDescription = "Save Venue",
                                    tint = if (venue.isSaved) MaterialTheme.colorScheme.primary else Color.White,
                                    modifier = Modifier.size(20.dp)
                                )
                            }

                            // Distance Badge
                            Surface(
                                color = Color.Black.copy(alpha = 0.75f),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier
                                    .align(Alignment.BottomStart)
                                    .padding(10.dp)
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.NearMe,
                                        contentDescription = null,
                                        tint = Color.White,
                                        modifier = Modifier.size(12.dp)
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "%.1f km away".format(distanceKm),
                                        fontSize = 11.sp,
                                        color = Color.White,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }

                        // Venue Details Body
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = venue.name,
                                        fontSize = 17.sp,
                                        fontWeight = FontWeight.Bold,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = venue.fullAddress,
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }

                                Spacer(modifier = Modifier.width(8.dp))

                                RatingBadge(rating = venue.avgRating, count = venue.ratingCount)
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            // Pricing & Action Buttons
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(
                                        text = "Starting from",
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = "₹%,d / hr".format(venue.pricingBaseAmount.toInt()),
                                        fontSize = 16.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }

                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    OutlinedButton(
                                        onClick = {
                                            val geoUri = Uri.parse("geo:${venue.latitude},${venue.longitude}?q=${venue.latitude},${venue.longitude}(${Uri.encode(venue.name)})")
                                            val intent = Intent(Intent.ACTION_VIEW, geoUri)
                                            context.startActivity(intent)
                                        },
                                        shape = RoundedCornerShape(12.dp),
                                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                                    ) {
                                        Icon(Icons.Default.Directions, contentDescription = "Directions", modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Directions", fontSize = 12.sp)
                                    }

                                    Button(
                                        onClick = { onNavigateToVenue(venue.id) },
                                        shape = RoundedCornerShape(12.dp),
                                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
                                        modifier = Modifier.testTag("map_venue_book_button")
                                    ) {
                                        Text("Book Space", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Icon(Icons.Default.ArrowForward, contentDescription = null, modifier = Modifier.size(14.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Skeleton overlay while map tiles / data load
        AnimatedVisibility(
            visible = allVenues.isEmpty(),
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            VenueMapSkeleton(modifier = Modifier.fillMaxSize())
        }

        // Venue Filter Bottom Sheet
        if (showFilterBottomSheet) {
            VenueFilterBottomSheet(
                initialMinPrice = minPriceFilter,
                initialMaxPrice = maxPriceFilter,
                initialMinRating = minRatingFilter,
                initialSelectedAmenities = selectedAmenitiesFilter,
                maxPriceLimit = 100000f,
                totalVenuesCount = allVenues.size,
                matchingVenuesCount = filteredVenues.size,
                onDismissRequest = { showFilterBottomSheet = false },
                onApplyFilters = { newMinPrice, newMaxPrice, newMinRating, newSelectedAmenities ->
                    minPriceFilter = newMinPrice
                    maxPriceFilter = newMaxPrice
                    minRatingFilter = newMinRating
                    selectedAmenitiesFilter = newSelectedAmenities
                },
                onResetFilters = {
                    minPriceFilter = 0f
                    maxPriceFilter = 100000f
                    minRatingFilter = 0f
                    selectedAmenitiesFilter = emptySet()
                }
            )
        }
    }
}

/**
 * Calculates distance in kilometers between two geo coordinates using Haversine formula.
 */
private fun calculateDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val r = 6371.0 // Earth radius in km
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = sin(dLat / 2).pow(2.0) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
            sin(dLon / 2).pow(2.0)
    val c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return r * c
}

/**
 * Returns integer color hex based on venue category.
 */
private fun getCategoryPinColorInt(categoryName: String?): Int {
    val name = categoryName?.lowercase() ?: ""
    return when {
        name.contains("sport") || name.contains("turf") || name.contains("ground") -> AndroidColor.parseColor("#4CAF50") // Green
        name.contains("meeting") || name.contains("office") || name.contains("conference") -> AndroidColor.parseColor("#2196F3") // Blue
        name.contains("pg") || name.contains("hostel") || name.contains("co-living") -> AndroidColor.parseColor("#FF9800") // Orange
        name.contains("hotel") || name.contains("stay") || name.contains("resort") -> AndroidColor.parseColor("#9C27B0") // Purple
        else -> AndroidColor.parseColor("#673AB7") // Deep Purple
    }
}
