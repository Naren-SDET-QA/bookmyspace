import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../business_providers.dart';

class BusinessPricingConfigurationScreen extends ConsumerStatefulWidget {
  const BusinessPricingConfigurationScreen({super.key});

  @override
  ConsumerState<BusinessPricingConfigurationScreen> createState() =>
      _BusinessPricingConfigurationScreenState();
}

class _BusinessPricingConfigurationScreenState
    extends ConsumerState<BusinessPricingConfigurationScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(businessConfigRepositoryProvider).adminPricing();
  }

  Future<bool> _isAdmin() async {
    final client = ref.read(supabaseProvider);
    final id = client.auth.currentUser?.id;
    if (id == null) return false;
    final rows = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', id);
    return rows.any(
      (row) =>
          row['role'] == 'administrator' ||
          row['role'] == 'super_administrator',
    );
  }

  void _reload() => setState(() {
    _future = ref.read(businessConfigRepositoryProvider).adminPricing();
  });

  Future<void> _addPrice() async {
    final key = TextEditingController();
    final name = TextEditingController();
    final amount = TextEditingController();
    final result = await showDialog<(String, String, int)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add pricing version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: key,
              decoration: const InputDecoration(labelText: 'Feature key'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount in minor units',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              key.text,
              name.text,
              int.tryParse(amount.text) ?? -1,
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    key.dispose();
    name.dispose();
    amount.dispose();
    if (result == null ||
        result.$1.trim().isEmpty ||
        result.$2.trim().isEmpty ||
        result.$3 < 0)
      return;
    try {
      await ref.read(businessConfigRepositoryProvider).createPricing({
        'feature_key': result.$1.trim(),
        'name': result.$2.trim(),
        'amount_minor': result.$3,
        'pricing_model': 'one_time',
        'version': 1,
      });
      _reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save pricing: $error')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business pricing')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addPrice,
      icon: const Icon(Icons.add),
      label: const Text('Add price'),
    ),
    body: FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, access) {
        if (access.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (access.data != true)
          return const Center(child: Text('Administrator access required'));
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(
                child: Text('Could not load pricing: ${snapshot.error}'),
              );
            final items = snapshot.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty)
              return const Center(child: Text('No pricing configured'));
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text('${item['name']} · ${item['feature_key']}'),
                    subtitle: Text(
                      '${item['amount_minor']} ${item['currency'] ?? 'INR'} · v${item['version']} · ${item['pricing_model']}',
                    ),
                    trailing: item['is_active'] == true
                        ? IconButton(
                            icon: const Icon(Icons.block),
                            tooltip: 'Disable',
                            onPressed: () async {
                              await ref
                                  .read(businessConfigRepositoryProvider)
                                  .disablePricing(item['id'] as String);
                              _reload();
                            },
                          )
                        : const Icon(Icons.block),
                  ),
                );
              },
            );
          },
        );
      },
    ),
  );
}
