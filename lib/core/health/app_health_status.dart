import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_health.dart';

class AppHealthStatusWidget extends ConsumerWidget {
  const AppHealthStatusWidget({super.key, this.onGoHome});

  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(appHealthProvider);
    return health.when(
      // Keep checks in the background; a persistent "healthy/checking"
      // bar clips the Android status bar and doubles home top inset.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _HealthMessage(
        icon: Icons.error_outline,
        title: 'Some services are temporarily unavailable.',
        message: 'Please try again.',
        retry: () => ref.invalidate(appHealthProvider),
        onGoHome: onGoHome,
      ),
      data: (snapshot) {
        final criticalFailure = snapshot.results.entries.any(
          (entry) =>
              entry.value.status == AppHealthStatus.failed &&
              entry.key == 'supabase',
        );
        if (criticalFailure) {
          return _HealthMessage(
            icon: Icons.error_outline,
            title: 'Some services are temporarily unavailable.',
            message: 'Please try again or return home.',
            retry: () => ref.invalidate(appHealthProvider),
            onGoHome: onGoHome,
          );
        }
        if (snapshot.status == AppHealthStatus.degraded ||
            snapshot.status == AppHealthStatus.failed) {
          return _HealthMessage(
            icon: Icons.warning_amber_rounded,
            title: 'Some features may be temporarily unavailable.',
            message: 'The application remains available.',
            retry: () => ref.invalidate(appHealthProvider),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _HealthMessage extends StatelessWidget {
  const _HealthMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.retry,
    this.onGoHome,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? retry;
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $message',
      child: Card(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, semanticLabel: title),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (retry != null || onGoHome != null)
                      Wrap(
                        spacing: 8,
                        children: [
                          if (retry != null)
                            TextButton(
                              onPressed: retry,
                              child: const Text('Retry'),
                            ),
                          if (onGoHome != null)
                            TextButton(
                              onPressed: onGoHome,
                              child: const Text('Go Home'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
