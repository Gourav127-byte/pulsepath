import '../../../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';
import 'token_storage.dart';

class AuthRepository {
  const AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthSession> login({required String email, required String password}) {
    return _authenticate('/auth/login', email: email, password: password);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/register', email: email, password: password);
  }

  Future<AuthSession> _authenticate(
    String path, {
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.postJson(path, {
        'email': email.trim().toLowerCase(),
        'password': password,
      });
      final session = AuthSession.fromJson(response);
      await _tokenStorage.saveToken(session.accessToken);
      return session;
    } on NetworkException catch (error) {
      throw AuthException(_messageFor(error));
    } on Object {
      throw const AuthException('The server returned an invalid response.');
    }
  }

  Future<ForgotPasswordResult> forgotPassword(String email) async {
    try {
      final response = await _apiClient.postJson('/auth/forgot-password', {
        'email': email.trim().toLowerCase(),
      });
      return ForgotPasswordResult(
        message: response['message'] as String,
        developmentToken: response['development_reset_token'] as String?,
      );
    } on NetworkException catch (error) {
      throw AuthException(_messageFor(error));
    } on Object {
      throw const AuthException('The server returned an invalid response.');
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _apiClient.postJson('/auth/reset-password', {
        'token': token.trim(),
        'new_password': newPassword,
      });
    } on NetworkException catch (error) {
      throw AuthException(_messageFor(error));
    }
  }

  Future<AuthUser?> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await _apiClient.getJsonWithBearer('/auth/me', token);
      return AuthUser.fromJson(response);
    } on NetworkException catch (error) {
      if (error.statusCode != 401) {
        throw const AuthException(
          'Could not verify your session. Check your connection and retry.',
        );
      }
      try {
        await _tokenStorage.deleteToken();
      } on Object {
        // A platform storage failure must not trap startup on session checking.
      }
      return null;
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException('The server returned an invalid response.');
    }
  }

  Future<void> logout() => _tokenStorage.deleteToken();

  String _messageFor(NetworkException error) {
    if (error.statusCode == 401) {
      return 'Invalid email or password.';
    }
    if (error.statusCode == 409) {
      return 'An account with this email already exists.';
    }
    if (error.statusCode == 400) {
      return 'The reset token is invalid or expired.';
    }
    if (error.statusCode == 422) {
      return 'Please check the information you entered.';
    }
    if (error.statusCode != null && error.statusCode! >= 500) {
      return 'PulsePath is temporarily unavailable. Please try again.';
    }
    return error.message;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}
