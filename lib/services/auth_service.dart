import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee_profile.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'employee_service.dart';

enum LoginPortal { employee, management }

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _portalKey = 'login_portal';
  static const _localSessionKey = 'local_auth_session';
  static const _loginEmailKey = 'login_email';
  static const _loginNameKey = 'login_display_name';
  static const _loginAtKey = 'login_at';

  /// After a successful login the session is kept alive for at least this long,
  /// even across reloads, regardless of whether the Supabase session rehydrates.
  static const _sessionGrace = Duration(minutes: 5);

  static String _passwordKey(LoginPortal portal) =>
      'portal_password_${portal.name}';

  static const managementEmail = 'management@fomrahousing.in';
  static const employeeEmail = 'employee@fomrahousing.in';
  static const portalPassword = 'fomra@2024';

  static SupabaseClient get _client => Supabase.instance.client;

  LoginPortal? _portal;
  String? _loginEmail;
  String? _loginDisplayName;

  LoginPortal? get loginPortal => _portal;

  bool get isManagement => _portal == LoginPortal.management;
  bool get isEmployee => _portal == LoginPortal.employee;

  static String emailForPortal(LoginPortal portal) => switch (portal) {
        LoginPortal.management => managementEmail,
        LoginPortal.employee => employeeEmail,
      };

  /// The active password for a portal: a custom one set via Settings,
  /// falling back to the shared default [portalPassword].
  Future<String> passwordForPortal(LoginPortal portal) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey(portal)) ?? portalPassword;
  }

  /// A login password is valid if it matches the active portal password.
  /// Trimmed so autofill/keyboard trailing spaces don't block login. (A changed
  /// password still invalidates the old one — the default is not a backdoor.)
  Future<bool> _passwordMatches(LoginPortal portal, String entered) async {
    return entered.trim() == (await passwordForPortal(portal)).trim();
  }

  AppUser? get currentUser {
    final u = _client.auth.currentUser;
    if (u != null) {
      final email = u.email ?? _loginEmail ?? '';
      return AppUser(
        id: u.id,
        email: email,
        fullName: _loginDisplayName ??
            u.userMetadata?['full_name'] as String? ??
            _defaultNameForEmail(email),
        phone: u.userMetadata?['phone'] as String?,
        role: u.userMetadata?['role'] as String? ??
            (_portal == LoginPortal.management ? 'management' : 'employee'),
        createdAt: DateTime.parse(u.createdAt),
      );
    }
    if (_portal != null) {
      final email = _loginEmail ?? emailForPortal(_portal!);
      return AppUser(
        id: 'local-${_portal!.name}',
        email: email,
        fullName: _loginDisplayName ?? _defaultNameForEmail(email),
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
    _loginEmail = prefs.getString(_loginEmailKey);
    _loginDisplayName = prefs.getString(_loginNameKey);
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
    // Keep the session while the Supabase session is missing only if it's a
    // local login or we're still inside the post-login grace window. This stops
    // a reload from bouncing the user back to the login screen.
    if (!local &&
        !_withinLoginGrace(prefs) &&
        _client.auth.currentUser == null) {
      _portal = null;
      _loginEmail = null;
      _loginDisplayName = null;
      await prefs.remove(_portalKey);
      await prefs.remove(_loginEmailKey);
      await prefs.remove(_loginNameKey);
      await prefs.remove(_loginAtKey);
    }
  }

  /// Whether the last login was recent enough to keep the session alive.
  bool _withinLoginGrace(SharedPreferences prefs) {
    final raw = prefs.getString(_loginAtKey);
    if (raw == null) return false;
    final at = DateTime.tryParse(raw);
    if (at == null) return false;
    return DateTime.now().difference(at) < _sessionGrace;
  }

  static String _defaultNameForEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized == managementEmail) return 'Management';
    if (normalized == employeeEmail) return 'Employee';
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'User';
    return local[0].toUpperCase() + local.substring(1);
  }

  Future<String> _resolveDisplayName(String email, LoginPortal portal) async {
    final normalized = email.trim().toLowerCase();
    if (normalized == managementEmail) return 'Management';
    if (normalized == employeeEmail) return 'Employee';
    final profile = await EmployeeService.findByEmail(normalized);
    if (profile != null && profile.fullName.trim().isNotEmpty) {
      return profile.fullName.trim();
    }
    return _defaultNameForEmail(normalized);
  }

  Future<bool> checkSession() async {
    await restoreSession();
    if (_client.auth.currentUser != null) return true;
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(_localSessionKey) ?? false) && _portal != null) {
      return true;
    }
    return _withinLoginGrace(prefs) && _portal != null;
  }

  Future<void> loginWithPortal(
    String email,
    String password,
    LoginPortal portal,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (portal == LoginPortal.management &&
        normalizedEmail != managementEmail) {
      throw const ApiException(
        statusCode: 401,
        message: 'Invalid email or password.',
      );
    }
    if (portal == LoginPortal.employee &&
        normalizedEmail != employeeEmail) {
      final profile = await EmployeeService.findByEmail(normalizedEmail);
      if (profile == null || profile.status != EmployeeStatus.active) {
        throw const ApiException(
          statusCode: 401,
          message: 'Invalid email or password.',
        );
      }
    }
    if (!await _passwordMatches(portal, password)) {
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
    _loginEmail = normalizedEmail;
    _loginDisplayName = await _resolveDisplayName(normalizedEmail, portal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_portalKey, portal.name);
    await prefs.setString(_loginEmailKey, normalizedEmail);
    await prefs.setString(_loginNameKey, _loginDisplayName!);
    await prefs.setBool(_localSessionKey, !supabaseOk);
    await prefs.setString(_loginAtKey, DateTime.now().toIso8601String());
  }

  Future<void> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();

    LoginPortal? portal;
    if (normalized == managementEmail) {
      portal = LoginPortal.management;
    } else if (normalized == employeeEmail ||
        await EmployeeService.emailExists(normalized)) {
      portal = LoginPortal.employee;
    }

    if (portal == null) {
      throw const ApiException(
        statusCode: 401,
        message: 'Invalid email or password.',
      );
    }

    await loginWithPortal(email, password, portal);
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
    _loginEmail = null;
    _loginDisplayName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_portalKey);
    await prefs.remove(_localSessionKey);
    await prefs.remove(_loginEmailKey);
    await prefs.remove(_loginNameKey);
    await prefs.remove(_loginAtKey);
  }

  /// Changes the password for the currently signed-in portal. Verifies the
  /// current password, stores the new one locally, and best-effort syncs it to
  /// the Supabase account when a real session exists.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final portal = _portal;
    if (portal == null) {
      throw const ApiException(
        statusCode: 401,
        message: 'You are not signed in.',
      );
    }
    if (currentPassword != await passwordForPortal(portal)) {
      throw const ApiException(
        statusCode: 400,
        message: 'Current password is incorrect.',
      );
    }
    if (newPassword.trim().length < 6) {
      throw const ApiException(
        statusCode: 400,
        message: 'New password must be at least 6 characters.',
      );
    }

    // Best-effort: update the Supabase account password if a session exists.
    try {
      if (_client.auth.currentUser != null) {
        await _client.auth.updateUser(UserAttributes(password: newPassword));
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey(portal), newPassword);
  }

  String routeForPortal(LoginPortal portal) => '/home';

  String? get postLoginRoute =>
      _portal != null ? routeForPortal(_portal!) : null;
}
