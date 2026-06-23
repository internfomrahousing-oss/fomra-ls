import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import 'api_client.dart'; // for ApiException

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static SupabaseClient get _client => Supabase.instance.client;

  AppUser? get currentUser {
    final u = _client.auth.currentUser;
    if (u == null) return null;
    return AppUser(
      id: u.id,
      email: u.email ?? '',
      fullName: u.userMetadata?['full_name'] as String? ??
          u.email?.split('@').first ??
          'User',
      phone: u.userMetadata?['phone'] as String?,
      role: u.userMetadata?['role'] as String? ?? 'agent',
      createdAt: DateTime.parse(u.createdAt),
    );
  }

  bool get isLoggedIn => _client.auth.currentSession != null;

  /// Restores an existing Supabase session (persisted automatically by SDK).
  Future<bool> restoreSession() async {
    return _client.auth.currentSession != null;
  }

  // Fallback credentials used when Supabase is unreachable or no user created yet
  static const _fallbackEmail    = 'info@fomrahousing.in';
  static const _fallbackPassword = 'Fomra@2024';

  /// Throws [ApiException] on failure so existing UI error handling works.
  Future<bool> login(String email, String password) async {
    // Try Supabase first
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      // If Supabase rejects but local fallback matches, allow entry
      if (email.trim().toLowerCase() == _fallbackEmail &&
          password == _fallbackPassword) {
        return true;
      }
      throw ApiException(statusCode: 401, message: e.message);
    } catch (e) {
      // Network error / Supabase unreachable — try fallback
      if (email.trim().toLowerCase() == _fallbackEmail &&
          password == _fallbackPassword) {
        return true;
      }
      throw const ApiException(
          statusCode: 500, message: 'Connection error. Check your internet.');
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = 'agent',
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, if (phone != null) 'phone': phone, 'role': role},
      );
      return true;
    } on AuthException catch (e) {
      throw ApiException(statusCode: 400, message: e.message);
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
