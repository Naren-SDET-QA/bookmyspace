import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/institute_profile.dart';
import '../institute_providers.dart';

class InstituteOwnerDashboardScreen extends ConsumerStatefulWidget {
  const InstituteOwnerDashboardScreen({super.key});

  @override
  ConsumerState<InstituteOwnerDashboardScreen> createState() =>
      _InstituteOwnerDashboardScreenState();
}

class _InstituteOwnerDashboardScreenState
    extends ConsumerState<InstituteOwnerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myInstituteProvider);
    final plans = ref.watch(instituteListingPlansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Institute owner portal')),
      floatingActionButton: mine.valueOrNull == null
          ? FloatingActionButton.extended(
              onPressed: _createInstitute,
              icon: const Icon(Icons.add),
              label: const Text('Create institute'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _addClass(mine.valueOrNull!),
              icon: const Icon(Icons.class_),
              label: const Text('Add class'),
            ),
      body: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myInstituteProvider),
        ),
        data: (institute) {
          if (institute == null) {
            return const EmptyState(
              icon: Icons.apartment_outlined,
              title: 'No institute profile',
              message:
                  'Create an institute to publish classes, faculty and a gallery.',
            );
          }
          final listing = ref.watch(
            activeInstituteListingProvider(institute.id),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(institute.name),
                  subtitle: Text(
                    institute.isVerified ? 'Verified' : 'Unverified',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _createInstitute(existing: institute),
                  ),
                ),
              ),
              listing.when(
                data: (active) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: Text(
                      active == null || !active.isValid
                          ? 'No active advertising plan'
                          : 'Listing active until ${active.endsAt.toLocal()}',
                    ),
                    subtitle: const Text(
                      'Plans are purchased through the existing payment flow.',
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Text('Plans', style: Theme.of(context).textTheme.titleMedium),
              ...?plans.valueOrNull?.map(
                (plan) => ListTile(
                  title: Text(plan.name),
                  subtitle: Text(plan.description),
                  trailing: Text('₹${plan.price.toStringAsFixed(0)}'),
                ),
              ),
              const Divider(),
              Text('Faculty', style: Theme.of(context).textTheme.titleMedium),
              ...institute.faculty.map(
                (f) => ListTile(
                  title: Text(f.name),
                  subtitle: Text(f.specialization),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addFaculty(institute.id),
                icon: const Icon(Icons.person_add),
                label: const Text('Add faculty'),
              ),
              const Divider(),
              Text('Classes', style: Theme.of(context).textTheme.titleMedium),
              ...institute.courses.map(
                (c) => ListTile(
                  title: Text(c.title),
                  subtitle: Text(
                    [
                      c.status,
                      c.mode.name,
                      if (c.isDemo) 'demo',
                    ].join(' · '),
                  ),
                  trailing: Text('₹${c.feeAmount.toStringAsFixed(0)}'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createInstitute({InstituteProfile? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final city = TextEditingController(text: existing?.city ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Create institute' : 'Edit institute'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    await ref.read(instituteRepositoryProvider).upsertMine(
      name: name.text.trim(),
      description: description.text.trim(),
      city: city.text.trim(),
      phone: phone.text.trim(),
    );
    ref.invalidate(myInstituteProvider);
    ref.invalidate(publishedInstitutesProvider);
  }

  Future<void> _addFaculty(String instituteId) async {
    final name = TextEditingController();
    final spec = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add faculty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: spec,
              decoration: const InputDecoration(labelText: 'Specialization'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    await ref.read(instituteRepositoryProvider).addFaculty(
      instituteId: instituteId,
      name: name.text.trim(),
      specialization: spec.text.trim(),
    );
    ref.invalidate(myInstituteProvider);
  }

  Future<void> _addClass(InstituteProfile institute) async {
    final title = TextEditingController();
    final fee = TextEditingController(text: '0');
    var demo = false;
    var mode = 'offline';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fee'),
              ),
              DropdownButtonFormField<String>(
                initialValue: mode,
                items: const [
                  DropdownMenuItem(value: 'offline', child: Text('Offline')),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                ],
                onChanged: (v) => setLocal(() => mode = v ?? 'offline'),
                decoration: const InputDecoration(labelText: 'Delivery mode'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Demo session'),
                value: demo,
                onChanged: (v) => setLocal(() => demo = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || title.text.trim().isEmpty) return;
    await ref.read(instituteRepositoryProvider).saveClass(
      instituteId: institute.id,
      draft: OwnerClassDraft(
        title: title.text.trim(),
        description: '',
        mode: mode,
        durationWeeks: 4,
        feeAmount: double.tryParse(fee.text) ?? 0,
        isDemo: demo,
        status: 'draft',
      ),
    );
    ref.invalidate(myInstituteProvider);
  }
}
