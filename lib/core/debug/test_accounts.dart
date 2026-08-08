import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pre-configured test account used by the hidden debug menu.
class TestAccount {
  const TestAccount({
    required this.label,
    required this.email,
    this.phone,
    required this.role,
  });

  final String label;
  final String email;
  final String? phone;
  final String role;
}

/// Test accounts for the existing development backend.
///
/// These are the same accounts the DEV backend seeds; the debug menu offers
/// one-tap sign-in via the app's existing OTP flow (no mock auth, no injected
/// tokens — the normal Supabase backend is used end to end).
const List<TestAccount> testAccounts = [
  TestAccount(
    label: 'Test Customer',
    email: 'customer@bookmyspace.dev',
    role: 'customer',
  ),
  TestAccount(
    label: 'Test Owner',
    email: 'owner@bookmyspace.dev',
    role: 'owner',
  ),
  TestAccount(
    label: 'Test Admin',
    email: 'admin@bookmyspace.dev',
    role: 'admin',
  ),
];

final testAccountsProvider = Provider<List<TestAccount>>((ref) => testAccounts);

/// Test account currently selected from the debug menu, used to prefill the
/// login form. Starts null (no auto sign-in).
final selectedTestAccountProvider =
    NotifierProvider<SelectedTestAccountNotifier, TestAccount?>(
  SelectedTestAccountNotifier.new,
);

class SelectedTestAccountNotifier extends Notifier<TestAccount?> {
  @override
  TestAccount? build() => null;
}
