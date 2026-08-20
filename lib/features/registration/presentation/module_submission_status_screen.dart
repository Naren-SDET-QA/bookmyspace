import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../infrastructure/supabase_submission_repository.dart';
import '../infrastructure/supabase_module_registration_repository.dart';
import '../domain/module_progress.dart';
import 'module_progress_stepper.dart';

class ModuleSubmissionStatusScreen extends ConsumerWidget {
  const ModuleSubmissionStatusScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = SupabaseSubmissionRepository(ref.watch(supabaseProvider));
    return Scaffold(
      appBar: AppBar(title: const Text('Registration status')),
      body: FutureBuilder(
        future: repo.byId(submissionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Text('Could not load status: ${snapshot.error}'),
            );
          final submission = snapshot.data!;
          final moduleRepo = SupabaseModuleRegistrationRepository(
            ref.read(supabaseProvider),
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Registration submitted',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              FutureBuilder(
                future: moduleRepo.featureConfig(
                  submission.moduleKey,
                  venueId: submission.venueId,
                ),
                builder: (context, configSnapshot) {
                  final config = configSnapshot.data;
                  if (config == null) return const SizedBox.shrink();
                  final current = switch (submission.status) {
                    'approved' => ModuleProgressStep.approved,
                    'confirmed' => ModuleProgressStep.completed,
                    'payment_pending' ||
                    'payment_verified' => ModuleProgressStep.payment,
                    'under_review' || 'rejected' => ModuleProgressStep.review,
                    _ => ModuleProgressStep.registration,
                  };
                  return ModuleProgressStepper(
                    steps: moduleProgressSteps(config),
                    current: current,
                  );
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('Status'),
                subtitle: Text(submission.status),
              ),
              ListTile(
                leading: const Icon(Icons.payment_outlined),
                title: const Text('Payment'),
                subtitle: Text(
                  submission.status == 'payment_pending'
                      ? 'Payment required'
                      : 'Payment status is managed by the server',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Documents'),
                subtitle: const Text(
                  'Document status is checked against the configured requirements',
                ),
              ),
              if (submission.rejectionReason != null)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Next action'),
                  subtitle: Text(submission.rejectionReason!),
                ),
            ],
          );
        },
      ),
    );
  }
}
