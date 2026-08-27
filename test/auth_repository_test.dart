import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulsepath/core/network/api_client.dart';
import 'package:pulsepath/features/auth/data/auth_repository.dart';
import 'package:pulsepath/features/auth/data/token_storage.dart';

void main() {
  test('login stores token and returns typed session', () async {
    final storage = MemoryTokenStorage();
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient((request) async {
          expect(request.url.path, '/auth/login');
          return http.Response(jsonEncode(_authResponse), 200);
        }),
      ),
      storage,
    );

    final session = await repository.login(
      email: ' ALEX@EXAMPLE.COM ',
      password: 'password123',
    );

    expect(session.user.email, 'alex@example.com');
    expect(storage.token, 'jwt-token');
    expect(storage.refreshToken, 'refresh-token');
  });

  test('login failure maps backend 401 safely', () async {
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': 'Invalid email or password'}),
            401,
          ),
        ),
      ),
      MemoryTokenStorage(),
    );

    expect(
      () => repository.login(email: 'a@b.com', password: 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('register uses normalized email and persists token', () async {
    final storage = MemoryTokenStorage();
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['email'], 'alex@example.com');
          return http.Response(jsonEncode(_authResponse), 201);
        }),
      ),
      storage,
    );

    await repository.register(
      email: ' Alex@Example.com ',
      password: 'password123',
    );
    expect(storage.token, 'jwt-token');
    expect(storage.refreshToken, 'refresh-token');
  });

  test(
    'forgot password exposes generic result and optional dev token',
    () async {
      final repository = AuthRepository(
        ApiClient(
          baseUrl: 'http://test/',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message': 'If an account exists, instructions were sent.',
                'development_reset_token': 'dev-token',
              }),
              200,
            ),
          ),
        ),
        MemoryTokenStorage(),
      );

      final result = await repository.forgotPassword('alex@example.com');
      expect(result.message, contains('If an account exists'));
      expect(result.developmentToken, 'dev-token');
    },
  );

  test('reset password sends token and new_password contract', () async {
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'token': 'reset-token',
            'new_password': 'new-password',
          });
          return http.Response(jsonEncode({'message': 'Password reset'}), 200);
        }),
      ),
      MemoryTokenStorage(),
    );

    await repository.resetPassword(
      token: 'reset-token',
      newPassword: 'new-password',
    );
  });

  test('valid stored token restores session', () async {
    final storage = MemoryTokenStorage()..token = 'stored-token';
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer stored-token');
          return http.Response(
            jsonEncode({'id': 'user-id', 'email': 'alex@example.com'}),
            200,
          );
        }),
      ),
      storage,
    );

    final user = await repository.restoreSession();
    expect(user?.email, 'alex@example.com');
    expect(storage.token, 'stored-token');
  });

  test('invalid or expired stored token is deleted', () async {
    final storage = MemoryTokenStorage()..token = 'expired-token';
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'detail': 'Invalid'}), 401),
        ),
      ),
      storage,
    );

    expect(await repository.restoreSession(), isNull);
    expect(storage.token, isNull);
  });

  test(
    'temporary session verification failure preserves stored token and restores fallback',
    () async {
      final storage = MemoryTokenStorage()..token = 'stored-token';
      final repository = AuthRepository(
        ApiClient(
          baseUrl: 'http://test/',
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'detail': 'Temporary'}), 503),
          ),
        ),
        storage,
      );

      final user = await repository.restoreSession();
      expect(user, isNotNull);
      expect(storage.token, 'stored-token');
    },
  );

  test('logout clears token', () async {
    final storage = MemoryTokenStorage()..token = 'stored-token';
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient((_) async => http.Response('{}', 200)),
      ),
      storage,
    );
    await repository.logout();
    expect(storage.token, isNull);
  });

  test(
    'logout does not wait for remote revocation before clearing tokens',
    () async {
      final response = Completer<http.Response>();
      final storage = MemoryTokenStorage()
        ..token = 'stored-token'
        ..refreshToken = 'stored-refresh-token';
      final repository = AuthRepository(
        ApiClient(
          baseUrl: 'http://test/',
          client: MockClient((request) {
            expect(request.url.path, '/auth/logout');
            return response.future;
          }),
        ),
        storage,
      );

      await repository.logout().timeout(const Duration(seconds: 1));

      expect(storage.token, isNull);
      expect(storage.refreshToken, isNull);
      response.complete(http.Response('{}', 200));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('loginWithGoogle sends id_token to /auth/google and persists session', () async {
    final storage = MemoryTokenStorage();
    final repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://test/',
        client: MockClient((request) async {
          expect(request.url.path, '/auth/google');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['id_token'], 'valid_google_id_token');
          return http.Response(jsonEncode(_authResponse), 200);
        }),
      ),
      storage,
    );

    final session = await repository.loginWithGoogle('valid_google_id_token');
    expect(session.user.email, 'alex@example.com');
    expect(storage.token, 'jwt-token');
    expect(storage.refreshToken, 'refresh-token');
  });
}

const _authResponse = {
  'user': {'id': 'user-id', 'email': 'alex@example.com'},
  'access_token': 'jwt-token',
  'refresh_token': 'refresh-token',
  'token_type': 'bearer',
};

class MemoryTokenStorage implements TokenStorage {
  String? token;
  String? refreshToken;

  @override
  Future<void> deleteToken() async {
    token = null;
    refreshToken = null;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveToken(String token, [String? refreshToken]) async {
    this.token = token;
    if (refreshToken != null) this.refreshToken = refreshToken;
  }
}
