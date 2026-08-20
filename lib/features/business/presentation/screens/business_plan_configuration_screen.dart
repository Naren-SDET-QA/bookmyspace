import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../business_providers.dart';

class BusinessPlanConfigurationScreen extends ConsumerStatefulWidget {
  const BusinessPlanConfigurationScreen({super.key});
  @override
  ConsumerState<BusinessPlanConfigurationScreen> createState() =>
      _BusinessPlanConfigurationScreenState();
}

class _BusinessPlanConfigurationScreenState
    extends ConsumerState<BusinessPlanConfigurationScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = ref.read(businessConfigRepositoryProvider).adminPlans();
  Future<void> _add() async {
    final key = TextEditingController(),
        name = TextEditingController(),
        amount = TextEditingController(),
        days = TextEditingController(text: '30'),
        images = TextEditingController(text: '6'),
        leads = TextEditingController(text: '0');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add business plan'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: key,
                decoration: const InputDecoration(labelText: 'Plan key'),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price in minor units',
                ),
              ),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration days'),
              ),
              TextField(
                controller: images,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Image limit'),
              ),
              TextField(
                controller: leads,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Lead limit'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true || key.text.trim().isEmpty || name.text.trim().isEmpty)
      return;
    try {
      await ref.read(businessConfigRepositoryProvider).createPlan({
        'plan_key': key.text.trim(),
        'name': name.text.trim(),
        'amount_minor': int.tryParse(amount.text) ?? -1,
        'duration_days': int.tryParse(days.text) ?? 0,
        'image_limit': int.tryParse(images.text) ?? 0,
        'lead_limit': int.tryParse(leads.text) ?? 0,
        'currency': 'INR',
        'is_active': true,
        'created_by': ref.read(supabaseProvider).auth.currentUser!.id,
      });
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save plan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business plans')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('Add plan'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Could not load plans: ${snapshot.error}'));
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty)
          return const Center(child: Text('No business plans configured'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: rows
              .map(
                (row) => Card(
                  child: ListTile(
                    title: Text('${row['name']} · ${row['plan_key']}'),
                    subtitle: Text(
                      '${row['amount_minor']} ${row['currency'] ?? 'INR'} · ${row['duration_days']} days · ${row['image_limit']} images · ${row['lead_limit']} leads',
                    ),
                    trailing: row['is_active'] == true
                        ? IconButton(
                            icon: const Icon(Icons.block),
                            onPressed: () async {
                              await ref
                                  .read(businessConfigRepositoryProvider)
                                  .disablePlan(row['id'] as String);
                              if (mounted) setState(_load);
                            },
                          )
                        : const Icon(Icons.block),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}
