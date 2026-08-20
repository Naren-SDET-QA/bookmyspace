import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/auth_providers.dart';

class AdminRewardConfigScreen extends ConsumerStatefulWidget {
  const AdminRewardConfigScreen({super.key});
  @override
  ConsumerState<AdminRewardConfigScreen> createState() =>
      _AdminRewardConfigScreenState();
}

class _AdminRewardConfigScreenState
    extends ConsumerState<AdminRewardConfigScreen> {
  final _name = TextEditingController(text: 'Referral reward');
  final _referrer = TextEditingController(text: '100');
  final _referred = TextEditingController(text: '50');
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _configs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _referrer.dispose();
    _referred.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref
          .read(supabaseProvider)
          .from('reward_configs')
          .select(
            'id,name,referrer_amount,referee_amount,currency,is_active,created_at',
          )
          .order('created_at', ascending: false);
      if (mounted)
        setState(() {
          _configs = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(supabaseProvider).from('reward_configs').insert({
        'name': _name.text.trim(),
        'referrer_amount': double.parse(_referrer.text),
        'referee_amount': double.parse(_referred.text),
        'currency': 'INR',
        'is_active': true,
        'created_by': ref.read(supabaseProvider).auth.currentUser!.id,
      });
      await _load();
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reward configuration')),
    body: _loading && _configs.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Rule name'),
              ),
              TextField(
                controller: _referrer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Referrer credit (INR)',
                ),
              ),
              TextField(
                controller: _referred,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New customer credit (INR)',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _create,
                child: const Text('Activate rule'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Existing rules',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._configs.map(
                (c) => ListTile(
                  title: Text(c['name'] as String? ?? ''),
                  subtitle: Text(
                    'Referrer ₹${c['referrer_amount']} · New customer ₹${c['referee_amount']}',
                  ),
                  trailing: Text(
                    c['is_active'] == true ? 'Active' : 'Inactive',
                  ),
                ),
              ),
            ],
          ),
  );
}
