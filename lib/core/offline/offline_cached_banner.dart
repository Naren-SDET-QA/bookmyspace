import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import 'offline_providers.dart';

/// Shown when browse/search/booking lists were served from a local snapshot
/// because the live request failed. Retry re-runs online fetches.
class OfflineCachedBanner extends ConsumerWidget {
  const OfflineCachedBanner({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(servingCachedDataProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.servingCachedData,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                onRetry?.call();
                ref.read(servingCachedDataProvider.notifier).state = false;
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
