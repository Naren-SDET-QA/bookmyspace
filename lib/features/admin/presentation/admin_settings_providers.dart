import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/admin_settings.dart';
import '../infrastructure/supabase_admin_settings_repository.dart';

final adminSettingsRepositoryProvider = Provider(
  (ref) => SupabaseAdminSettingsRepository(ref.watch(supabaseProvider)),
);
final adminSettingsProvider = FutureProvider<AdminSettings>(
  (ref) => ref.watch(adminSettingsRepositoryProvider).load(),
);
