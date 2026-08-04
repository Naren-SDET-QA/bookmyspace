import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../domain/geo_point.dart';
import '../maps_providers.dart';

/// Reusable OSM map: markers, optional GPS, tap-to-pick, address search.
class MapView extends ConsumerStatefulWidget {
  const MapView({
    super.key,
    this.initialCenter,
    this.initialZoom = 14,
    this.markers = const [],
    this.height = 200,
    this.interactive = true,
    this.showUserLocation = false,
    this.pickOnTap = false,
    this.showAddressSearch = false,
    this.onLocationPicked,
    this.borderRadius = 16,
  });

  final GeoPoint? initialCenter;
  final double initialZoom;
  final List<MapMarkerData> markers;
  final double height;
  final bool interactive;
  final bool showUserLocation;
  final bool pickOnTap;
  final bool showAddressSearch;
  final ValueChanged<GeoPoint>? onLocationPicked;
  final double borderRadius;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final MapController _controller = MapController();
  final TextEditingController _searchController = TextEditingController();
  GeoPoint? _picked;
  GeoPoint? _userPoint;
  List<GeocodedPlace> _suggestions = const [];
  bool _searching = false;
  Timer? _debounce;

  GeoPoint get _center =>
      _picked ??
      widget.initialCenter ??
      _userPoint ??
      const GeoPoint(15.5057, 80.0495);

  @override
  void initState() {
    super.initState();
    _picked = widget.initialCenter;
    if (widget.showUserLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _locateUser());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    try {
      final point = await ref.read(locationProvider).currentPosition();
      if (!mounted || point == null) return;
      setState(() => _userPoint = point);
      _controller.move(LatLng(point.latitude, point.longitude), 15);
    } catch (_) {
      // GPS unavailable (tests / missing plugin) — ignore.
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || value.trim().length < 3) {
        setState(() => _suggestions = const []);
        return;
      }
      setState(() => _searching = true);
      try {
        final results = await ref.read(geocodingProvider).searchAddress(value);
        if (mounted) setState(() => _suggestions = results);
      } catch (_) {
        if (mounted) setState(() => _suggestions = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectPlace(GeocodedPlace place) {
    setState(() {
      _picked = place.point;
      _suggestions = const [];
      _searchController.text = place.displayName;
    });
    _controller.move(
      LatLng(place.point.latitude, place.point.longitude),
      15,
    );
    widget.onLocationPicked?.call(place.point);
  }

  void _onTap(TapPosition tapPosition, LatLng latLng) {
    if (!widget.pickOnTap) return;
    final point = GeoPoint(latLng.latitude, latLng.longitude);
    setState(() => _picked = point);
    widget.onLocationPicked?.call(point);
  }

  @override
  Widget build(BuildContext context) {
    final tiles = ref.watch(mapTileProvider);
    final center = LatLng(_center.latitude, _center.longitude);

    final markerPoints = <Marker>[
      ...widget.markers.map(
        (m) => Marker(
          point: LatLng(m.point.latitude, m.point.longitude),
          width: 40,
          height: 40,
          child: Tooltip(
            message: m.label ?? '',
            child: const Icon(
              Icons.location_pin,
              color: AppTheme.brand,
              size: 40,
            ),
          ),
        ),
      ),
      if (_picked != null && widget.pickOnTap)
        Marker(
          point: LatLng(_picked!.latitude, _picked!.longitude),
          width: 40,
          height: 40,
          child: const Icon(
            Icons.place_rounded,
            color: AppTheme.accent,
            size: 40,
          ),
        ),
      if (_userPoint != null && widget.showUserLocation)
        Marker(
          point: LatLng(_userPoint!.latitude, _userPoint!.longitude),
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.brand,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brand.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showAddressSearch) ...[
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search address',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (widget.showUserLocation
                        ? IconButton(
                            tooltip: 'Use my location',
                            icon: const Icon(Icons.my_location_rounded),
                            color: AppTheme.brand,
                            onPressed: _locateUser,
                          )
                        : null),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                borderSide: const BorderSide(color: AppTheme.line),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Material(
              color: AppTheme.card,
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length.clamp(0, 5),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final place = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppTheme.brand,
                    ),
                    title: Text(
                      place.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectPlace(place),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: widget.initialZoom,
                    onTap: widget.pickOnTap ? _onTap : null,
                    interactionOptions: InteractionOptions(
                      flags: widget.interactive
                          ? InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom
                          : InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tiles.urlTemplate,
                      userAgentPackageName: tiles.userAgentPackageName,
                    ),
                    MarkerLayer(markers: markerPoints),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(tiles.attribution),
                      ],
                    ),
                  ],
                ),
                if (widget.showUserLocation && !widget.showAddressSearch)
                  Positioned(
                    right: 8,
                    bottom: 28,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        tooltip: 'My location',
                        icon: const Icon(
                          Icons.my_location_rounded,
                          color: AppTheme.brand,
                        ),
                        onPressed: _locateUser,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
