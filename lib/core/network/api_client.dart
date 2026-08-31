import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/token_storage.dart';
import 'api_config.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final unauthorizedProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    baseUrl: ApiConfig.baseUrl,
    client: ref.watch(httpClientProvider),
    authTokenProvider: tokenStorage.readToken,
    refreshTokenProvider: tokenStorage.readRefreshToken,
    onTokenRefreshed: (access, refresh) =>
        tokenStorage.saveToken(access, refresh),
    onUnauthorized: () {
      ref.read(unauthorizedProvider.notifier).state = true;
    },
  );
});

class ApiClient {
  ApiClient({
    required String baseUrl,
    required http.Client client,
    this.authTokenProvider,
    this.refreshTokenProvider,
    this.onTokenRefreshed,
    this.onUnauthorized,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _baseUri = Uri.parse(baseUrl),
       _httpClient = client;

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration requestTimeout;
  final Future<String?> Function()? authTokenProvider;
  final Future<String?> Function()? refreshTokenProvider;
  final Future<void> Function(String accessToken, String refreshToken)?
  onTokenRefreshed;
  final void Function()? onUnauthorized;

  Completer<String?>? _refreshCompleter;

  Future<Map<String, String>> _buildHeaders([String? manualToken]) async {
    final headers = {'Content-Type': 'application/json'};
    final token = manualToken ?? await authTokenProvider?.call();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _resolveUri(String path) {
    final base = _baseUri.toString();
    final cleanBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final headers = await _buildHeaders();
    final decodedBody = await _requestDecoded(
      (h) => _httpClient.get(_resolveUri(path), headers: h),
      initialHeaders: headers,
    );
    if (decodedBody is! Map<String, dynamic>) {
      throw const NetworkException('Response format was invalid.');
    }
    return decodedBody;
  }

  Future<Map<String, dynamic>> getJsonWithBearer(
    String path,
    String token,
  ) async {
    final headers = await _buildHeaders(token);
    final decodedBody = await _requestDecoded(
      (h) => _httpClient.get(_resolveUri(path), headers: h),
      initialHeaders: headers,
      skipRefresh: true,
    );
    if (decodedBody is! Map<String, dynamic>) {
      throw const NetworkException('Response format was invalid.');
    }
    return decodedBody;
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final headers = await _buildHeaders();
    final decodedBody = await _requestDecoded(
      (h) => _httpClient.patch(
        _resolveUri(path),
        headers: h,
        body: jsonEncode(body),
      ),
      initialHeaders: headers,
    );
    if (decodedBody is! Map<String, dynamic>) {
      throw const NetworkException('Response format was invalid.');
    }
    return decodedBody;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final headers = await _buildHeaders();
    final decodedBody = await _requestDecoded(
      (h) => _httpClient.post(
        _resolveUri(path),
        headers: h,
        body: jsonEncode(body),
      ),
      initialHeaders: headers,
      skipRefresh: path.startsWith('/auth/'),
    );
    if (decodedBody is! Map<String, dynamic>) {
      throw const NetworkException('Response format was invalid.');
    }
    return decodedBody;
  }

  Future<void> delete(String path) async {
    final headers = await _buildHeaders();
    await _send(
      (h) => _httpClient.delete(_resolveUri(path), headers: h),
      initialHeaders: headers,
    );
  }

  Future<List<Map<String, dynamic>>> getJsonList(String path) async {
    final headers = await _buildHeaders();
    final decodedBody = await _requestDecoded(
      (h) => _httpClient.get(_baseUri.resolve(path), headers: h),
      initialHeaders: headers,
    );
    if (decodedBody is! List) {
      throw const NetworkException('Response format was invalid.');
    }

    try {
      return decodedBody.cast<Map<String, dynamic>>();
    } on TypeError {
      throw const NetworkException('Response format was invalid.');
    }
  }

  Future<Object?> _requestDecoded(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required Map<String, String> initialHeaders,
    bool skipRefresh = false,
  }) async {
    final response = await _send(
      send,
      initialHeaders: initialHeaders,
      skipRefresh: skipRefresh,
    );
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const NetworkException('Response format was invalid.');
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required Map<String, String> initialHeaders,
    bool skipRefresh = false,
  }) async {
    try {
      var response = await send(initialHeaders).timeout(requestTimeout);

      // Handle 401 Single-Flight Refresh
      if (response.statusCode == 401 && !skipRefresh) {
        final newToken = await _performSingleFlightRefresh();
        if (newToken != null) {
          final retriedHeaders = Map<String, String>.from(initialHeaders);
          retriedHeaders['Authorization'] = 'Bearer $newToken';
          response = await send(retriedHeaders).timeout(requestTimeout);
        } else {
          onUnauthorized?.call();
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
            detail = decoded['detail'] as String;
          }
        } on FormatException {
          // Keep default status message
        }
        throw NetworkException(
          'Request failed with status ${response.statusCode}.',
          statusCode: response.statusCode,
          detail: detail,
        );
      }

      return response;
    } on NetworkException {
      rethrow;
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[NETWORKING_AUDIT] TimeoutException | type: ${e.runtimeType}',
        );
      }
      throw const NetworkException('Request timed out.');
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[NETWORKING_AUDIT] SocketException | type: ${e.runtimeType}',
        );
      }
      throw const NetworkException('Could not connect to the server.');
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[NETWORKING_AUDIT] ClientException | type: ${e.runtimeType}',
        );
      }
      throw const NetworkException('Could not connect to the server.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NETWORKING_AUDIT] Exception | type: ${e.runtimeType}');
      }
      throw const NetworkException('Could not connect to the server.');
    }
  }

  Future<String?> _performSingleFlightRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    try {
      final refreshToken = await refreshTokenProvider?.call();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final response = await _httpClient
          .post(
            _resolveUri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = decoded['access_token'] as String;
        final newRefresh = decoded['refresh_token'] as String;
        await onTokenRefreshed?.call(newAccess, newRefresh);
        _refreshCompleter!.complete(newAccess);
        return newAccess;
      } else {
        _refreshCompleter!.complete(null);
        return null;
      }
    } on Object {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}

class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'NetworkException: $message';
}
