import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/plugins/map_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Interactive map for choosing a point on the map.
///
/// Tap anywhere to move the pin; the parent receives the new coordinate.
/// Shared by the owner venue form and the customer location picker.
class MapPointPicker extends ConsumerStatefulWidget {
  const MapPointPicker({
    super.key,
    required this.initial,
    required this.onPicked,
    this.height = 240,
    this.initialZoom = 12,
  });

  final LatLng initial;
  final ValueChanged<LatLng> onPicked;
  final double height;
  final double initialZoom;

  @override
  ConsumerState<MapPointPicker> createState() => _MapPointPickerState();
}

class _MapPointPickerState extends ConsumerState<MapPointPicker> {
  MapController? _controller;
  late LatLng _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = resolvedMapProvider(ref.watch(providerRegistryProvider));
    if (map == null) {
      return SizedBox(height: widget.height);
    }
    final controller = _controller ??= map.createController();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: _point,
            initialZoom: widget.initialZoom,
            onTap: (tap, latLng) {
              setState(() => _point = latLng);
              widget.onPicked(latLng);
            },
            interactionOptions: const InteractionOptions(
              flags:
                  InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: map.tileUrlTemplate,
              userAgentPackageName: map.userAgentPackageName,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _point,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: AppTheme.brand,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
