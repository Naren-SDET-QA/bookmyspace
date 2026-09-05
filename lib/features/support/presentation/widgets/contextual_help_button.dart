import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/offline/offline_providers.dart';
import '../../domain/contextual_help.dart';

class ContextualHelpButton extends ConsumerWidget {
  const ContextualHelpButton({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = ContextualHelpCatalog.forRoute(route);
    if (topic == null) return const SizedBox.shrink();
    return IconButton(
      key: const Key('contextual_help_button'),
      tooltip: 'Help',
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => showContextualHelp(context, ref, topic),
    );
  }
}

Future<void> showContextualHelp(
  BuildContext context,
  WidgetRef ref,
  ContextualHelpTopic topic,
) async {
  final store = ref.read(contextualHelpStoreProvider);
  final dismissed = await store.isDismissed(topic.id);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(topic.body),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!dismissed)
                  TextButton(
                    onPressed: () async {
                      await store.dismiss(topic.id);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Hide next time'),
                  ),
                if (dismissed)
                  TextButton(
                    onPressed: () async {
                      await store.restore(topic.id);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Show again later'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
