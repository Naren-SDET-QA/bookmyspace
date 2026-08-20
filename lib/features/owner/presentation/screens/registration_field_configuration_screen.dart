import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/registration_field_config.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../owner_providers.dart';

/// Admin-only configuration for the fields shown during owner registration.
class RegistrationFieldConfigurationScreen extends ConsumerStatefulWidget {
  const RegistrationFieldConfigurationScreen({super.key});

  @override
  ConsumerState<RegistrationFieldConfigurationScreen> createState() =>
      _RegistrationFieldConfigurationScreenState();
}

class _RegistrationFieldConfigurationScreenState
    extends ConsumerState<RegistrationFieldConfigurationScreen> {
  late Future<List<RegistrationFieldConfig>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(registrationConfigRepositoryProvider).allFields();
  }

  void _reload() => setState(() {
    _future = ref.read(registrationConfigRepositoryProvider).allFields();
  });

  Future<void> _update(
    RegistrationFieldConfig field,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref
          .read(registrationConfigRepositoryProvider)
          .updateFieldConfig(field.key, changes);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update field: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owner registration fields')),
      body: FutureBuilder<bool>(
        future: _isAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return const Center(child: Text('Administrator access required'));
          }
          return FutureBuilder<List<RegistrationFieldConfig>>(
            future: _future,
            builder: (context, fieldsSnapshot) {
              if (fieldsSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (fieldsSnapshot.hasError) {
                return Center(
                  child: Text('Could not load fields: ${fieldsSnapshot.error}'),
                );
              }
              final fields =
                  fieldsSnapshot.data ?? const <RegistrationFieldConfig>[];
              if (fields.isEmpty) {
                return const Center(
                  child: Text('No registration fields configured'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: fields.length,
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return Card(
                    child: SwitchListTile(
                      title: Text(field.label),
                      subtitle: Text(
                        '${field.key} · ${field.type.name} · '
                        '${field.required ? 'required' : 'optional'}'
                        '${field.sensitive ? ' · sensitive' : ''}',
                      ),
                      value: field.enabled,
                      onChanged: (value) => _update(field, {'enabled': value}),
                      secondary: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'required') {
                            _update(field, {'required': !field.required});
                          } else if (action == 'owner') {
                            _update(field, {
                              'owner_visible': !field.ownerVisible,
                            });
                          } else if (action == 'customer') {
                            _update(field, {
                              'customer_visible': !field.customerVisible,
                            });
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'required',
                            child: Text(
                              field.required
                                  ? 'Make optional'
                                  : 'Make required',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'owner',
                            child: Text(
                              field.ownerVisible
                                  ? 'Hide from owners'
                                  : 'Show to owners',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'customer',
                            child: Text(
                              field.customerVisible
                                  ? 'Hide from customers'
                                  : 'Show to customers',
                            ),
                          ),
                        ],
                      ),
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

  Future<bool> _isAdmin() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;
    final rows = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId);
    return rows.any(
      (row) =>
          row['role'] == 'administrator' ||
          row['role'] == 'super_administrator',
    );
  }
}
