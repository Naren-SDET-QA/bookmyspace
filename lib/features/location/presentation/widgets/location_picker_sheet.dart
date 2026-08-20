import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/search_area.dart';
import 'cascading_location_selector.dart';
import '../location_providers.dart';
import 'map_point_picker.dart';

/// Bottom-sheet location picker.
///
/// Combines device location, free-text place search (Nominatim), quick
/// popular areas and a tap-to-pick map, plus the search radius. Returns
/// the chosen [SearchArea] via `Navigator.pop`.
class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key, required this.initial});

  final SearchArea initial;

  static Future<SearchArea?> show(
    BuildContext context, {
    required SearchArea initial,
  }) {
    return showModalBottomSheet<SearchArea>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LocationPickerSheet(initial: initial),
    );
  }

  @override
  ConsumerState<LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  late SearchArea _area;
  final _searchController = TextEditingController();
  Timer? _debounce;
  LatLng _mapPoint = LatLng(
    SearchArea.defaultArea.latitude,
    SearchArea.defaultArea.longitude,
  );
  bool _locating = false;
  String _locationError = '';
  CascadingLocationValue _hierarchy = const CascadingLocationValue();

  @override
  void initState() {
    super.initState();
    _area = widget.initial;
    _mapPoint = LatLng(_area.latitude, _area.longitude);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || value.trim().isEmpty) return;
      ref.invalidate(geocodePlaceProvider(value.trim()));
    });
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _locating = true;
      _locationError = '';
    });
    ref.invalidate(deviceLocationProvider);
    try {
      final area = await ref.read(deviceLocationProvider.future);
      if (!mounted) return;
      setState(() {
        _area = area;
        _mapPoint = LatLng(area.latitude, area.longitude);
        _locating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError =
            'Could not access your location. Please pick it on the map.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final geocode = ref.watch(
      geocodePlaceProvider(_searchController.text.trim()),
    );
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Location & Search Area',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            CascadingLocationSelector(
              value: _hierarchy,
              compact: true,
              onChanged: (value) {
                final selected =
                    value.area ??
                    value.city ??
                    value.district ??
                    value.state ??
                    value.country;
                if (selected == null) return;
                setState(() {
                  _hierarchy = value;
                  _area = _area.copyWith(
                    label: selected.name,
                    locationNodeId: value.selectedLocationId,
                    countryCode: selected.countryCode,
                    country: value.country?.name,
                    state: value.state?.name,
                    district: value.district?.name,
                    city: value.city?.name,
                    area: value.area?.name,
                    timezone: selected.timezone,
                    latitude: selected.latitude,
                    longitude: selected.longitude,
                  );
                  if (selected.latitude != null && selected.longitude != null) {
                    _mapPoint = LatLng(selected.latitude!, selected.longitude!);
                  }
                });
              },
            ),

            const SizedBox(height: 12),

            // Free-text place search
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search area, locality or landmark…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.invalidate(geocodePlaceProvider(''));
                        },
                      )
                    : null,
              ),
            ),
            if (_searchController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              geocode.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text(
                  'Could not find that place. Try the map below.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                data: (area) {
                  if (area == null) {
                    return const Text('No matches found. Try the map below.');
                  }
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_rounded),
                    title: Text(
                      area.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.check_circle_rounded),
                    onTap: () {
                      setState(() {
                        _area = area;
                        _mapPoint = LatLng(area.latitude, area.longitude);
                      });
                    },
                  );
                },
              ),
            ],

            const SizedBox(height: 8),

            // Device location + radius
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useDeviceLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(l10n.useMyLocation),
                  ),
                ),
              ],
            ),
            if (_locationError.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _locationError,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),

            // Map picker
            MapPointPicker(
              initial: _mapPoint,
              onPicked: (point) {
                setState(() {
                  _mapPoint = point;
                  _area = SearchArea(
                    label:
                        '${point.latitude.toStringAsFixed(4)}, '
                        '${point.longitude.toStringAsFixed(4)}',
                    latitude: point.latitude,
                    longitude: point.longitude,
                    radiusKm: _area.radiusKm,
                  );
                });
                ref.invalidate(
                  reverseGeocodeProvider((point.latitude, point.longitude)),
                );
              },
            ),
            const SizedBox(height: 4),
            ref
                .watch(
                  reverseGeocodeProvider((
                    _mapPoint.latitude,
                    _mapPoint.longitude,
                  )),
                )
                .when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (label) => Text(
                    'Selected: $label',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

            const SizedBox(height: 12),

            // Quick areas
            Text(
              'Popular Areas',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SearchArea.popularAreas.map((area) {
                final selected = area.label == _area.label;
                return ChoiceChip(
                  label: Text(area.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _area = area.copyWith(radiusKm: _area.radiusKm);
                      _mapPoint = LatLng(area.latitude, area.longitude);
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Search radius
            Text(
              'Search Radius',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SearchArea.radiusOptions.map((km) {
                final selected = _area.radiusKm == km;
                return ChoiceChip(
                  label: Text('Within $km km'),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _area = _area.copyWith(radiusKm: km)),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _area),
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.apply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
