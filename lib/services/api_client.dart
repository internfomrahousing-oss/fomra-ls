import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static String get baseUrl => _baseUrl;

  // Web production: same origin. Local dev: always hit the API on :3000.
  static String get _baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:3000';
      }
      return origin;
    }
    return 'http://localhost:3000';
  }

  static const String _tokenKey = 'auth_token';

  // ── Token storage ──────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── HTTP helpers ───────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(
        statusCode: res.statusCode,
        message: (body is Map ? body['error'] as String? : null) ?? 'Request failed',
      );
    }
    return body is Map<String, dynamic> ? body : {'data': body};
  }

  static List<dynamic> _decodeList(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw ApiException(
        statusCode: res.statusCode,
        message: (body is Map ? body['error'] as String? : null) ?? 'Request failed',
      );
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: await _headers(),
        )
        .timeout(timeout);
    return _decode(res);
  }

  static Future<List<dynamic>> getList(String path) async {
    final res = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    );
    return _decodeList(res);
  }

  /// Raw bytes (e.g. government PDF from /api/tnlands/fmb).
  static Future<List<int>> getBytes(String path, {bool auth = false}) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: await _headers(auth: auth),
        )
        .timeout(const Duration(seconds: 120));
    if (res.statusCode >= 400) {
      try {
        final body = jsonDecode(res.body);
        throw ApiException(
          statusCode: res.statusCode,
          message: (body is Map ? body['error'] as String? : null) ?? 'Request failed',
        );
      } catch (_) {
        throw ApiException(statusCode: res.statusCode, message: 'Request failed');
      }
    }
    return res.bodyBytes;
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  static Future<void> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw ApiException(
        statusCode: res.statusCode,
        message: (body is Map ? body['error'] as String? : null) ?? 'Delete failed',
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
