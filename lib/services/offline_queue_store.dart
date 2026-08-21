import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'offline_blob_store.dart';

enum OfflineOpType {
  createLead,
  updateLead,
  uploadPhoto,
  uploadVoiceNote,
  createTask,
  logMeeting,
}

class OfflineOp {
  final String id;
  final OfflineOpType type;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  /// Local blob ids (photos / audio) referenced by [payload].
  final List<String> blobIds;
  int attempts;
  String? lastError;

  OfflineOp({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.payload,
    this.blobIds = const [],
    this.attempts = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'payload': payload,
        'blob_ids': blobIds,
        'attempts': attempts,
        'last_error': lastError,
      };

  factory OfflineOp.fromJson(Map<String, dynamic> j) => OfflineOp(
        id: j['id'] as String,
        type: OfflineOpType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => OfflineOpType.updateLead,
        ),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
        payload: Map<String, dynamic>.from(j['payload'] as Map? ?? {}),
        blobIds: (j['blob_ids'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        attempts: j['attempts'] as int? ?? 0,
        lastError: j['last_error'] as String?,
      );
}

/// Local outbox for field ops while offline. Blobs stored separately.
class OfflineQueueStore {
  static const _prefsKey = 'fomra_offline_queue_v1';

  static Future<List<OfflineOp>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw
        .map((s) => OfflineOp.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _save(List<OfflineOp> ops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      ops.map((o) => jsonEncode(o.toJson())).toList(),
    );
  }

  static Future<void> enqueue(OfflineOp op) async {
    final ops = await load();
    ops.add(op);
    await _save(ops);
  }

  static Future<void> remove(String id) async {
    final ops = await load();
    final removed = ops.where((o) => o.id == id).toList();
    ops.removeWhere((o) => o.id == id);
    await _save(ops);
    for (final op in removed) {
      for (final blobId in op.blobIds) {
        await OfflineBlobStore.delete(blobId);
      }
    }
  }

  static Future<void> update(OfflineOp op) async {
    final ops = await load();
    final i = ops.indexWhere((o) => o.id == op.id);
    if (i >= 0) {
      ops[i] = op;
      await _save(ops);
    }
  }

  static Future<int> get pendingCount async => (await load()).length;

  static Future<String> putBlob(Uint8List bytes, {String ext = 'bin'}) =>
      OfflineBlobStore.put(bytes, ext: ext);

  static Future<Uint8List?> getBlob(String id) => OfflineBlobStore.get(id);
}
