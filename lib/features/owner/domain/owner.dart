/// Owner domain model (separate profile from user auth).
class Owner {
  const Owner({
    required this.id,
    required this.userId,
    required this.email,
    required this.name,
    this.phone = '',
    this.whatsapp = '',
    this.businessName = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.photoUrl = '',
    this.latitude,
    this.longitude,
    this.orgId = '',
  });

  final String id;
  final String userId;
  final String email;
  final String name;
  final String phone;
  final String whatsapp;
  final String businessName;
  final String address;
  final String city;
  final String state;
  final String photoUrl;
  final double? latitude;
  final double? longitude;
  final String orgId;

  factory Owner.fromJson(Map<String, dynamic> json) => Owner(
    id: json['id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    whatsapp: json['whatsapp'] as String? ?? '',
    businessName: json['business_name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    city: json['city'] as String? ?? '',
    state: json['state'] as String? ?? '',
    photoUrl: json['photo_url'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    orgId: json['org_id'] as String? ?? '',
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

  Future<Owner> saveProfile(Owner owner);
}
