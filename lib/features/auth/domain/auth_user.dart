/// An authenticated user in the application.
///
/// NOTE: Freezed/JsonSerializable codegen is configured but was not run in
/// this environment. The class is hand-written to stay dependency-free.
class AuthUser {
  const AuthUser({
    required this.id,
    this.email = '',
    this.phone = '',
    this.fullName = '',
    this.avatarUrl = '',
  });

  final String id;
  final String email;
  final String phone;
  final String fullName;
  final String avatarUrl;

  AuthUser copyWith({
    String? id,
    String? email,
    String? phone,
    String? fullName,
    String? avatarUrl,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'avatar_url': avatarUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}
