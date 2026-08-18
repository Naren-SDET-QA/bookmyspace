package com.bookmyspace.bookmyspace.ui.components

import android.view.MotionEvent
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.bookmyspace.bookmyspace.map.DefaultMapConfiguration
import com.bookmyspace.bookmyspace.map.MapAndMarkerCacheManager
import com.bookmyspace.bookmyspace.map.MapProvider
import com.bookmyspace.bookmyspace.map.OsmTileMapProvider
import com.bookmyspace.bookmyspace.util.PerformanceTracer
import com.bookmyspace.bookmyspace.util.TraceCategory
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.MapTileProviderBasic
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView

/**
 * Lifecycle-aware MapComponent wrapper for osmdroid / OpenStreetMap tile engine.
 * Ensures proper initialization, tile provider configuration, lifecycle cleanup,
 * and disallows parent scroll interception on touch gestures so the map freely moves,
 * pans, and zooms without scrolling parent containers.
 */
@Composable
fun MapComponent(
    modifier: Modifier = Modifier,
    mapProvider: MapProvider = remember { OsmTileMapProvider() },
    centerLatitude: Double = DefaultMapConfiguration.DEFAULT_LATITUDE,
    centerLongitude: Double = DefaultMapConfiguration.DEFAULT_LONGITUDE,
    zoomLevel: Double = DefaultMapConfiguration.DEFAULT_ZOOM,
    onMapReady: (MapView) -> Unit = {},
    onMapUpdate: (MapView) -> Unit = {}
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // Initialize osmdroid user agent configuration
    LaunchedEffect(mapProvider) {
        Configuration.getInstance().userAgentValue = mapProvider.userAgent
    }

    val currentOnMapReady by rememberUpdatedState(onMapReady)
    val currentOnMapUpdate by rememberUpdatedState(onMapUpdate)

    var mapView by remember { mutableStateOf<MapView?>(null) }

    // Lifecycle observer to handle MapView pause/resume/detach safely
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> mapView?.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView?.onPause()
                Lifecycle.Event.ON_DESTROY -> mapView?.onDetach()
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)

        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView?.onDetach()
        }
    }

    AndroidView(
        factory = { ctx ->
            PerformanceTracer.traceSection("InitMapViewFactory", TraceCategory.MAP_RENDER) {
                val cacheManager = MapAndMarkerCacheManager.getInstance(ctx)
                val tileProvider = MapTileProviderBasic(ctx, TileSourceFactory.MAPNIK, cacheManager.roomTileWriter)
                MapView(ctx, tileProvider).apply {
                    setMultiTouchControls(true)
                    maxZoomLevel = mapProvider.maxZoom.toDouble()
                    minZoomLevel = mapProvider.minZoom.toDouble()
                    controller.setZoom(zoomLevel)
                    controller.setCenter(GeoPoint(centerLatitude, centerLongitude))

                    // Disallow parent scroll interception on touch gestures so osmdroid map freely moves
                    setOnTouchListener { v, event ->
                        when (event.actionMasked) {
                            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE, MotionEvent.ACTION_POINTER_DOWN -> {
                                v.parent?.requestDisallowInterceptTouchEvent(true)
                            }
                            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                                v.parent?.requestDisallowInterceptTouchEvent(false)
                            }
                        }
                        false
                    }

                    mapView = this
                    currentOnMapReady(this)
                }
            }
        },
        update = { view ->
            PerformanceTracer.traceSection("UpdateMapView", TraceCategory.MAP_RENDER) {
                currentOnMapUpdate(view)
            }
        },
        modifier = modifier
    )
}
