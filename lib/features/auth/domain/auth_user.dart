/// An authenticated user in the application.
///
/// NOTE: Freezed/JsonSerializable codegen is configured but was not run in
/// this environment. The class is hand-written to stay dependency-free.
enum AppRole { customer, venueOwner, admin }

enum VerificationStatus { pending, submitted, approved, rejected, unknown }

class AuthUser {
  const AuthUser({
    required this.id,
    this.email = '',
    this.phone = '',
    this.fullName = '',
    this.avatarUrl = '',
    this.role = AppRole.customer,
    this.verificationStatus = VerificationStatus.unknown,
  });

  final String id;
  final String email;
  final String phone;
  final String fullName;
  final String avatarUrl;
  final AppRole role;
  final VerificationStatus verificationStatus;

  bool get isAdmin => role == AppRole.admin;
  bool get isOwner => role == AppRole.venueOwner || isAdmin;

  AuthUser copyWith({
    String? id,
    String? email,
    String? phone,
    String? fullName,
    String? avatarUrl,
    AppRole? role,
    VerificationStatus? verificationStatus,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String? ?? '',
    role: _role(json['role'] as String?),
    verificationStatus: _verification(json['verification_status'] as String?),
  );

  static AppRole _role(String? value) => switch (value) {
    'admin' || 'administrator' || 'super_administrator' => AppRole.admin,
    'venue_owner' ||
    'institute_owner' ||
    'event_organizer' => AppRole.venueOwner,
    _ => AppRole.customer,
  };

  static VerificationStatus _verification(String? value) =>
      VerificationStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => VerificationStatus.unknown,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'role': role.name,
    'verification_status': verificationStatus.name,
  };

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}
