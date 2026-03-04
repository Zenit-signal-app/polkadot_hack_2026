import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../auth/auth_local_storage.dart';

class ApiClient {
  static String get baseUrl {
    final value = dotenv.env['API_BASE_URL'];
    if (value == null || value.isEmpty) {
      return 'https://zenit-api.seerbot.io/';
    }
    return value;
  }
  
  final http.Client _client;
  final AuthLocalStorage _authLocalStorage;
  String? _authToken;

  ApiClient({http.Client? client, AuthLocalStorage? authLocalStorage})
      : _client = client ?? http.Client(),
        _authLocalStorage = authLocalStorage ?? AuthLocalStorage();
  
  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Uri _buildUri(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) {
    final baseUri = Uri.parse(baseUrl);
    final basePath = baseUri.path;
    final normalizedBasePath = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    final mergedPath = normalizedEndpoint.isEmpty
        ? normalizedBasePath
        : (normalizedBasePath.isEmpty
            ? '/$normalizedEndpoint'
            : '$normalizedBasePath/$normalizedEndpoint');

    return baseUri.replace(
      path: mergedPath,
      queryParameters: queryParameters == null
          ? null
          : queryParameters.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
    );
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final url = _buildUri(endpoint, queryParameters: queryParameters);
      log('GET: $url');
      
      final response = await _client.get(url, headers: _headers);
      
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && await _refreshAccessTokenIfNeeded()) {
        final url = _buildUri(endpoint, queryParameters: queryParameters);
        final retryResponse = await _client.get(url, headers: _headers);
        return _handleResponse(retryResponse);
      }
      rethrow;
    } catch (e) {
      log('GET Error: $e');
      rethrow;
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = _buildUri(endpoint);
      log('POST: $url');
      log('Body: $body');
      
      final response = await _client.post(
        url,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && await _refreshAccessTokenIfNeeded()) {
        final url = _buildUri(endpoint);
        final retryResponse = await _client.post(
          url,
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
        return _handleResponse(retryResponse);
      }
      rethrow;
    } catch (e) {
      log('POST Error: $e');
      rethrow;
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = _buildUri(endpoint);
      log('PUT: $url');
      
      final response = await _client.put(
        url,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && await _refreshAccessTokenIfNeeded()) {
        final url = _buildUri(endpoint);
        final retryResponse = await _client.put(
          url,
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
        return _handleResponse(retryResponse);
      }
      rethrow;
    } catch (e) {
      log('PUT Error: $e');
      rethrow;
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = _buildUri(endpoint);
      log('DELETE: $url');
      log('Body: $body');
      
      final response = await _client.delete(
        url,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && await _refreshAccessTokenIfNeeded()) {
        final url = _buildUri(endpoint);
        final retryResponse = await _client.delete(
          url,
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
        return _handleResponse(retryResponse);
      }
      rethrow;
    } catch (e) {
      log('DELETE Error: $e');
      rethrow;
    }
  }

  Future<bool> _refreshAccessTokenIfNeeded() async {
    final localSession = await _authLocalStorage.loadSession();
    final refreshToken = localSession.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final refreshEndpoint = dotenv.env['API_REFRESH_ENDPOINT']?.trim();
    final endpoint = (refreshEndpoint == null || refreshEndpoint.isEmpty)
      ? 'auth/refresh'
        : refreshEndpoint;

    final url = _buildUri(endpoint);
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'refreshToken': refreshToken,
        'refresh_token': refreshToken,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    if (response.body.isEmpty) {
      return false;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    final nextAccessToken = _extractToken(decoded, [
      'accessToken',
      'access_token',
    ]);
    if (nextAccessToken == null || nextAccessToken.isEmpty) {
      return false;
    }

    final nextRefreshToken =
        _extractToken(decoded, ['refreshToken', 'refresh_token']);

    _authToken = nextAccessToken;
    await _authLocalStorage.updateTokens(
      accessToken: nextAccessToken,
      refreshToken: nextRefreshToken,
    );

    return true;
  }

  String? _extractToken(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    final data = source['data'];
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    final tokens = source['tokens'];
    if (tokens is Map<String, dynamic>) {
      for (final key in keys) {
        final value = tokens[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  dynamic _handleResponse(http.Response response) {
    log('Response status: ${response.statusCode}');
    log('Response body: ${response.body}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _getErrorMessage(response),
      );
    }
  }

  String _getErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['message'] ?? body['error'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Error: ${response.statusCode}';
    }
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}
