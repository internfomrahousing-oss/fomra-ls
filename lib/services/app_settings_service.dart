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
  bool _dbReachable = false;

  /// Bumped on every local write so an in-flight [reload] cannot clobber a
  /// toggle the user just flipped.
  int _writeGeneration = 0;

  bool get isLoaded => _loaded;

  /// True after a successful read/write against `app_settings`.
  bool get dbReachable => _dbReachable;

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

  /// Always re-reads prefs + Supabase. Safe to call when opening Add Lead /
  /// Feature Controls so every screen sees the latest toggles.
  Future<void> reload() async {
    final gen = _writeGeneration;
    await _loadFromPrefs();
    if (gen != _writeGeneration) return;

    try {
      final rows = await _db.from(_table).select('key, value');
      if (gen != _writeGeneration) return;
      _dbReachable = true;
      // DB is source of truth when reachable — reset then apply rows.
      _manualGpsEntry = false;
      _cameraOnlySitePhotos = true;
      _roleHierarchy = true;
      for (final raw in rows as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final key = (m['key'] as String? ?? '').trim();
        if (key.isEmpty) continue;
        _apply(key, _asBool(m['value']));
      }
      await _saveAllPrefs();
    } catch (_) {
      _dbReachable = false;
      // Table missing / offline — keep prefs / defaults already loaded.
    }
    if (gen != _writeGeneration) return;
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
    _writeGeneration++;
    assign(value);
    _loaded = true;
    notifyListeners();
    await _savePref(key, value);

    final by = AuthService.instance.currentUser?.email ?? '';
    try {
      await _db.from(_table).upsert(
        {
          'key': key,
          // JSONB column — send a real JSON boolean, not a string.
          'value': value,
          'updated_by': by,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'key',
      );
      _dbReachable = true;
    } catch (e) {
      _dbReachable = false;
      // Local + prefs already updated so this device stays consistent.
      throw Exception(
        'Saved on this device only. Run supabase/app_settings.sql in Supabase '
        'so the toggle syncs for everyone.\n\n$e',
      );
    }
  }

  void _apply(String key, bool value) {
    if (key == keyManualGpsEntry) {
      _manualGpsEntry = value;
    } else if (key == keyCameraOnlySitePhotos) {
      _cameraOnlySitePhotos = value;
    } else if (key == keyRoleHierarchy) {
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

  Future<void> _saveAllPrefs() async {
    await _savePref(keyManualGpsEntry, _manualGpsEntry);
    await _savePref(keyCameraOnlySitePhotos, _cameraOnlySitePhotos);
    await _savePref(keyRoleHierarchy, _roleHierarchy);
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
      return t == 'true' || t == '1' || t == 'yes' || t == 'on';
    }
    if (raw is num) return raw != 0;
    // Some PostgREST payloads wrap scalars.
    if (raw is Map) {
      if (raw.containsKey('value')) return _asBool(raw['value']);
      if (raw.containsKey('bool')) return _asBool(raw['bool']);
    }
    return false;
  }
}
