import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<void> saveToken(String token);
  Future<String?> readToken();
  Future<void> deleteToken();
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const SecureTokenStorage(),
);

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  static const _tokenKey = 'pulsepath_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
