import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../observability_providers.dart';

class AdminObservabilityScreen extends ConsumerWidget {
  const AdminObservabilityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthSnapshotsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Observability')),
      body: health.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Health data unavailable: $error')),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(healthSnapshotsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('System health', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (items.isEmpty) const Card(child: ListTile(title: Text('No verified health checks yet'), subtitle: Text('Only recorded server health is shown.'))),
              ...items.map((item) => Card(child: ListTile(leading: Icon(_icon(item.status), color: _color(item.status)), title: Text(item.feature), subtitle: Text(item.responseMs == null ? item.status : '${item.status} · ${item.responseMs} ms')))),
              const SizedBox(height: 16),
              _Section(title: 'Error Center', child: _AsyncList(provider: errorEventsProvider, label: (row) => '${row['severity'] ?? 'unknown'} · ${row['feature'] ?? 'unknown'} · ${row['status'] ?? 'unresolved'}')),
              _Section(title: 'Alerts', child: _AsyncList(provider: alertRulesProvider, label: (row) => '${row['feature'] ?? 'metric'} · threshold ${row['threshold'] ?? '-'} · ${row['enabled'] == true ? 'enabled' : 'disabled'}')),
              _Section(title: 'Recovery', child: _AsyncList(provider: recoveryEventsProvider, label: (row) => '${row['feature'] ?? 'component'} · ${row['action'] ?? 'action'} · ${row['status'] ?? 'status'}')),
              const _Section(title: 'Metrics', child: ListTile(subtitle: Text('Metrics are read from bounded server-side event queries.'))),
            ],
          ),
        ),
      ),
    );
  }
  static IconData _icon(String status) => switch (status) { 'healthy' => Icons.check_circle, 'warning' => Icons.warning_rounded, 'critical' => Icons.error, _ => Icons.pause_circle };
  static Color _color(String status) => switch (status) { 'healthy' => Colors.green, 'warning' => Colors.orange, 'critical' => Colors.red, _ => Colors.grey };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: ExpansionTile(title: Text(title), children: [child]));
}

class _AsyncList extends ConsumerWidget {
  const _AsyncList({required this.provider, required this.label});
  final FutureProvider<List<Map<String, dynamic>>> provider;
  final String Function(Map<String, dynamic>) label;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(provider).when(
    loading: () => const ListTile(title: Text('Loading…')),
    error: (_, __) => const ListTile(title: Text('Unavailable'), subtitle: Text('Observability is fail-open.')),
    data: (rows) => rows.isEmpty ? const ListTile(title: Text('No records')) : Column(children: rows.take(20).map((row) => ListTile(title: Text(label(row)))).toList()),
  );
}
