/// Owner domain model (separate profile from user auth).
class Owner {
  const Owner({
    required this.id,
    required this.userId,
    required this.email,
    required this.name,
  });

  final String id;
  final String userId;
  final String email;
  final String name;

  factory Owner.fromJson(Map<String, dynamic> json) => Owner(
    id: json['id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );
}

/// Contract for owner repository.
abstract interface class OwnerRepository {
  /// Create a new owner profile for the current user.
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
  });

  /// Get the current owner profile, if any.
  Future<Owner?> currentOwner();

  /// Sign in with email/password for owners.
  Future<Owner> signInWithEmailPassword(String email, String password);

  /// Sign out from owner session.
  Future<void> signOut();

  /// Delete the owner profile and associated auth user.
  Future<void> deleteOwner();
}
