import 'package:flutter_test/flutter_test.dart';
import '../../support/auth_boundary_identity.dart';

void main() {
  test('boundary identities are deterministic and never represent Auth sessions', () {
    expect(AuthBoundaryIdentity.customer.userId, 'TEST_BOUNDARY_CUSTOMER');
    expect(AuthBoundaryIdentity.owner.organizationId, 'TEST_BOUNDARY_ORGANIZATION');
    expect(AuthBoundaryIdentity.administrator.applicationUser?.isAdmin, isTrue);
    expect(AuthBoundaryIdentity.unauthenticated.applicationUser, isNull);
  });
}
