import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_profile.dart';
import 'api_client.dart';
import 'app_store.dart';

class EmployeeService {
  static const _cacheKey = 'employee_profiles_v1';

  static SupabaseClient get _db => Supabase.instance.client;

  /// A currently-valid access token for the admin endpoint, refreshing an
  /// expired session first. The app keeps management "signed in" for a grace
  /// window even after the Supabase access token expires, so admin actions must
  /// refresh rather than assume the live token is still there.
  static Future<String?> _adminToken() async {
    var session = _db.auth.currentSession;
    if (session == null || session.isExpired) {
      try {
        final res = await _db.auth.refreshSession();
        session = res.session ?? _db.auth.currentSession;
      } catch (_) {
        // No/expired refresh token — the caller must sign in again.
      }
    }
    return session?.accessToken;
  }

  // ── Auth-user provisioning (real Supabase Auth for each employee) ────────────
  // These call the management-only admin endpoint (api/employee-auth), which
  // uses the server-side service_role key. They require a signed-in management
  // session; without one they no-op (create) or throw (reset) so the app keeps
  // working before real auth is fully rolled out.

  /// Create a real Supabase Auth user for [email] (default password) so the
  /// employee can get an authenticated session. Best-effort and non-fatal.
  static Future<void> provisionAuthUser(String email, {String? password}) async {
    final token = await _adminToken();
    if (token == null) return; // no management session → skip silently
    try {
      final res = await http.post(
        Uri.parse('${ApiClient.baseUrl}/api/employee-auth'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': 'provision',
          'email': email.trim().toLowerCase(),
          if (password != null) 'password': password,
        }),
      );
      if (res.statusCode >= 400) {
        // ignore: avoid_print
        print('provisionAuthUser(${email.trim()}) → ${res.statusCode} ${res.body}');
      }
    } catch (_) {/* endpoint not deployed / offline — profile still created */}
  }

  /// Email [email] a link to set their OWN password (real Supabase Auth login).
  /// Management only. Returns `'invite'` when a fresh invite email was sent, or
  /// `'recovery'` when the address already had a login so a set-password
  /// (recovery) email went instead. Throws with a management-actionable message
  /// (e.g. SMTP not configured) when the email couldn't be sent.
  ///
  /// [designation]/[fullName] ride along as the invited user's metadata. Sending
  /// is identical for every role.
  static Future<String> inviteEmployee(
    String email, {
    String designation = '',
    String fullName = '',
  }) async {
    final token = await _adminToken();
    if (token == null) {
      throw Exception(
          'Sign in as management (with your real password) to invite employees.');
    }
    final res = await http.post(
      Uri.parse('${ApiClient.baseUrl}/api/employee-auth'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': 'invite',
        'email': email.trim().toLowerCase(),
        if (designation.trim().isNotEmpty) 'designation': designation.trim(),
        if (fullName.trim().isNotEmpty) 'fullName': fullName.trim(),
      }),
    );
    if (res.statusCode >= 400) {
      String msg = 'Invite failed (${res.statusCode}).';
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['error'] != null) msg = j['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['recovered'] == true) return 'recovery';
    } catch (_) {}
    return 'invite';
  }

  /// Reset an employee's login password (management only).
  static Future<void> resetAuthPassword(String email, String password) async {
    final token = await _adminToken();
    if (token == null) {
      throw Exception(
          'Your session expired. Sign out and sign in again as management, then retry.');
    }
    final res = await http.post(
      Uri.parse('${ApiClient.baseUrl}/api/employee-auth'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': 'reset',
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );
    if (res.statusCode >= 400) {
      String msg = 'Reset failed (${res.statusCode}).';
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['error'] != null) msg = j['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// Provision auth users for every current employee (one-time backfill).
  /// Returns the number attempted. Management only.
  static Future<int> provisionAllEmployees() async {
    final all = await getAll();
    for (final e in all) {
      await provisionAuthUser(e.email);
    }
    return all.length;
  }

  static Future<List<EmployeeProfile>> getAll() async {
    try {
      final rows = await _db
          .from('employee_profiles')
          .select()
          .order('joined_on', ascending: false);
      final list = (rows as List)
          .map((r) => _fromRow(r as Map<String, dynamic>))
          .toList();
      await _saveCache(list);
      return list;
    } catch (_) {
      return _loadCache();
    }
  }

  static Future<bool> emailExists(String email) async {
    final profile = await findByEmail(email);
    return profile != null && profile.status == EmployeeStatus.active;
  }

  static Future<EmployeeProfile?> findByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    try {
      final row = await _db
          .from('employee_profiles')
          .select()
          .eq('email', normalized)
          .maybeSingle();
      if (row != null) return _fromRow(Map<String, dynamic>.from(row));
    } catch (_) {}
    final cached = await _loadCache();
    for (final e in cached) {
      if (e.email.trim().toLowerCase() == normalized) return e;
    }
    return null;
  }

  static Future<EmployeeProfile> create({
    required String fullName,
    required String email,
    String phone = '',
    String designation = '',
    String department = '',
    String notes = '',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (await emailExists(normalizedEmail)) {
      throw Exception('An employee with this email already exists.');
    }

    try {
      final row = await _db
          .from('employee_profiles')
          .insert({
            'id': normalizedEmail,
            'full_name': fullName.trim(),
            'email': normalizedEmail,
            'phone': phone.trim(),
            'designation': designation.trim(),
            'department': department.trim(),
            'notes': notes.trim(),
            'status': EmployeeStatus.active.name,
            'joined_on': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      final profile = _fromRow(row);
      final all = await getAll();
      if (!all.any((e) => e.id == profile.id)) {
        all.insert(0, profile);
        await _saveCache(all);
      }
      // The login is set up by the caller via inviteEmployee (email invite), so
      // its outcome can be surfaced.
      return profile;
    } catch (e) {
      final profile = EmployeeProfile(
        id: normalizedEmail,
        fullName: fullName.trim(),
        email: normalizedEmail,
        phone: phone.trim(),
        designation: designation.trim(),
        department: department.trim(),
        notes: notes.trim(),
        joinedOn: DateTime.now(),
      );
      final cached = await _loadCache();
      cached.insert(0, profile);
      await _saveCache(cached);
      return profile;
    }
  }

  /// Permanently deletes an employee: their Supabase Auth login, their profile
  /// row, and their place in the team tree. Management only.
  ///
  /// The auth user goes FIRST and a failure aborts the whole thing — deleting
  /// the profile while the login survives would leave someone who can still
  /// sign in but has no roster entry, which is worse than not deleting at all.
  ///
  /// Everything that lists people (dropdowns, assignments, teams, reports,
  /// dashboards, user lists) reads the roster, so removing the profile row plus
  /// the [AppStore] entry retires them everywhere at once.
  static Future<void> deleteEmployee(String id) async {
    final normalized = id.trim().toLowerCase();

    await _deleteAuthUser(normalized);
    // Their reports would otherwise keep pointing at a manager who no longer
    // exists, which silently drops them out of their Head's team. Unassigning
    // surfaces them in Team Management's "unassigned" list for reassignment.
    await _unassignDirectReportsOf(normalized);

    try {
      await _db.from('employee_profiles').delete().eq('id', normalized);
    } catch (_) {
      throw Exception(
        'Login removed, but the profile could not be deleted. Try again.',
      );
    }
    final cached = await _loadCache();
    cached.removeWhere((e) => e.id.toLowerCase() == normalized);
    await _saveCache(cached);
  }

  /// Deletes the Supabase Auth user so [email] can never sign in again.
  /// Succeeds when there was no auth user to begin with.
  static Future<void> _deleteAuthUser(String email) async {
    final token = await _adminToken();
    if (token == null) {
      throw Exception(
        'Your session expired. Sign out and sign in again as management, then retry.',
      );
    }
    final res = await http.post(
      Uri.parse('${ApiClient.baseUrl}/api/employee-auth'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'action': 'delete', 'email': email}),
    );
    if (res.statusCode >= 400) {
      String msg = 'Could not delete the login (${res.statusCode}).';
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['error'] != null) msg = j['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> _unassignDirectReportsOf(String managerEmail) async {
    try {
      await _db
          .from('employee_profiles')
          .update({'reports_to': ''}).eq('reports_to', managerEmail);
    } catch (_) {
      // Column may not exist yet / offline — fall through to the cache below.
    }
    final cached = await _loadCache();
    var touched = false;
    for (var i = 0; i < cached.length; i++) {
      if (cached[i].reportsTo.trim().toLowerCase() == managerEmail) {
        cached[i] = cached[i].copyWith(reportsTo: '');
        touched = true;
      }
    }
    if (touched) await _saveCache(cached);
  }

  /// Updates [employeeEmail]'s designation (Executive / Reporting Manager /
  /// Head). Clears [reportsTo] when the new role cannot keep the old manager
  /// link (e.g. promoting to Head).
  static Future<void> updateDesignation(
    String employeeEmail,
    String designation,
  ) async {
    final emp = employeeEmail.trim().toLowerCase();
    final next = designation.trim();
    if (emp.isEmpty || next.isEmpty) {
      throw Exception('Employee and designation are required.');
    }
    if (!EmployeeDesignations.all.contains(next) ||
        next == EmployeeDesignations.management) {
      throw Exception('Pick Executive, Reporting Manager, or Head.');
    }

    List rows;
    try {
      rows = await _db
          .from('employee_profiles')
          .update({'designation': next})
          .eq('email', emp)
          .select() as List;
    } catch (e) {
      throw Exception('Could not update the role: $e');
    }
    if (rows.isEmpty) {
      throw Exception(
        'That employee could not be found — refresh and try again.',
      );
    }

    final cached = await _loadCache();
    final idx = cached.indexWhere((e) => e.email.trim().toLowerCase() == emp);
    if (idx != -1) {
      cached[idx] = cached[idx].copyWith(designation: next);
      await _saveCache(cached);
    }
    final roster = List<EmployeeProfile>.from(AppStore.instance.employees);
    final ri = roster.indexWhere((e) => e.email.trim().toLowerCase() == emp);
    if (ri != -1) {
      roster[ri] = roster[ri].copyWith(designation: next);
      AppStore.instance.setEmployees(roster);
    }
  }

  /// Assigns [employeeEmail] to report to [managerEmail] (empty to unassign).
  ///
  /// Persists to the DB and throws on failure — a silent cache-only "success"
  /// would vanish on the next reload (which reads the DB), so the caller must
  /// know. The usual cause is the `reports_to` column not being migrated yet.
  static Future<void> assignReportsTo(
    String employeeEmail,
    String managerEmail,
  ) async {
    final emp = employeeEmail.trim().toLowerCase();
    final mgr = managerEmail.trim().toLowerCase();
    List rows;
    try {
      // Match on the email column (stable) and read back the updated rows —
      // a filter that matches nothing returns success with an empty list, which
      // would otherwise persist nothing and make the assignment "vanish" on the
      // next reload.
      rows = await _db
          .from('employee_profiles')
          .update({'reports_to': mgr})
          .eq('email', emp)
          .select() as List;
    } catch (e) {
      throw Exception(
        'Could not save the team assignment. If this persists, run '
        'supabase/employee_reports_to.sql in Supabase. ($e)',
      );
    }
    if (rows.isEmpty) {
      throw Exception(
        'That employee could not be found to update — refresh the page and try again.',
      );
    }
    final cached = await _loadCache();
    final idx = cached.indexWhere((e) => e.email.trim().toLowerCase() == emp);
    if (idx != -1) {
      cached[idx] = cached[idx].copyWith(reportsTo: mgr);
      await _saveCache(cached);
    }
    // Reflect it in the in-memory roster the team screens read, so the change
    // shows immediately without depending on a re-fetch that might lag.
    final roster = List<EmployeeProfile>.from(AppStore.instance.employees);
    final ri = roster.indexWhere((e) => e.email.trim().toLowerCase() == emp);
    if (ri != -1) {
      roster[ri] = roster[ri].copyWith(reportsTo: mgr);
      AppStore.instance.setEmployees(roster);
    }
  }

  static EmployeeProfile _fromRow(Map<String, dynamic> r) {
    return EmployeeProfile(
      id: r['id'] as String,
      fullName: r['full_name'] as String,
      email: r['email'] as String,
      phone: r['phone'] as String? ?? '',
      designation: r['designation'] as String? ?? '',
      department: r['department'] as String? ?? '',
      notes: r['notes'] as String? ?? '',
      reportsTo: r['reports_to'] as String? ?? '',
      status: EmployeeStatus.values.firstWhere(
        (s) => s.name == (r['status'] as String? ?? 'active'),
        orElse: () => EmployeeStatus.active,
      ),
      joinedOn: DateTime.parse(r['joined_on'] as String),
    );
  }

  static Map<String, dynamic> _toJson(EmployeeProfile e) => {
        'id': e.id,
        'full_name': e.fullName,
        'email': e.email,
        'phone': e.phone,
        'designation': e.designation,
        'department': e.department,
        'notes': e.notes,
        'reports_to': e.reportsTo,
        'status': e.status.name,
        'joined_on': e.joinedOn.toUtc().toIso8601String(),
      };

  static Future<void> _saveCache(List<EmployeeProfile> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(list.map(_toJson).toList()),
    );
  }

  static Future<List<EmployeeProfile>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _fromRow((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
