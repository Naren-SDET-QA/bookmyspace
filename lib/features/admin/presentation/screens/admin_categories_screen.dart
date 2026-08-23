import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/presentation/category_configuration_providers.dart';

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(categoryConfigurationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Category configuration')),
      body: configs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(categoryConfigurationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.category_outlined,
              title: 'No categories',
              message: 'Categories are loaded from the database.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    [
                      item.slug,
                      item.sectionId,
                      item.bookable ? 'bookable' : 'listing',
                      item.bookingMode,
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: Icon(
                    item.visible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onTap: () => _edit(context, ref, item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CategoryConfiguration item,
  ) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(item.toMetadata()),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLines: 18,
            decoration: const InputDecoration(
              labelText: 'Category metadata (JSON)',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      final decoded = jsonDecode(controller.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Metadata must be a JSON object');
      }
      await ref
          .read(categoryConfigurationRepositoryProvider)
          .updateMetadata(categoryId: item.id, metadata: decoded);
      ref.invalidate(categoryConfigurationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
