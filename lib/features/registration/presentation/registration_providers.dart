import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/registration_form.dart';
import '../infrastructure/supabase_registration_repository.dart';

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => SupabaseRegistrationRepository(ref.watch(supabaseProvider)),
);
final myRegistrationFormsProvider =
    FutureProvider<List<RegistrationFormDefinition>>(
      (ref) => ref.watch(registrationRepositoryProvider).myForms(),
    );
final registrationFormProvider =
    FutureProvider.family<RegistrationFormDefinition, String>(
      (ref, id) => ref.watch(registrationRepositoryProvider).form(id),
    );
