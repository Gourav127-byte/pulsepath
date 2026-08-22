import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    this.onUnauthorized,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _baseUri = Uri.parse(baseUrl),
       _httpClient = client;

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration requestTimeout;
  final Future<String?> Function()? authTokenProvider;
  final void Function()? onUnauthorized;

  Future<Map<String, String>> _buildHeaders([String? manualToken]) async {
    final headers = {'Content-Type': 'application/json'};
    final token = manualToken ?? await authTokenProvider?.call();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final headers = await _buildHeaders();
    final decodedBody = await _requestDecoded(
      () => _httpClient.get(_baseUri.resolve(path), headers: headers),
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
      () => _httpClient.get(_baseUri.resolve(path), headers: headers),
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
      () => _httpClient.patch(
        _baseUri.resolve(path),
        headers: headers,
        body: jsonEncode(body),
      ),
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
      () => _httpClient.post(
        _baseUri.resolve(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    if (decodedBody is! Map<String, dynamic>) {
      throw const NetworkException('Response format was invalid.');
    }
    return decodedBody;
  }

  Future<void> delete(String path) async {
    final headers = await _buildHeaders();
    await _send(
      () => _httpClient.delete(_baseUri.resolve(path), headers: headers),
    );
  }

  Future<List<Map<String, dynamic>>> getJsonList(String path) async {
    final headers = await _buildHeaders();
    final decodedBody = await _requestDecoded(
      () => _httpClient.get(_baseUri.resolve(path), headers: headers),
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

  Future<Object?> _requestDecoded(Future<http.Response> Function() send) async {
    final response = await _send(send);
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const NetworkException('Response format was invalid.');
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() send) async {
    try {
      final response = await send().timeout(requestTimeout);

      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
            detail = decoded['detail'] as String;
          }
        } on FormatException {
          // Keep the safe status-based error when the backend body is invalid.
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
    } on TimeoutException {
      throw const NetworkException('Request timed out.');
    } on SocketException {
      throw const NetworkException('Could not connect to the server.');
    } on http.ClientException {
      throw const NetworkException('Could not connect to the server.');
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
