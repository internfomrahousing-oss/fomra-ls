import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee_profile.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'employee_service.dart';
import 'tab_session_store.dart';

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

  static const managementEmail = 'management@fomrahousing.in';
  static const employeeEmail = 'employee@fomrahousing.in';

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

  /// True when the app holds a REAL Supabase Auth session — required for the
  /// locked-down (authenticated-only) database. False means the login fell back
  /// to local mode (anon), which the RLS lockdown would block from writing.
  bool get hasRealSession => _client.auth.currentUser != null;

  Future<void> restoreSession() async {
    final portalName = await tabGetString(_portalKey);
    _loginEmail = await tabGetString(_loginEmailKey);
    _loginDisplayName = await tabGetString(_loginNameKey);
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

    final local = (await tabGetString(_localSessionKey)) == 'true';
    // Keep the session while the Supabase session is missing only if it's a
    // local login or we're still inside the post-login grace window. This stops
    // a reload from bouncing the user back to the login screen.
    if (!local &&
        !(await _withinLoginGrace()) &&
        _client.auth.currentUser == null) {
      _portal = null;
      _loginEmail = null;
      _loginDisplayName = null;
      await tabRemove(_portalKey);
      await tabRemove(_loginEmailKey);
      await tabRemove(_loginNameKey);
      await tabRemove(_loginAtKey);
    }
  }

  /// Whether the last login was recent enough to keep the session alive.
  Future<bool> _withinLoginGrace() async {
    final raw = await tabGetString(_loginAtKey);
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
    if ((await tabGetString(_localSessionKey)) == 'true' && _portal != null) {
      return true;
    }
    return (await _withinLoginGrace()) && _portal != null;
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
    // Prefer a REAL Supabase Auth session — that's what makes locked-down
    // (authenticated-only) RLS work. If Supabase accepts the credentials we're
    // done; the password that logs you in is guaranteed to be the auth password.
    var supabaseOk = false;
    try {
      await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      supabaseOk = _client.auth.currentUser != null;
    } on AuthException {
      supabaseOk = false;
    } catch (_) {
      supabaseOk = false;
    }

    // Real Supabase Auth is the ONLY accepted credential now — there is no
    // default ('fomra@2024') or local-password fallback. Each account's
    // password is the one the user set (via their invite / a change).
    if (!supabaseOk) {
      throw const ApiException(
        statusCode: 401,
        message: 'Invalid email or password.',
      );
    }

    _portal = portal;
    _loginEmail = normalizedEmail;
    _loginDisplayName = await _resolveDisplayName(normalizedEmail, portal);
    await tabSetString(_portalKey, portal.name);
    await tabSetString(_loginEmailKey, normalizedEmail);
    await tabSetString(_loginNameKey, _loginDisplayName!);
    await tabSetString(_localSessionKey, 'false');
    await tabSetString(_loginAtKey, DateTime.now().toIso8601String());
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
    await tabRemove(_portalKey);
    await tabRemove(_localSessionKey);
    await tabRemove(_loginEmailKey);
    await tabRemove(_loginNameKey);
    await tabRemove(_loginAtKey);
  }

  /// Changes the password for the currently signed-in Supabase account.
  /// The current password is verified by re-authenticating; the new one is then
  /// saved to Supabase Auth (the single source of truth — no local fallback).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    final email = (user?.email ?? _loginEmail)?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'You are not signed in.',
      );
    }
    final newTrimmed = newPassword.trim();
    if (newTrimmed.length < 8) {
      throw const ApiException(
        statusCode: 400,
        message: 'New password must be at least 8 characters.',
      );
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(newTrimmed) ||
        !RegExp(r'\d').hasMatch(newTrimmed)) {
      throw const ApiException(
        statusCode: 400,
        message: 'New password must include at least one letter and one number.',
      );
    }

    // Verify the current password by re-authenticating.
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword.trim(),
      );
    } on AuthException {
      throw const ApiException(
        statusCode: 400,
        message: 'Current password is incorrect.',
      );
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: newTrimmed));
    } on AuthException catch (e) {
      throw ApiException(statusCode: 400, message: e.message);
    }
  }

  String routeForPortal(LoginPortal portal) => '/home';

  String? get postLoginRoute =>
      _portal != null ? routeForPortal(_portal!) : null;
}
