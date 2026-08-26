class AuthUser {
  const AuthUser({required this.id, required this.email, this.phoneNumber});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      phoneNumber: json['phone_number'] as String?,
    );
  }

  final String id;
  final String email;
  final String? phoneNumber;
}
