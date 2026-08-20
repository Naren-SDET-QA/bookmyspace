import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';

const _modules = <String, String>{
  'function_halls': 'Function Halls',
  'lodge_rooms': 'Hotels / Lodges',
  'pg_hostels': 'PG / Hostels',
  'institutes': 'Institutes',
  'courses': 'Classes / Courses',
  'events': 'Events',
  'meetings': 'Meetings',
  'sports': 'Sports',
  'other': 'Other',
};

class ModuleConfigurationScreen extends ConsumerStatefulWidget {
  const ModuleConfigurationScreen({super.key});

  @override
  ConsumerState<ModuleConfigurationScreen> createState() =>
      _ModuleConfigurationScreenState();
}

class _ModuleConfigurationScreenState
    extends ConsumerState<ModuleConfigurationScreen> {
  final _enabled = <String, bool>{};
  bool _saving = false;

  Future<bool> _isAdmin() async {
    final client = ref.read(supabaseProvider);
    final user = client.auth.currentUser;
    if (user == null) return false;
    final rows = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id);
    return rows.any(
      (row) =>
          row['role'] == 'administrator' ||
          row['role'] == 'super_administrator',
    );
  }

  Future<void> _save(String module, bool value) async {
    setState(() {
      _enabled[module] = value;
      _saving = true;
    });
    try {
      final client = ref.read(supabaseProvider);
      final existing = await client
          .from('module_feature_configs')
          .select('id')
          .eq('module_key', module)
          .isFilter('venue_id', null)
          .maybeSingle();
      if (existing == null) {
        await client.from('module_feature_configs').insert({
          'module_key': module,
          'module_enabled': value,
        });
      } else {
        await client
            .from('module_feature_configs')
            .update({'module_enabled': value})
            .eq('id', existing['id']);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Module configuration'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _isAdmin(),
        builder: (context, access) {
          if (access.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (access.data != true) {
            return const Center(child: Text('Administrator access required'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: _modules.entries
                .map(
                  (entry) => Card(
                    child: SwitchListTile(
                      title: Text(entry.value),
                      subtitle: const Text(
                        'Configure registration, documents, payment and notifications',
                      ),
                      value: _enabled[entry.key] ?? true,
                      onChanged: (value) => _save(entry.key, value),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
