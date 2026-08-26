import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../data/token_storage.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';

enum AuthStatus { checking, unauthenticated, loading, authenticated, error }

class AuthState {
  const AuthState(this.status, {this.user, this.message});

  const AuthState.checking() : this(AuthStatus.checking);
  const AuthState.unauthenticated() : this(AuthStatus.unauthenticated);

  final AuthStatus status;
  final AuthUser? user;
  final String? message;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.watch(authRepositoryProvider));
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.checking()) {
    restoreSession();
  }

  AuthController.forTesting(super.initialState) : _repository = null;

  final AuthRepository? _repository;

  Future<void> restoreSession() async {
    state = const AuthState.checking();
    try {
      final user = await _repository!.restoreSession();
      state = user == null
          ? const AuthState.unauthenticated()
          : AuthState(AuthStatus.authenticated, user: user);
    } on AuthException catch (error) {
      state = AuthState(AuthStatus.error, message: error.message);
    }
  }

  Future<bool> login(String email, String password) =>
      _authenticate(() => _repository!.login(email: email, password: password));

  Future<bool> register(String email, String password) => _authenticate(
    () => _repository!.register(email: email, password: password),
  );

  Future<bool> _authenticate(Future<AuthSession> Function() action) async {
    if (state.status == AuthStatus.loading) return false;
    state = const AuthState(AuthStatus.loading);
    try {
      final session = await action();
      state = AuthState(AuthStatus.authenticated, user: session.user);
      return true;
    } on AuthException catch (error) {
      state = AuthState(AuthStatus.error, message: error.message);
      return false;
    }
  }

  void clearError() => state = const AuthState.unauthenticated();

  void setSession(AuthSession session) {
    state = AuthState(AuthStatus.authenticated, user: session.user);
  }

  Future<void> logout() async {
    await _repository!.logout();
    state = const AuthState.unauthenticated();
  }
}
