import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import 'api_client.dart';

enum LoginPortal { employee, management }

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _portalKey = 'login_portal';
  static const _localSessionKey = 'local_auth_session';

  static const managementEmail = 'management@fomrahousing.in';
  static const employeeEmail = 'employee@fomrahousing.in';
  static const portalPassword = 'fomra@2024';

  static SupabaseClient get _client => Supabase.instance.client;

  LoginPortal? _portal;

  LoginPortal? get loginPortal => _portal;

  bool get isManagement => _portal == LoginPortal.management;
  bool get isEmployee => _portal == LoginPortal.employee;

  static String emailForPortal(LoginPortal portal) => switch (portal) {
        LoginPortal.management => managementEmail,
        LoginPortal.employee => employeeEmail,
      };

  AppUser? get currentUser {
    final u = _client.auth.currentUser;
    if (u != null) {
      return AppUser(
        id: u.id,
        email: u.email ?? '',
        fullName: u.userMetadata?['full_name'] as String? ??
            u.email?.split('@').first ??
            'User',
        phone: u.userMetadata?['phone'] as String?,
        role: u.userMetadata?['role'] as String? ??
            (_portal == LoginPortal.management ? 'management' : 'employee'),
        createdAt: DateTime.parse(u.createdAt),
      );
    }
    if (_portal != null) {
      final email = emailForPortal(_portal!);
      return AppUser(
        id: 'local-${_portal!.name}',
        email: email,
        fullName: _portal == LoginPortal.management ? 'Management' : 'Employee',
        role: _portal == LoginPortal.management ? 'management' : 'employee',
        createdAt: DateTime.now(),
      );
    }
    return null;
  }

  bool get isLoggedIn =>
      _client.auth.currentUser != null || _portal != null;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final portalName = prefs.getString(_portalKey);
    if (portalName == LoginPortal.management.name) {
      _portal = LoginPortal.management;
    } else if (portalName == LoginPortal.employee.name) {
      _portal = LoginPortal.employee;
    }

    final authEmail = _client.auth.currentUser?.email?.trim().toLowerCase();
    if (authEmail == managementEmail) {
      _portal = LoginPortal.management;
    } else if (authEmail == employeeEmail) {
      _portal = LoginPortal.employee;
    }

    final local = prefs.getBool(_localSessionKey) ?? false;
    if (!local && _client.auth.currentUser == null) {
      _portal = null;
      await prefs.remove(_portalKey);
    }
  }

  Future<bool> checkSession() async {
    await restoreSession();
    if (_client.auth.currentUser != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_localSessionKey) ?? false) && _portal != null;
  }

  Future<void> loginWithPortal(
    String email,
    String password,
    LoginPortal portal,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    final expectedEmail = emailForPortal(portal);

    if (normalizedEmail != expectedEmail) {
      throw const ApiException(
        statusCode: 401,
        message: 'Invalid email for this portal.',
      );
    }
    if (password != portalPassword) {
      throw const ApiException(
        statusCode: 401,
        message: 'Invalid email or password.',
      );
    }

    var supabaseOk = false;
    try {
      await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      supabaseOk = true;
    } on AuthException {
      supabaseOk = false;
    } catch (_) {
      supabaseOk = false;
    }

    _portal = portal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_portalKey, portal.name);
    await prefs.setBool(_localSessionKey, !supabaseOk);
  }

  /// Legacy single-form login — management only, routes via portal.
  Future<void> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (normalized == employeeEmail) {
      await loginWithPortal(email, password, LoginPortal.employee);
    } else {
      await loginWithPortal(
        normalized == managementEmail ? email : managementEmail,
        password,
        LoginPortal.management,
      );
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
        data: {
          'full_name': fullName,
          if (phone != null) 'phone': phone,
          'role': role,
        },
      );
      return true;
    } on AuthException catch (e) {
      throw ApiException(statusCode: 400, message: e.message);
    }
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    _portal = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_portalKey);
    await prefs.remove(_localSessionKey);
  }

  String routeForPortal(LoginPortal portal) => '/home';

  String? get postLoginRoute =>
      _portal != null ? routeForPortal(_portal!) : null;
}
