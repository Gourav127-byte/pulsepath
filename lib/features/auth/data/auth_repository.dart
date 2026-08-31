import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/cache/temporary_demo_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';
import 'token_storage.dart';

class PhoneOTPResult {
  const PhoneOTPResult({
    required this.message,
    required this.cooldownSeconds,
    this.developmentOtp,
  });

  final String message;
  final int cooldownSeconds;
  final String? developmentOtp;
}

class EmailOTPResult {
  const EmailOTPResult({
    required this.message,
    required this.cooldownSeconds,
    this.developmentOtp,
  });

  final String message;
  final int cooldownSeconds;
  final String? developmentOtp;
}

class AuthRepository {
  const AuthRepository(this._apiClient, this._tokenStorage, [this._cache]);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final TemporaryDemoCache? _cache;

  Future<AuthSession> login({required String email, required String password}) {
    return _authenticate('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/register', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  Future<PhoneOTPResult> requestPhoneOTP(String phone) async {
    try {
      final response = await _apiClient.postJson('/auth/phone/request-otp', {
        'phone_number': phone,
      });
      return PhoneOTPResult(
        message: (response['message'] as String?) ?? 'OTP dispatched',
        cooldownSeconds: (response['cooldown_seconds'] as int?) ?? 60,
        developmentOtp: response['development_otp'] as String?,
      );
    } on NetworkException catch (error) {
      throw AuthException(_messageFor(error));
    } on Object {
      throw const AuthException('The server returned an invalid response.');
    }
  }

  Future<AuthSession> verifyPhoneOTP(String phone, String otp) async {
    return _authenticate('/auth/phone/verify-otp', {
      'phone_number': phone,
      'otp': otp.trim(),
    });
  }

  Future<EmailOTPResult> requestEmailOTP(String email) async {
    try {
      final response = await _apiClient.postJson('/auth/email/request-otp', {
        'email': email.trim().toLowerCase(),
      });
      return EmailOTPResult(
        message: (response['message'] as String?) ?? 'OTP dispatched',
        cooldownSeconds: (response['cooldown_seconds'] as int?) ?? 60,
        developmentOtp: response['development_otp'] as String?,
      );
    } on NetworkException catch (error) {
      throw AuthException(_messageFor(error));
    } on Object {
      throw const AuthException('The server returned an invalid response.');
    }
  }

  Future<AuthSession> verifyEmailOTP(String email, String otp) async {
    return _authenticate('/auth/email/verify-otp', {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });
  }

  Future<AuthSession> loginWithGoogle(String idToken) async {
    return _authenticate('/auth/google', {'id_token': idToken});
  }

  static bool _googleSignInInFlight = false;

  Future<AuthSession> signInWithGoogleNative() async {
    if (_googleSignInInFlight) {
      throw const AuthException('Google sign in is already in progress.');
    }
    _googleSignInInFlight = true;
    try {
      final clientId = ApiConfig.googleClientId.isNotEmpty
          ? ApiConfig.googleClientId
          : null;
      final googleSignIn = GoogleSignIn(
        serverClientId: clientId,
        scopes: ['email'],
      );
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // Ignore silent sign-out errors to allow clean account chooser presentation
      }
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Google sign in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Could not retrieve Google ID token.');
      }
      return await loginWithGoogle(idToken);
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException('Google Sign-In failed: $error');
    } finally {
      _googleSignInInFlight = false;
    }
  }

  Future<AuthSession> _authenticate(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await _apiClient.postJson(path, body);
      final session = AuthSession.fromJson(response);
      final cacheFuture = _cache?.saveProfile({
        'id': session.user.id,
        'email': session.user.email,
      });
      await _tokenStorage.saveToken(session.accessToken, session.refreshToken);
      if (cacheFuture != null) await cacheFuture;
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
      final user = AuthUser.fromJson(response);
      await _cache?.saveProfile({'id': user.id, 'email': user.email});
      return user;
    } on NetworkException catch (error) {
      if (error.statusCode == 401) {
        try {
          await _tokenStorage.deleteToken();
        } on Object {
          // The session is still rejected even if secure-storage cleanup fails.
        }
        return null;
      }
      // OFFLINE / UNREACHABLE BACKEND: Preserve session and restore cached profile if available.
      final cached = await _cache?.loadProfile();
      if (cached != null && cached['id'] is String) {
        return AuthUser(
          id: cached['id'] as String,
          email: (cached['email'] as String?) ?? '',
        );
      }
      // If no cached profile and backend is unreachable, do not synthesize a fake user.
      return null;
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException('The server returned an invalid response.');
    }
  }

  Future<void> logout() async {
    final refresh = await _tokenStorage.readRefreshToken();
    // Local logout is authoritative for UI/session state. Never keep the user
    // signed in while an optional server-side refresh-token revocation waits on
    // a slow or unavailable network.
    await _tokenStorage.deleteToken();
    if (refresh != null) {
      unawaited(_revokeRefreshToken(refresh));
    }
  }

  Future<void> _revokeRefreshToken(String refresh) async {
    try {
      await _apiClient.postJson('/auth/logout', {'refresh_token': refresh});
    } on Object {
      // The local credentials are already gone. Server revocation is
      // best-effort and expiry remains the final fallback.
    }
  }

  String _messageFor(NetworkException error) {
    if (error.statusCode == 401) {
      return error.message.isNotEmpty && error.message != 'Unauthorized'
          ? error.message
          : 'Invalid credentials.';
    }
    if (error.statusCode == 409) {
      return 'An account with this email or phone already exists.';
    }
    if (error.statusCode == 400) {
      return 'The code or token is invalid or expired.';
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
