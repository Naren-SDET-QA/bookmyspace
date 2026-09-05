import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/customer_category_preferences.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/presentation/category_configuration_providers.dart';
import '../customer_category_preferences_providers.dart';

class CustomerCategoryPreferencesScreen extends ConsumerWidget {
  const CustomerCategoryPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(customerCategoryPreferencesProvider);
    final configured = ref.watch(categoryConfigurationsProvider).valueOrNull;
    final categories = configured == null || configured.isEmpty
        ? _fallback()
        : _group(configured);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose what you want to see')),
      body: _Body(preferences: preferences, categories: categories),
    );
  }

  static List<CategoryConfiguration> _group(
    List<CategoryConfiguration> configurations,
  ) {
    final grouped = <String, CategoryConfiguration>{};
    for (final config in configurations.where((item) => item.visible)) {
      final key = config.sectionId.isNotEmpty ? config.sectionId : config.id;
      grouped.putIfAbsent(key, () => config);
    }
    return grouped.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static List<CategoryConfiguration> _fallback() => const [
    CategoryConfiguration(
      id: 'lodge_rooms',
      slug: 'lodge_rooms',
      name: 'Hotels / Rooms',
      sectionId: 'lodge_rooms',
      icon: '🏨',
      sortOrder: 1,
    ),
    CategoryConfiguration(
      id: 'function_halls',
      slug: 'function_halls',
      name: 'Function / Marriage Halls',
      sectionId: 'function_halls',
      icon: '🎉',
      sortOrder: 2,
    ),
    CategoryConfiguration(
      id: 'pg_hostels',
      slug: 'pg_hostels',
      name: 'PG / Hostels',
      sectionId: 'pg_hostels',
      icon: '🏠',
      sortOrder: 3,
    ),
    CategoryConfiguration(
      id: 'institutes_classes',
      slug: 'institutes_classes',
      name: 'Institutes / Classes',
      sectionId: 'institutes_classes',
      icon: '🎓',
      sortOrder: 4,
    ),
  ];
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.preferences, required this.categories});

  final CustomerCategoryPreferences preferences;
  final List<CategoryConfiguration> categories;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late final Map<String, bool> values = {
    for (final entry in widget.preferences.values.entries)
      entry.key: entry.value,
  };

  @override
  void initState() {
    super.initState();
    for (final category in widget.categories) {
      final id = category.sectionId.isNotEmpty
          ? category.sectionId
          : category.id;
      values.putIfAbsent(id, () => true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Choose what you want to see'),
        const SizedBox(height: 12),
        ...widget.categories.map((category) {
          final id = category.sectionId.isNotEmpty
              ? category.sectionId
              : category.id;
          return Card(
            child: SwitchListTile.adaptive(
              secondary: Text(category.icon.isNotEmpty ? category.icon : '✨'),
              title: Text(category.name),
              value: values[id] ?? true,
              onChanged: (value) => setState(() => values[id] = value),
            ),
          );
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                for (final id in values.keys) values[id] = true;
              }),
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () => setState(() {
                for (final id in values.keys) values[id] = false;
                if (values.isNotEmpty) values[values.keys.first] = true;
              }),
              child: const Text('Clear All'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(customerCategoryPreferencesProvider.notifier)
                    .save(values);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Preferences'),
            ),
          ],
        ),
      ],
    );
  }
}
