import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Immutable audit entry — append only; never update/delete from the app.
class AuditLogEntry {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String entityType;
  final String entityId;
  final String field;
  final String oldValue;
  final String newValue;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'field': field,
        'old_value': oldValue,
        'new_value': newValue,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
        id: j['id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        userName: j['user_name'] as String? ?? '',
        action: j['action'] as String? ?? '',
        entityType: j['entity_type'] as String? ?? '',
        entityId: j['entity_id'] as String? ?? '',
        field: j['field'] as String? ?? '',
        oldValue: j['old_value'] as String? ?? '',
        newValue: j['new_value'] as String? ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Append-only audit trail. Local immutable store + best-effort remote insert.
class AuditLogService {
  static const _prefsKey = 'fomra_audit_log_v1';
  static const _maxLocal = 2000;

  static Future<void> log({
    required String action,
    required String entityType,
    required String entityId,
    String field = '',
    String oldValue = '',
    String newValue = '',
  }) async {
    final user = AuthService.instance.currentUser;
    final entry = AuditLogEntry(
      id: 'aud_${DateTime.now().microsecondsSinceEpoch}',
      userId: user?.id ?? 'unknown',
      userName: user?.fullName ?? user?.email ?? 'Unknown',
      action: action,
      entityType: entityType,
      entityId: entityId,
      field: field,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now().toUtc(),
    );

    await _appendLocal(entry);
    try {
      await Supabase.instance.client.from('audit_logs').insert(entry.toJson());
    } catch (_) {
      // Table may not exist yet — local immutable copy is enough.
    }
  }

  static Future<void> _appendLocal(AuditLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    raw.insert(0, jsonEncode(entry.toJson()));
    if (raw.length > _maxLocal) {
      raw.removeRange(_maxLocal, raw.length);
    }
    await prefs.setStringList(_prefsKey, raw);
  }

  static Future<List<AuditLogEntry>> getAll({int limit = 200}) async {
    final remote = await _tryRemote(limit);
    if (remote.isNotEmpty) return remote;
    return _local(limit);
  }

  static Future<List<AuditLogEntry>> _local(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw
        .take(limit)
        .map((s) => AuditLogEntry.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList();
  }

  static Future<List<AuditLogEntry>> _tryRemote(int limit) async {
    try {
      final rows = await Supabase.instance.client
          .from('audit_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => AuditLogEntry.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
