import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Org-wide feature toggles (Settings › Feature Controls).
///
/// Persists to Supabase `app_settings` when available, with a SharedPreferences
/// cache so Add Lead / approvals keep working offline or before the SQL is
/// applied. Defaults match today's hard-coded behaviour.
class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();
  static final AppSettingsService instance = AppSettingsService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const _table = 'app_settings';

  static const keyManualGpsEntry = 'manual_gps_entry';
  static const keyCameraOnlySitePhotos = 'camera_only_site_photos';
  static const keyRoleHierarchy = 'role_hierarchy';

  static const _prefsPrefix = 'app_setting_';

  bool _manualGpsEntry = false;
  bool _cameraOnlySitePhotos = true;
  bool _roleHierarchy = true;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// When ON, Add Lead allows typed GPS and map pins (plus Live GPS).
  bool get manualGpsEntry => _manualGpsEntry;

  /// When ON, site photos must be taken with the camera. When OFF, camera or
  /// gallery is allowed.
  bool get cameraOnlySitePhotos => _cameraOnlySitePhotos;

  /// When ON, approvals follow Employee → Reporting Manager → Head →
  /// Management. When OFF, employee approvals go straight to Management.
  bool get roleHierarchyEnabled => _roleHierarchy;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await reload();
  }

  Future<void> reload() async {
    await _loadFromPrefs();
    try {
      final rows = await _db.from(_table).select('key, value');
      for (final raw in rows as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final key = (m['key'] as String? ?? '').trim();
        final value = _asBool(m['value']);
        _apply(key, value);
      }
    } catch (_) {
      // Table may be missing — keep prefs / defaults.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setManualGpsEntry(bool value) =>
      _set(keyManualGpsEntry, value, (v) => _manualGpsEntry = v);

  Future<void> setCameraOnlySitePhotos(bool value) =>
      _set(keyCameraOnlySitePhotos, value, (v) => _cameraOnlySitePhotos = v);

  Future<void> setRoleHierarchyEnabled(bool value) =>
      _set(keyRoleHierarchy, value, (v) => _roleHierarchy = v);

  Future<void> _set(
    String key,
    bool value,
    void Function(bool) assign,
  ) async {
    assign(value);
    notifyListeners();
    await _savePref(key, value);
    try {
      final by = AuthService.instance.currentUser?.email ?? '';
      await _db.from(_table).upsert({
        'key': key,
        'value': value,
        'updated_by': by,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Prefs already updated — UI stays consistent until SQL is applied.
    }
  }

  void _apply(String key, bool value) {
    switch (key) {
      case keyManualGpsEntry:
        _manualGpsEntry = value;
      case keyCameraOnlySitePhotos:
        _cameraOnlySitePhotos = value;
      case keyRoleHierarchy:
        _roleHierarchy = value;
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _manualGpsEntry =
          prefs.getBool('$_prefsPrefix$keyManualGpsEntry') ?? false;
      _cameraOnlySitePhotos =
          prefs.getBool('$_prefsPrefix$keyCameraOnlySitePhotos') ?? true;
      _roleHierarchy = prefs.getBool('$_prefsPrefix$keyRoleHierarchy') ?? true;
    } catch (_) {}
  }

  Future<void> _savePref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsPrefix$key', value);
    } catch (_) {}
  }

  static bool _asBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is String) {
      final t = raw.trim().toLowerCase();
      return t == 'true' || t == '1';
    }
    if (raw is num) return raw != 0;
    return false;
  }
}
