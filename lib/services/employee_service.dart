import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_profile.dart';
import 'api_client.dart';

class EmployeeService {
  static const _cacheKey = 'employee_profiles_v1';

  static SupabaseClient get _db => Supabase.instance.client;

  // ── Auth-user provisioning (real Supabase Auth for each employee) ────────────
  // These call the management-only admin endpoint (api/employee-auth), which
  // uses the server-side service_role key. They require a signed-in management
  // session; without one they no-op (create) or throw (reset) so the app keeps
  // working before real auth is fully rolled out.

  /// Create a real Supabase Auth user for [email] (default password) so the
  /// employee can get an authenticated session. Best-effort and non-fatal.
  static Future<void> provisionAuthUser(String email, {String? password}) async {
    final token = _db.auth.currentSession?.accessToken;
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

  /// Reset an employee's login password (management only).
  static Future<void> resetAuthPassword(String email, String password) async {
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Sign in as management to reset employee passwords.');
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
      // Best-effort: give the new employee a real auth login (default password).
      await provisionAuthUser(profile.email);
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

  static Future<void> removeAccess(String id) async {
    final normalized = id.trim().toLowerCase();
    try {
      await _db.from('employee_profiles').delete().eq('id', normalized);
    } catch (_) {
      throw Exception('Could not remove employee access. Try again.');
    }
    final cached = await _loadCache();
    cached.removeWhere((e) => e.id.toLowerCase() == normalized);
    await _saveCache(cached);
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
