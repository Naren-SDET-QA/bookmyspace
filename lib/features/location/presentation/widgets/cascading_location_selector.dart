import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/location_node.dart';
import '../location_providers.dart';

class CascadingLocationValue {
  const CascadingLocationValue({
    this.country,
    this.state,
    this.district,
    this.mandal,
    this.city,
    this.village,
    this.area,
  });

  final LocationNode? country;
  final LocationNode? state;
  final LocationNode? district;
  final LocationNode? mandal;
  final LocationNode? city;
  final LocationNode? village;
  final LocationNode? area;

  /// Builds a selector value from an ordered country-to-leaf path.
  ///
  /// Paths may skip levels (for example, district → city), and future or
  /// unknown levels are ignored rather than being forced into a category.
  factory CascadingLocationValue.fromPath(Iterable<LocationNode> path) {
    LocationNode? country;
    LocationNode? state;
    LocationNode? district;
    LocationNode? mandal;
    LocationNode? city;
    LocationNode? village;
    LocationNode? area;
    for (final node in path) {
      switch (node.level) {
        case LocationNodeLevel.country:
          country = node;
        case LocationNodeLevel.stateProvince:
          state = node;
        case LocationNodeLevel.districtCounty:
          district = node;
        case LocationNodeLevel.mandalTalukTehsilBlock:
          mandal = node;
        case LocationNodeLevel.cityTown:
          city = node;
        case LocationNodeLevel.village:
          village = node;
        case LocationNodeLevel.areaLocality:
          area = node;
        case LocationNodeLevel.unknown:
          break;
      }
    }
    return CascadingLocationValue(
      country: country,
      state: state,
      district: district,
      mandal: mandal,
      city: city,
      village: village,
      area: area,
    );
  }

  String? get selectedLocationId =>
      area?.id ??
      village?.id ??
      city?.id ??
      mandal?.id ??
      district?.id ??
      state?.id ??
      country?.id;

  List<String> get pathNames => [
    country,
    state,
    district,
    mandal,
    city ?? village,
    area,
  ].whereType<LocationNode>().map((node) => node.name).toList(growable: false);

  CascadingLocationValue copyWith({
    LocationNode? country,
    LocationNode? state,
    LocationNode? district,
    LocationNode? mandal,
    LocationNode? city,
    LocationNode? village,
    LocationNode? area,
    bool clearState = false,
    bool clearDistrict = false,
    bool clearMandal = false,
    bool clearCity = false,
    bool clearVillage = false,
    bool clearArea = false,
  }) => CascadingLocationValue(
    country: country ?? this.country,
    state: clearState ? null : state ?? this.state,
    district: clearDistrict ? null : district ?? this.district,
    mandal: clearMandal ? null : mandal ?? this.mandal,
    city: clearCity ? null : city ?? this.city,
    village: clearVillage ? null : village ?? this.village,
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
            label: 'State / UT',
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
            label: 'District',
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
        if (value.district != null) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'Mandal / Taluk / Tehsil / Block',
            level: LocationNodeLevel.mandalTalukTehsilBlock,
            parentId: value.district!.id,
            selected: value.mandal,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(
                country: value.country,
                state: value.state,
                district: value.district,
                mandal: node,
              ),
            ),
          ),
        ],
        if (value.state != null) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'Town / City',
            level: LocationNodeLevel.cityTown,
            parentId: value.mandal?.id ?? value.district?.id ?? value.state!.id,
            selected: value.city,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(
                country: value.country,
                state: value.state,
                district: value.district,
                mandal: value.mandal,
                city: node,
              ),
            ),
          ),
        ],
        if (value.district != null || value.mandal != null) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'Village',
            level: LocationNodeLevel.village,
            parentId: value.mandal?.id ?? value.district?.id,
            selected: value.village,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(
                country: value.country,
                state: value.state,
                district: value.district,
                mandal: value.mandal,
                village: node,
              ),
            ),
          ),
        ],
        if (value.city != null || value.village != null) ...[
          const SizedBox(height: 12),
          _LocationDropdown(
            label: 'Locality',
            level: LocationNodeLevel.areaLocality,
            parentId: (value.city ?? value.village)!.id,
            selected: value.area,
            compact: compact,
            onSelected: (node) => onChanged(
              CascadingLocationValue(
                country: value.country,
                state: value.state,
                district: value.district,
                mandal: value.mandal,
                city: value.city,
                village: value.village,
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
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: compact,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: compact ? 140 : 200),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    ChoiceChip(
                      label: Text(item.name),
                      selected: selected?.id == item.id,
                      onSelected: (_) => onSelected(item),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
