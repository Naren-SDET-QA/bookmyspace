import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/presentation/category_configuration_providers.dart';

/// Android listing-fields config, stored as category metadata on Supabase.
class AdminListingFieldsScreen extends ConsumerWidget {
  const AdminListingFieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(categoryConfigurationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Listing fields')),
      body: configs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(categoryConfigurationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.tune,
              title: 'No category fields',
              message: 'Category configuration is loaded from the database.',
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
                      if (item.requiredFields.isNotEmpty)
                        'required: ${item.requiredFields.join(', ')}',
                      if (item.optionalFields.isNotEmpty)
                        'optional: ${item.optionalFields.join(', ')}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.edit_outlined),
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
    final required = TextEditingController(
      text: item.requiredFields.join(', '),
    );
    final optional = TextEditingController(
      text: item.optionalFields.join(', '),
    );
    final owner = TextEditingController(text: item.ownerFields.join(', '));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.name} fields'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: required,
                decoration: const InputDecoration(
                  labelText: 'Required fields (comma separated)',
                ),
              ),
              TextField(
                controller: optional,
                decoration: const InputDecoration(
                  labelText: 'Optional fields (comma separated)',
                ),
              ),
              TextField(
                controller: owner,
                decoration: const InputDecoration(
                  labelText: 'Owner fields (comma separated)',
                ),
              ),
            ],
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
    List<String> split(String raw) =>
        raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    try {
      final updated = item.copyWith(
        requiredFields: split(required.text),
        optionalFields: split(optional.text),
        ownerFields: split(owner.text),
      );
      await ref
          .read(categoryConfigurationRepositoryProvider)
          .updateMetadata(categoryId: item.id, metadata: updated.toMetadata());
      ref.invalidate(categoryConfigurationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
