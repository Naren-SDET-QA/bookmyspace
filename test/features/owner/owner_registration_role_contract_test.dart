import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'owner registration migration grants only an active venue_owner role',
    () {
      final migration = File(
        'supabase/migrations/20260823170000_secure_owner_registration_role.sql',
      );

      expect(migration.existsSync(), isTrue);
      final sql = migration.readAsStringSync().toLowerCase();

      expect(sql, contains('complete_owner_registration'));
      expect(sql, contains('security definer'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains("'venue_owner'"));
      expect(sql, contains('user_roles'));
      expect(sql, contains('on conflict (user_id, role)'));
      expect(sql, isNot(contains('insert into auth.users')));
      expect(sql, contains('grant execute'));
    },
  );

  test(
    'owner repository establishes a session before calling the role RPC',
    () {
      final source = File(
        'lib/features/owner/infrastructure/supabase_owner_repository.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('response.session ?? _client.auth.currentSession'),
      );
      expect(source, contains("'complete_owner_registration'"));
      expect(source, contains("'p_name': name"));
      expect(
        source.indexOf('currentSession'),
        lessThan(source.indexOf('complete_owner_registration')),
      );
    },
  );

  test(
    'owner registration screen uses the Supabase owner creation provider',
    () {
      final screen = File(
        'lib/features/owner/presentation/screens/owner_registration_screen.dart',
      ).readAsStringSync();
      final providers = File(
        'lib/features/owner/presentation/owner_providers.dart',
      ).readAsStringSync();

      expect(screen, contains('createOwnerProvider'));
      expect(screen, contains('ref.read('));
      expect(providers, contains('SupabaseOwnerRepository(client)'));
      expect(providers, contains('.createOwner('));
    },
  );
}
