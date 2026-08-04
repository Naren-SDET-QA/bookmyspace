import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/owner.dart';
import '../owner_providers.dart';

class OwnerProfileScreen extends ConsumerStatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  ConsumerState<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends ConsumerState<OwnerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = List.generate(11, (_) => TextEditingController());
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _load(Owner owner) {
    if (_loaded) return;
    _loaded = true;
    final values = [
      owner.name,
      owner.phone,
      owner.whatsapp,
      owner.email,
      owner.businessName,
      owner.address,
      owner.city,
      owner.state,
      owner.latitude?.toString() ?? '',
      owner.longitude?.toString() ?? '',
      owner.photoUrl,
    ];
    for (var i = 0; i < values.length; i++) {
      _fields[i].text = values[i];
    }
  }

  Future<void> _save(Owner current) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .saveProfile(
            Owner(
              id: current.id,
              userId: current.userId,
              email: current.email,
              name: _fields[0].text.trim(),
              phone: _fields[1].text.trim(),
              whatsapp: _fields[2].text.trim(),
              businessName: _fields[4].text.trim(),
              address: _fields[5].text.trim(),
              city: _fields[6].text.trim(),
              state: _fields[7].text.trim(),
              latitude: double.tryParse(_fields[8].text),
              longitude: double.tryParse(_fields[9].text),
              photoUrl: _fields[10].text.trim(),
              orgId: current.orgId,
            ),
          );
      ref.invalidate(currentOwnerProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Owner profile saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentOwnerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Owner Profile')),
      body: owner.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Owner profile not found'));
          }
          _load(value);
          const labels = [
            'Name',
            'Phone',
            'WhatsApp',
            'Email',
            'Business name',
            'Address',
            'City',
            'State',
            'Latitude',
            'Longitude',
            'Profile / business photo URL',
          ];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.pagePadding),
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundImage: value.photoUrl.isEmpty
                      ? null
                      : NetworkImage(value.photoUrl),
                  child: value.photoUrl.isEmpty
                      ? const Icon(Icons.business_rounded, size: 34)
                      : null,
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _fields[i],
                      readOnly: i == 3,
                      keyboardType: i >= 8
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: labels[i]),
                      validator: i == 0 || i == 4
                          ? (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null
                          : null,
                    ),
                  ),
                FilledButton(
                  onPressed: _saving ? null : () => _save(value),
                  child: Text(_saving ? 'Saving…' : 'Save profile'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
