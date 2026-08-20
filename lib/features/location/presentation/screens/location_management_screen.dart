import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/location_node.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../owner/presentation/owner_providers.dart';
import '../location_providers.dart';

class LocationManagementScreen extends ConsumerStatefulWidget {
  const LocationManagementScreen({super.key, required this.admin});
  final bool admin;

  @override
  ConsumerState<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState
    extends ConsumerState<LocationManagementScreen> {
  final _searchController = TextEditingController();
  late Future<List<LocationNode>> _nodesFuture;

  @override
  void initState() {
    super.initState();
    _nodesFuture = ref.read(locationRepositoryProvider).managementSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _nodesFuture = ref
          .read(locationRepositoryProvider)
          .managementSearch(_searchController.text);
    });
  }

  Future<void> _createLocation() async {
    final nameController = TextEditingController();
    final countryController = TextEditingController(text: 'US');
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: countryController,
              decoration: const InputDecoration(labelText: 'Country code'),
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
              nameController.text,
              countryController.text,
            )),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    nameController.dispose();
    countryController.dispose();
    if (result == null || result.$1.trim().isEmpty) return;
    try {
      await ref
          .read(locationRepositoryProvider)
          .submitNode(
            name: result.$1,
            normalizedName: result.$1,
            level: 'country',
            countryCode: result.$2.trim().toUpperCase(),
          );
      if (mounted) {
        ref.invalidate(
          locationChildrenProvider((
            parentId: null,
            level: LocationNodeLevel.country,
          )),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location submitted for review')),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save location: $error')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: widget.admin ? _isAdmin() : _isOwner(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != true) {
          return const Scaffold(
            body: Center(child: Text('Location management access denied')),
          );
        }
        return _authorizedBody(context);
      },
    );
  }

  Future<bool> _isOwner() async =>
      (await ref.read(currentOwnerProvider.future)) != null;

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

  Widget _authorizedBody(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.admin ? 'Admin Locations' : 'My Location Submissions',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLocation,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add location'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Search locations',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LocationNode>>(
              future: _nodesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError)
                  return Center(
                    child: Text('Could not load locations: ${snapshot.error}'),
                  );
                final items = snapshot.data ?? const <LocationNode>[];
                if (items.isEmpty)
                  return const Center(child: Text('No matching locations'));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _LocationTreeTile(
                    node: items[index],
                    admin: widget.admin,
                    onChanged: _search,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationTreeTile extends ConsumerWidget {
  const _LocationTreeTile({
    required this.node,
    required this.admin,
    required this.onChanged,
  });
  final LocationNode node;
  final bool admin;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(
      locationChildrenProvider((
        parentId: node.id,
        level: LocationNodeLevel.stateProvince,
      )),
    );
    return ExpansionTile(
      title: Text(node.name),
      subtitle: Text('${node.countryCode} · ${node.status}'),
      trailing: admin
          ? PopupMenuButton<String>(
              onSelected: (action) async {
                final repo = ref.read(locationRepositoryProvider);
                if (action == 'deactivate')
                  await repo.setNodeStatus(node.id, 'inactive');
                if (action == 'activate')
                  await repo.setNodeStatus(node.id, 'active');
                onChanged();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: node.status == 'active' ? 'deactivate' : 'activate',
                  child: Text(
                    node.status == 'active' ? 'Deactivate' : 'Activate',
                  ),
                ),
              ],
            )
          : null,
      children: children.when(
        loading: () => [const LinearProgressIndicator()],
        error: (_, _) => [
          const ListTile(title: Text('Could not load children')),
        ],
        data: (items) => items.isEmpty
            ? [const ListTile(title: Text('No child locations'))]
            : [
                for (final child in items)
                  ListTile(
                    title: Text(child.name),
                    subtitle: Text(child.status),
                  ),
              ],
      ),
    );
  }
}
