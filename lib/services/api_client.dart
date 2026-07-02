import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static String get baseUrl => _baseUrl;

  // Mobile/desktop builds talk to the deployed backend so every feature works
  // like the website. Override for local testing with:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  static const _prodBaseUrl = 'https://fomra-ls.vercel.app';
  static const _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Web production: same origin. Local dev web: hit the API on :3000.
  static String get _baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:3000';
      }
      return Uri.base.origin;
    }
    return _envBaseUrl.isNotEmpty ? _envBaseUrl : _prodBaseUrl;
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

  // Some responses aren't JSON at all — a serverless crash/timeout returns a
  // plain-text page like "A server error has occurred" (HTTP 500) or a gateway
  // HTML page (HTTP 502/504). jsonDecode would throw a FormatException that
  // surfaces to the user as "Unexpected token 'A'…", so parse defensively.
  static dynamic _tryJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _plainErrorMessage(http.Response res) {
    final raw = res.body.trim();
    // Vercel's serverless crash/timeout page — transient, worth retrying.
    if (raw.toLowerCase().contains('a server error has occurred') ||
        res.statusCode == 408 || res.statusCode == 504) {
      return 'The server was busy or took too long. Please tap the plot again.';
    }
    if (raw.isNotEmpty && raw.length < 200 && !raw.startsWith('<')) {
      return raw; // short plain-text server message
    }
    return 'Server error (HTTP ${res.statusCode}). Please try again.';
  }

  static Map<String, dynamic> _decode(http.Response res) {
    final body = _tryJsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(
        statusCode: res.statusCode,
        message: (body is Map ? body['error'] as String? : null) ?? _plainErrorMessage(res),
      );
    }
    if (body == null) {
      // 2xx but not JSON — upstream proxy/error page slipped through.
      throw ApiException(statusCode: res.statusCode, message: _plainErrorMessage(res));
    }
    return body is Map<String, dynamic> ? body : {'data': body};
  }

  static List<dynamic> _decodeList(http.Response res) {
    final body = _tryJsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(
        statusCode: res.statusCode,
        message: (body is Map ? body['error'] as String? : null) ?? _plainErrorMessage(res),
      );
    }
    if (body is List) return body;
    throw ApiException(statusCode: res.statusCode, message: _plainErrorMessage(res));
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
    // Do not send Content-Type on GET — triggers CORS preflight in the browser.
    final headers = <String, String>{'Accept': 'application/pdf,application/octet-stream,*/*'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final uri = Uri.parse('$_baseUrl$path');
    http.Response res;
    try {
      res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 120));
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Could not reach server at ${uri.host}. '
            'Start backend: cd backend && npm start',
      );
    }
    if (res.statusCode >= 400) {
      String message = 'Request failed (HTTP ${res.statusCode})';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['error'] != null) {
          message = body['error'].toString();
          final hint = body['hint']?.toString();
          if (hint != null && hint.isNotEmpty) {
            message = '$message\n$hint';
          }
        }
      } catch (_) {
        if (res.body.isNotEmpty && res.body.length < 500) {
          message = res.body;
        }
      }
      throw ApiException(statusCode: res.statusCode, message: message);
    }
    final bytes = res.bodyBytes;
    if (bytes.length < 100) {
      throw ApiException(
        statusCode: res.statusCode,
        message: 'Empty document response from server',
      );
    }
    // Reject JSON error payloads returned with HTTP 200.
    if (bytes.length >= 2 && bytes[0] == 0x7b) {
      try {
        final body = jsonDecode(String.fromCharCodes(bytes));
        if (body is Map && body['error'] != null) {
          throw ApiException(
            statusCode: res.statusCode,
            message: body['error'].toString(),
          );
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
    }
    if (bytes.length >= 4) {
      final head = String.fromCharCodes(bytes.sublist(0, 4));
      if (head != '%PDF') {
        throw ApiException(
          statusCode: res.statusCode,
          message: 'Server did not return a PDF (got ${head.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')})',
        );
      }
    }
    return bytes;
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
      final body = _tryJsonDecode(res.body);
      throw ApiException(
        statusCode: res.statusCode,
        message: (body is Map ? body['error'] as String? : null) ?? _plainErrorMessage(res),
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
