import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/registration_form.dart';
import '../registration_providers.dart';
import '../widgets/dynamic_registration_form.dart';

class RegistrationFillScreen extends ConsumerWidget {
  const RegistrationFillScreen({
    super.key,
    required this.formId,
    this.bookingId,
  });
  final String formId;
  final String? bookingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(registrationFormProvider(formId));
    return Scaffold(
      appBar: AppBar(title: const Text('Registration')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(registrationFormProvider(formId)),
        ),
        data: (form) => ListView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          children: [
            Text(
              form.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text('Form version ${form.version}'),
            const SizedBox(height: 18),
            DynamicRegistrationForm(
              definition: form,
              onSubmit: (values, files) => _submit(context, ref, values, files),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> values,
    Map<String, XFile> files,
  ) async {
    final repo = ref.read(registrationRepositoryProvider);
    final id = await repo.submit(formId, bookingId, values);
    for (final entry in files.entries) {
      final x = entry.value;
      await repo.upload(
        id,
        entry.key,
        x.name,
        x.mimeType ?? 'application/octet-stream',
        await x.readAsBytes(),
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration submitted securely')),
      );
      Navigator.of(context).pop();
    }
  }
}

class RegistrationFormsAdminScreen extends ConsumerWidget {
  const RegistrationFormsAdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myRegistrationFormsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Forms'),
        actions: [
          IconButton(
            onPressed: () => _new(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(myRegistrationFormsProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.dynamic_form,
                title: 'No form templates',
                message: 'Create one reusable form for any module.',
                action: FilledButton(
                  onPressed: () => _new(context, ref),
                  child: const Text('Create form'),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                itemCount: items.length,
                itemBuilder: (c, i) => Card(
                  child: ListTile(
                    title: Text(items[i].name),
                    subtitle: Text(
                      '${items[i].moduleKey} • v${items[i].version} • ${items[i].status}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RegistrationFormEditorScreen(initial: items[i]),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(), module = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New form template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Form name'),
            ),
            TextField(
              controller: module,
              decoration: const InputDecoration(labelText: 'Module key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final id = await ref
          .read(registrationRepositoryProvider)
          .create(name.text, module.text, const []);
      ref.invalidate(myRegistrationFormsProvider);
      final form = await ref.read(registrationRepositoryProvider).form(id);
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RegistrationFormEditorScreen(initial: form),
          ),
        );
      }
    }
  }
}

class RegistrationFormEditorScreen extends ConsumerStatefulWidget {
  const RegistrationFormEditorScreen({super.key, required this.initial});
  final RegistrationFormDefinition initial;
  @override
  ConsumerState<RegistrationFormEditorScreen> createState() => _EditorState();
}

class _EditorState extends ConsumerState<RegistrationFormEditorScreen> {
  late RegistrationFormDefinition form;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    form = widget.initial;
  }

  void move(int i, int delta) {
    final fields = [...form.fields];
    final j = i + delta;
    if (j < 0 || j >= fields.length) return;
    final item = fields.removeAt(i);
    fields.insert(j, item);
    setState(
      () => form = form.copyWith(
        fields: [
          for (var x = 0; x < fields.length; x++) fields[x].copyWith(order: x),
        ],
      ),
    );
  }

  Future<void> add() async {
    RegistrationFieldType type = RegistrationFieldType.text;
    final label = TextEditingController();
    final options = TextEditingController();
    final pattern = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              DropdownButtonFormField(
                initialValue: type,
                items: RegistrationFieldType.values
                    .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) => set(() => type = v ?? type),
              ),
              TextField(
                controller: options,
                decoration: const InputDecoration(
                  labelText: 'Dropdown options, comma separated',
                ),
              ),
              TextField(
                controller: pattern,
                decoration: const InputDecoration(
                  labelText: 'Validation pattern (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final k = label.text.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );
      setState(
        () => form = form.copyWith(
          fields: [
            ...form.fields,
            RegistrationFieldDefinition(
              key: k,
              label: label.text.trim(),
              type: type,
              order: form.fields.length,
              options: options.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
              validation: pattern.text.trim().isEmpty
                  ? const {}
                  : {'pattern': pattern.text.trim()},
            ),
          ],
        ),
      );
    }
  }

  Future<void> save({bool publish = false}) async {
    setState(() => busy = true);
    try {
      final v = await ref.read(registrationRepositoryProvider).save(form);
      form = form.copyWith(version: v);
      if (publish) {
        await ref.read(registrationRepositoryProvider).publish(form.id);
      }
      ref.invalidate(myRegistrationFormsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publish ? 'Published version $v' : 'Saved version $v',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> bindForm() async {
    final module = TextEditingController(text: form.moduleKey);
    final resource = TextEditingController();
    var stage = RegistrationCollectionStage.preBooking;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Use form in module'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: module,
                decoration: const InputDecoration(labelText: 'Module key'),
              ),
              TextField(
                controller: resource,
                decoration: const InputDecoration(
                  labelText: 'Resource ID (optional)',
                ),
              ),
              DropdownButtonFormField<RegistrationCollectionStage>(
                initialValue: stage,
                decoration: const InputDecoration(
                  labelText: 'Collection stage',
                ),
                items: RegistrationCollectionStage.values
                    .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) => setDialogState(() => stage = v ?? stage),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Bind'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await ref
        .read(registrationRepositoryProvider)
        .bind(
          form.id,
          module.text.trim(),
          resource.text.trim().isEmpty ? null : resource.text.trim(),
          RegistrationFormDefinition.stageKey(stage),
        );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Form linked to module')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(form.name),
      actions: [
        IconButton(
          tooltip: 'Use in module',
          onPressed: busy ? null : bindForm,
          icon: const Icon(Icons.link),
        ),
        IconButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Preview'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: DynamicRegistrationForm(
                    definition: form,
                    preview: true,
                    onSubmit: (_, _) async {},
                  ),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.preview),
        ),
        IconButton(
          onPressed: busy ? null : () => save(publish: true),
          icon: const Icon(Icons.publish),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        for (var i = 0; i < form.fields.length; i++)
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(form.fields[i].label),
                  subtitle: Text(
                    '${form.fields[i].type.name} • ${form.fields[i].participantScope.name} • ${form.fields[i].collectionStage.name}',
                  ),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle),
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: i == 0 ? null : () => move(i, -1),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        onPressed: i == form.fields.length - 1
                            ? null
                            : () => move(i, 1),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        onPressed: () => setState(
                          () => form = form.copyWith(
                            fields: [...form.fields]..removeAt(i),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Enabled'),
                  value: form.fields[i].enabled,
                  onChanged: (v) => setState(
                    () => form = form.copyWith(
                      fields: [...form.fields]
                        ..[i] = form.fields[i].copyWith(enabled: v),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            DropdownButtonFormField<
                              RegistrationParticipantScope
                            >(
                              initialValue: form.fields[i].participantScope,
                              decoration: const InputDecoration(
                                labelText: 'Participants',
                              ),
                              items: RegistrationParticipantScope.values
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => form = form.copyWith(
                                  fields: [...form.fields]
                                    ..[i] = form.fields[i].copyWith(
                                      participantScope: v,
                                    ),
                                ),
                              ),
                            ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                            DropdownButtonFormField<
                              RegistrationCollectionStage
                            >(
                              initialValue: form.fields[i].collectionStage,
                              decoration: const InputDecoration(
                                labelText: 'Collection stage',
                              ),
                              items: RegistrationCollectionStage.values
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => form = form.copyWith(
                                  fields: [...form.fields]
                                    ..[i] = form.fields[i].copyWith(
                                      collectionStage: v,
                                    ),
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Required'),
                  value: form.fields[i].required,
                  onChanged: (v) => setState(
                    () => form = form.copyWith(
                      fields: [...form.fields]
                        ..[i] = form.fields[i].copyWith(required: v),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 70),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: busy ? null : save,
          icon: const Icon(Icons.save),
          label: Text(busy ? 'Saving…' : 'Save new version'),
        ),
      ),
    ),
  );
}
