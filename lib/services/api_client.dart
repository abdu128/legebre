import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'auth_storage.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AuthStorage? storage,
  })  : _client = httpClient ?? http.Client(),
        _storage = storage ?? AuthStorage();

  final http.Client _client;
  final AuthStorage _storage;

  static const baseUrl = 'https://legeber-backend.onrender.com';

  Future<String?> get token async => _cachedToken ??= await _storage.readToken();
  String? _cachedToken;

  void cacheToken(String? token) {
    _cachedToken = token;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Future<Map<String, String>> _headers({bool authorized = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authorized) {
      final value = await token;
      if (value == null || value.isEmpty) {
        throw ApiException('You need to log in first');
      }
      headers['Authorization'] = 'Bearer $value';
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool authorized = false,
  }) async {
    final response = await _client.get(
      _buildUri(path, query),
      headers: await _headers(authorized: authorized),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String path, {
    bool authorized = false,
  }) async {
    final response = await _client.delete(
      _buildUri(path),
      headers: await _headers(authorized: authorized),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authorized = false,
  }) async {
    final response = await _client.post(
      _buildUri(path),
      headers: await _headers(authorized: authorized),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool authorized = false,
  }) async {
    final response = await _client.put(
      _buildUri(path),
      headers: await _headers(authorized: authorized),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authorized = false,
  }) async {
    final response = await _client.patch(
      _buildUri(path),
      headers: await _headers(authorized: authorized),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> uploadMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    bool authorized = false,
    String method = 'POST',
  }) async {
    final request = http.MultipartRequest(method, _buildUri(path))
      ..fields.addAll(fields);

    for (final file in files) {
      request.files.add(file);
    }

    final headers = await _headers(authorized: authorized);
    headers.remove('Content-Type'); // multipart sets its own boundary header
    request.headers.addAll(headers);

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    String message = 'Unexpected error ($statusCode)';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      } else if (body is Map && body['error'] != null) {
        message = body['error'].toString();
      } else if (body is String) {
        message = body;
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }
    throw ApiException(message, statusCode: statusCode);
  }
}


