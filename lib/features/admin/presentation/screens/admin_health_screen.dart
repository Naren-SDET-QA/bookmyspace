import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/health/app_health.dart';

class AdminHealthScreen extends ConsumerWidget {
  const AdminHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(appHealthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('System Health')),
      body: health.when(
        loading: () => const _Checking(),
        error: (_, __) => _DiagnosticError(onRetry: () => ref.invalidate(appHealthProvider)),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(appHealthProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Summary(snapshot: snapshot),
              const SizedBox(height: 12),
              ...snapshot.results.entries.map((entry) => _HealthRow(id: entry.key, result: entry.value)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(appHealthProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Run Diagnostic'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});
  final AppHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final counts = <AppHealthStatus, int>{};
    for (final result in snapshot.results.values) {
      counts[result.status] = (counts[result.status] ?? 0) + 1;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Overall: ${snapshot.status.name.toUpperCase()}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Healthy: ${counts[AppHealthStatus.healthy] ?? 0} · Degraded: ${counts[AppHealthStatus.degraded] ?? 0} · Failed: ${counts[AppHealthStatus.failed] ?? 0} · Unknown: ${counts[AppHealthStatus.unknown] ?? 0}'),
        ]),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.id, required this.result});
  final String id;
  final AppHealthResult result;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(_icon(result.status), semanticLabel: result.status.name),
      title: Text(id),
      subtitle: Text('${result.status.name}: ${result.message}${result.latency == null ? '' : ' · ${result.latency!.inMilliseconds} ms'}'),
    ),
  );

  static IconData _icon(AppHealthStatus status) => switch (status) {
    AppHealthStatus.healthy => Icons.check_circle,
    AppHealthStatus.degraded => Icons.warning_amber,
    AppHealthStatus.failed => Icons.error,
    AppHealthStatus.unknown => Icons.help_outline,
  };
}

class _Checking extends StatelessWidget {
  const _Checking();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(semanticsLabel: 'Checking health'));
}

class _DiagnosticError extends StatelessWidget {
  const _DiagnosticError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('Health diagnostic unavailable.'),
    const SizedBox(height: 8),
    FilledButton(onPressed: onRetry, child: const Text('Retry')),
  ]));
}
