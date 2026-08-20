import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves customer role and unverified status', () {
    const user = AuthUser(id: 'customer');

    expect(user.role, AppRole.customer);
    expect(user.verificationStatus, VerificationStatus.unknown);
    expect(user.isAdmin, isFalse);
    expect(user.isOwner, isFalse);
  });

  test('preserves venue owner and approved verification', () {
    const user = AuthUser(
      id: 'owner',
      role: AppRole.venueOwner,
      verificationStatus: VerificationStatus.approved,
    );

    expect(user.isOwner, isTrue);
    expect(user.isAdmin, isFalse);
    expect(user.verificationStatus, VerificationStatus.approved);
  });

  test('preserves admin role and elevated access', () {
    const user = AuthUser(
      id: 'admin',
      role: AppRole.admin,
      verificationStatus: VerificationStatus.approved,
    );

    expect(user.isAdmin, isTrue);
    expect(user.isOwner, isTrue);
  });
}
