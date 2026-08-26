import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
    );
  }

  final AuthUser user;
  final String accessToken;
  final String? refreshToken;
}

class ForgotPasswordResult {
  const ForgotPasswordResult({required this.message, this.developmentToken});

  final String message;
  final String? developmentToken;
}
