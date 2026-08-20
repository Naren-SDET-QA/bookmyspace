import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/location_node.dart';
import '../location_providers.dart';

class CascadingLocationValue {
  const CascadingLocationValue({
    this.country,
    this.state,
    this.district,
    this.city,
    this.area,
  });

  final LocationNode? country;
  final LocationNode? state;
  final LocationNode? district;
  final LocationNode? city;
  final LocationNode? area;

  String? get selectedLocationId =>
      area?.id ?? city?.id ?? district?.id ?? state?.id ?? country?.id;

  CascadingLocationValue copyWith({
    LocationNode? country,
    LocationNode? state,
    LocationNode? district,
    LocationNode? city,
    LocationNode? area,
    bool clearState = false,
    bool clearDistrict = false,
    bool clearCity = false,
    bool clearArea = false,
  }) => CascadingLocationValue(
    country: country ?? this.country,
    state: clearState ? null : state ?? this.state,
    district: clearDistrict ? null : district ?? this.district,
    city: clearCity ? null : city ?? this.city,
    area: clearArea ? null : area ?? this.area,
  );
}

class CascadingLocationSelector extends ConsumerWidget {
  const CascadingLocationSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final CascadingLocationValue value;
  final ValueChanged<CascadingLocationValue> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _LocationDropdown(
          label: 'Country',
          level: LocationNodeLevel.country,
          parentId: null,
          selected: value.country,
          compact: compact,
          onSelected: (node) =>
              onChanged(CascadingLocationValue(country: node)),
        ),
        if (value.country != null) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'State / Province',
            level: LocationNodeLevel.stateProvince,
            parentId: value.country!.id,
            selected: value.state,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(country: value.country, state: node),
            ),
          ),
        ],
        if (value.state != null) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'District / County',
            level: LocationNodeLevel.districtCounty,
            parentId: value.state!.id,
            selected: value.district,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(
                country: value.country,
                state: value.state,
                district: node,
              ),
            ),
          ),
        ],
        if (value.district != null ||
            (value.state != null && value.city == null)) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'City / Town',
            level: LocationNodeLevel.cityTown,
            parentId: value.district?.id ?? value.state?.id,
            selected: value.city,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(
                country: value.country,
                state: value.state,
                district: value.district,
                city: node,
              ),
            ),
          ),
        ],
        if (value.city != null) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'Area / Locality',
            level: LocationNodeLevel.areaLocality,
            parentId: value.city!.id,
            selected: value.area,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(
                country: value.country,
                state: value.state,
                district: value.district,
                city: value.city,
                area: node,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LocationDropdown extends ConsumerWidget {
  const _LocationDropdown({
    required this.label,
    required this.level,
    required this.parentId,
    required this.selected,
    required this.onSelected,
    required this.compact,
  });

  final String label;
  final LocationNodeLevel level;
  final String? parentId;
  final LocationNode? selected;
  final ValueChanged<LocationNode> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      locationChildrenProvider((parentId: parentId, level: level)),
    );
    return state.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: 'Could not load locations',
          border: const OutlineInputBorder(),
          isDense: compact,
        ),
        child: TextButton(
          onPressed: () => ref.invalidate(
            locationChildrenProvider((parentId: parentId, level: level)),
          ),
          child: const Text('Retry'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: compact,
            ),
            child: const Text('No locations available'),
          );
        }
        final selectedValue = items.any((item) => item.id == selected?.id)
            ? selected?.id
            : null;
        return DropdownButtonFormField<String>(
          initialValue: selectedValue,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: compact,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item.id, child: Text(item.name)),
          ],
          onChanged: (id) {
            if (id == null) return;
            onSelected(items.firstWhere((item) => item.id == id));
          },
        );
      },
    );
  }
}
