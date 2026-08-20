import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/module_registration.dart';
import '../infrastructure/supabase_module_registration_repository.dart';
import 'dynamic_registration_form.dart';

class ModuleRegistrationScreen extends ConsumerStatefulWidget {
  const ModuleRegistrationScreen({
    super.key,
    required this.moduleKey,
    this.venueId,
    this.bookingId,
  });
  final String moduleKey;
  final String? venueId;
  final String? bookingId;

  @override
  ConsumerState<ModuleRegistrationScreen> createState() =>
      _ModuleRegistrationScreenState();
}

class _ModuleRegistrationScreenState
    extends ConsumerState<ModuleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _values = const {};
  bool _submitting = false;

  SupabaseModuleRegistrationRepository get _repo =>
      SupabaseModuleRegistrationRepository(ref.read(supabaseProvider));

  Future<void> _submit(ModuleFormVersion form) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final id = await _repo.submit(
        moduleKey: widget.moduleKey,
        venueId: widget.venueId,
        bookingId: widget.bookingId,
        formVersionId: form.id,
        values: _values,
        idempotencyKey:
            '${DateTime.now().microsecondsSinceEpoch}-${widget.moduleKey}',
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration submitted: $id')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration could not be submitted: $error'),
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = Future.wait([
      _repo.featureConfig(widget.moduleKey, venueId: widget.venueId),
      _repo.publishedForms(widget.moduleKey, venueId: widget.venueId),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text('Register: ${widget.moduleKey}')),
      body: FutureBuilder<List<Object?>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Text('Could not load registration: ${snapshot.error}'),
            );
          final config = snapshot.data![0] as ModuleFeatureConfig?;
          final forms = snapshot.data![1] as List<ModuleFormVersion>;
          if (config == null ||
              !config.moduleEnabled ||
              !config.registrationEnabled)
            return const Center(
              child: Text('Registration is not available for this listing'),
            );
          if (forms.isEmpty)
            return const Center(
              child: Text('Registration form is not configured'),
            );
          final form = forms.first;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Complete your registration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (config.documentUploadEnabled)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Required documents will be requested before submission.',
                    ),
                  ),
                if (config.paymentEnabled)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Payment will be handled by the existing secure payment flow after submission.',
                    ),
                  ),
                DynamicRegistrationForm(
                  fields: form.fields,
                  onChanged: (values) => _values = values,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(form),
                  child: _submitting
                      ? const CircularProgressIndicator()
                      : const Text('Submit registration'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
