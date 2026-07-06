import 'package:shared_preferences/shared_preferences.dart';
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

  // Local per-account password cache key (offline / pre-migration fallback).
  static String _accountPwKey(String account) =>
      'account_password_${account.trim().toLowerCase()}';

  static const managementEmail = 'management@fomrahousing.in';
  static const employeeEmail = 'employee@fomrahousing.in';

  /// The default password every account starts with, until it's changed.
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

  /// Locally-cached password for an account (offline / pre-migration fallback).
  Future<String> _localPasswordFor(String account) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountPwKey(account)) ?? portalPassword;
  }

  /// Whether [entered] is the correct password for [account] (a login email).
  ///
  /// The source of truth is the server (per-account, synced across devices):
  /// [verify_account_password] returns true/false when a custom password is set,
  /// or null when the account still uses the default [portalPassword]. If the
  /// RPC is unavailable (offline, or the migration hasn't been applied yet) it
  /// falls back to the previous local behavior so login keeps working.
  /// Trimmed so autofill/keyboard trailing spaces don't block login.
  Future<bool> _passwordMatches(String account, String entered) async {
    final trimmed = entered.trim();
    try {
      final res = await _client.rpc('verify_account_password', params: {
        'p_account': account.trim().toLowerCase(),
        'p_password': trimmed,
      });
      if (res is bool) return res;
      // null → no custom password set → the account still uses the default.
      return trimmed == portalPassword.trim();
    } catch (_) {
      final local = await _localPasswordFor(account);
      return trimmed == local.trim();
    }
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

    // Fallback for accounts not yet provisioned as real auth users: accept the
    // legacy shared/custom password. (Once every account is provisioned and RLS
    // is locked down, this path is no longer exercised.)
    if (!supabaseOk && !await _passwordMatches(normalizedEmail, password)) {
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
    await tabSetString(_localSessionKey, (!supabaseOk).toString());
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

  /// Changes the password for the currently signed-in account (this email).
  /// The new password becomes that account's password on every device — it's
  /// stored server-side (hashed), not per-browser. Verifies the current password
  /// first. Falls back to local storage if the DB function isn't available.
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
    if (newPassword.trim().length < 6) {
      throw const ApiException(
        statusCode: 400,
        message: 'New password must be at least 6 characters.',
      );
    }

    final account = (_loginEmail ?? emailForPortal(portal)).trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();

    try {
      final ok = await _client.rpc('set_account_password', params: {
        'p_account': account,
        'p_current': currentPassword.trim(),
        'p_new': newPassword.trim(),
      });
      if (ok == false) {
        throw const ApiException(
          statusCode: 400,
          message: 'Current password is incorrect.',
        );
      }
      // Server is now the source of truth — drop any stale local override.
      await prefs.remove(_accountPwKey(account));
    } on ApiException {
      rethrow;
    } catch (_) {
      // RPC unavailable (offline or migration not applied) → local fallback,
      // keyed per-account so it still behaves per-employee.
      if (!await _passwordMatches(account, currentPassword)) {
        throw const ApiException(
          statusCode: 400,
          message: 'Current password is incorrect.',
        );
      }
      await prefs.setString(_accountPwKey(account), newPassword.trim());
    }

    // Best-effort: update the Supabase Auth account password if a real session
    // exists (kept for accounts that have a Supabase user).
    try {
      if (_client.auth.currentUser != null) {
        await _client.auth.updateUser(UserAttributes(password: newPassword));
      }
    } catch (_) {}
  }

  String routeForPortal(LoginPortal portal) => '/home';

  String? get postLoginRoute =>
      _portal != null ? routeForPortal(_portal!) : null;
}
