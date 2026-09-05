import 'package:flutter/material.dart';

import '../../../venues/domain/category_configuration.dart';
import '../../../venues/domain/category_discovery.dart';

class CategoryCarousel extends StatelessWidget {
  const CategoryCarousel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final List<CategoryConfiguration> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = CategoryDiscovery.carouselItems(items);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        primary: false,
        physics: const ClampingScrollPhysics(),
        clipBehavior: Clip.none,
        addAutomaticKeepAlives: false,
        padding: padding,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = chips[index];
          final isSelected = selectedId == cat.id || selectedId == cat.slug;
          final accent = cat.accentColor ?? theme.colorScheme.primary;
          return FilterChip(
            selected: isSelected,
            onSelected: (_) => onSelected(cat.slug),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Text(
              cat.icon.isNotEmpty ? cat.icon : '•',
              style: const TextStyle(fontSize: 14),
            ),
            label: Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            selectedColor: accent,
            checkmarkColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}
