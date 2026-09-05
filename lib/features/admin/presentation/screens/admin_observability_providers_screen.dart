import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/auth_providers.dart';

final observabilityProvidersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('integrations').select('id,name,slug,type,provider,enabled,status,base_url,configuration,display_order,archived_at').isFilter('archived_at', null).order('display_order').limit(100);
  return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
});

class AdminObservabilityProvidersScreen extends ConsumerWidget {
  const AdminObservabilityProvidersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(observabilityProvidersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Observability providers')),
      body: providers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Providers unavailable: $error')),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(observabilityProvidersProvider.future),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Configured providers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (items.isEmpty) const Card(child: ListTile(title: Text('No providers configured'))),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _editProvider(context, ref), icon: const Icon(Icons.add), label: const Text('Add provider'))),
            ...items.map((item) => Card(child: ListTile(
              title: Text('${item['name'] ?? item['slug'] ?? 'Provider'}'),
              subtitle: Text('${item['type'] ?? 'UNKNOWN'} · ${item['status'] ?? 'disabled'} · ${_credentialStatus(item)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: item['enabled'] == true, onChanged: (enabled) async { await ref.read(supabaseProvider).from('integrations').update({'enabled': enabled}).eq('id', item['id'] as Object); ref.invalidate(observabilityProvidersProvider); }),
                IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit provider', onPressed: () => _editProvider(context, ref, item)),
                IconButton(icon: const Icon(Icons.network_check), tooltip: 'Test connection', onPressed: () => _testConnection(context, ref, item)),
                IconButton(icon: const Icon(Icons.archive_outlined), tooltip: 'Archive provider', onPressed: () async { await ref.read(supabaseProvider).from('integrations').update({'archived_at': DateTime.now().toIso8601String(), 'enabled': false, 'status': 'disabled'}).eq('id', item['id'] as Object); ref.invalidate(observabilityProvidersProvider); }),
              ]),
            )))
          ]),
        ),
      ),
    );
  }

  Future<void> _editProvider(BuildContext context, WidgetRef ref, [Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final slug = TextEditingController(text: item?['slug']?.toString() ?? '');
    final baseUrl = TextEditingController(text: item?['base_url']?.toString() ?? '');
    final configuration = Map<String, dynamic>.from((item?['configuration'] as Map?) ?? const {});
    final model = TextEditingController(text: configuration['model']?.toString() ?? '');
    final priority = TextEditingController(text: '${configuration['priority'] ?? item?['display_order'] ?? 0}');
    final retry = TextEditingController(text: '${configuration['retry_count'] ?? 1}');
    final inputLimit = TextEditingController(text: '${configuration['input_limit'] ?? 8000}');
    final outputLimit = TextEditingController(text: '${configuration['output_limit'] ?? 8000}');
    final rateLimit = TextEditingController(text: '${configuration['rate_limit'] ?? 20}');
    final saved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(item == null ? 'Add provider' : 'Edit provider'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
        TextField(controller: baseUrl, decoration: const InputDecoration(labelText: 'Base URL')),
        TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
        TextField(controller: priority, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Priority')),
        TextField(controller: retry, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Retry')),
        TextField(controller: inputLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Input limit')),
        TextField(controller: outputLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Output limit')),
        TextField(controller: rateLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate limit')),
        const Align(alignment: Alignment.centerLeft, child: Text('Credential: Configured / Not Configured (secret values are never shown)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    ));
    if (saved != true || name.text.trim().isEmpty || slug.text.trim().isEmpty) return;
    final client = ref.read(supabaseProvider);
    final values = {
      'name': name.text.trim(), 'slug': slug.text.trim(),
      'base_url': baseUrl.text.trim().isEmpty ? null : baseUrl.text.trim(),
      'display_order': int.tryParse(priority.text) ?? 0,
      'configuration': {
        ...configuration,
        'model': model.text.trim().isEmpty ? null : model.text.trim(),
        'priority': _boundedInt(priority.text, 0, 1000),
        'retry_count': _boundedInt(retry.text, 0, 3),
        'input_limit': _boundedInt(inputLimit.text, 256, 16000),
        'output_limit': _boundedInt(outputLimit.text, 256, 16000),
        'rate_limit': _boundedInt(rateLimit.text, 1, 60),
      },
    };
    if (item == null) {
      await client.from('integrations').insert({...values, 'type': 'REST_API', 'status': 'disabled', 'enabled': false});
    } else {
      await client.from('integrations').update(values).eq('id', item['id'] as Object);
    }
    ref.invalidate(observabilityProvidersProvider);
  }

  static int _boundedInt(String value, int min, int max) {
    final parsed = int.tryParse(value) ?? min;
    return parsed.clamp(min, max);
  }

  static String _credentialStatus(Map<String, dynamic> item) {
    final configuration = item['configuration'];
    if (configuration is Map && configuration['credential_configured'] == true) return 'Configured';
    return 'Not Configured';
  }

  Future<void> _testConnection(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    try {
      final result = await ref.read(supabaseProvider).functions.invoke('integration-executor', body: {'operation': 'test_connection', 'integration_slug': item['slug'], 'action_slug': 'health'});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['status'] == 'SUCCESS' ? 'SUCCESS' : 'SAFE ERROR')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAILED: provider unavailable')));
    }
  }
}
