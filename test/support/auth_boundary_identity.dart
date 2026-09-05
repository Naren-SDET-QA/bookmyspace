import 'package:bookmyspace/features/auth/domain/auth_user.dart';

/// Deterministic application-boundary identities for tests only.
/// These values never authenticate against Supabase Auth.
enum AuthBoundaryRole { unauthenticated, customer, owner, administrator }

class AuthBoundaryIdentity {
  const AuthBoundaryIdentity._({
    required this.role,
    this.userId,
    this.organizationId,
    this.venueId,
  });

  final AuthBoundaryRole role;
  final String? userId;
  final String? organizationId;
  final String? venueId;

  static const unauthenticated = AuthBoundaryIdentity._(
    role: AuthBoundaryRole.unauthenticated,
  );
  static const customer = AuthBoundaryIdentity._(
    role: AuthBoundaryRole.customer,
    userId: 'TEST_BOUNDARY_CUSTOMER',
  );
  static const owner = AuthBoundaryIdentity._(
    role: AuthBoundaryRole.owner,
    userId: 'TEST_BOUNDARY_OWNER',
    organizationId: 'TEST_BOUNDARY_ORGANIZATION',
    venueId: 'TEST_BOUNDARY_OWNER_VENUE',
  );
  static const administrator = AuthBoundaryIdentity._(
    role: AuthBoundaryRole.administrator,
    userId: 'TEST_BOUNDARY_ADMIN',
  );

  AuthUser? get applicationUser => switch (role) {
    AuthBoundaryRole.unauthenticated => null,
    AuthBoundaryRole.customer => const AuthUser(
      id: 'TEST_BOUNDARY_CUSTOMER',
      email: 'boundary.customer@test.invalid',
    ),
    AuthBoundaryRole.owner => const AuthUser(
      id: 'TEST_BOUNDARY_OWNER',
      email: 'boundary.owner@test.invalid',
      role: AppRole.venueOwner,
      verificationStatus: VerificationStatus.approved,
    ),
    AuthBoundaryRole.administrator => const AuthUser(
      id: 'TEST_BOUNDARY_ADMIN',
      email: 'boundary.admin@test.invalid',
      role: AppRole.admin,
      verificationStatus: VerificationStatus.approved,
    ),
  };
}
