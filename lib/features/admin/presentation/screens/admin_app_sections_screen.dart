import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/presentation/category_configuration_providers.dart';

class AdminAppSectionsScreen extends ConsumerWidget {
  const AdminAppSectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(appCustomerSectionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('App sections')),
      body: sections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(appCustomerSectionsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.toggle_on_outlined,
              title: 'Using built-in sections',
              message:
                  'The four customer sections remain visible until database configuration is available.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = items[i];
              return SwitchListTile.adaptive(
                secondary: Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                value: item.visible,
                onChanged: (value) async {
                  try {
                    await ref
                        .read(categoryConfigurationRepositoryProvider)
                        .updateSectionVisibility(
                          sectionId: item.id,
                          visible: value,
                        );
                    ref.invalidate(appCustomerSectionsProvider);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
