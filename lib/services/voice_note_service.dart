import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_store.dart';
import 'auth_service.dart';
import 'land_lead_service.dart';
import 'offline_sync_service.dart';

/// Audio voice notes — record/store/playback. No speech-to-text.
class VoiceNoteService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _bucket = 'land-lead-voice-notes';

  /// Upload audio and append a timeline marker on the lead notes.
  /// Does **not** convert speech to text.
  static Future<String> uploadAndAttach({
    required String leadId,
    required Uint8List bytes,
    required int durationMs,
    String fileName = 'voice.m4a',
  }) async {
    final userId = _db.auth.currentUser?.id;
    final loggedBy = AuthService.instance.currentUser?.fullName ?? '';
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path =
        '$leadId/${DateTime.now().millisecondsSinceEpoch}_$safe';

    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(safe),
            upsert: true,
          ),
        );
    final url = _db.storage.from(_bucket).getPublicUrl(path);

    try {
      await _db.from('land_lead_voice_notes').insert({
        'lead_id': leadId,
        'file_url': url,
        'duration_ms': durationMs,
        if (loggedBy.isNotEmpty) 'logged_by_name': loggedBy,
        if (userId != null) 'logged_by': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Table may not exist yet — notes marker is enough for timeline.
    }

    final lead =
        AppStore.instance.leads.where((l) => l.leadId == leadId).firstOrNull;
    if (lead != null) {
      final stamp = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());
      final secs = (durationMs / 1000).round();
      final line =
          '[$stamp] [Voice Note] audio:$url · ${secs}s'
          '${loggedBy.isEmpty ? '' : ' · $loggedBy'}';
      final notes =
          lead.notes.trim().isEmpty ? line : '${lead.notes.trim()}\n$line';
      final updated = await LandLeadService.update(lead.copyWith(notes: notes));
      AppStore.instance.replaceLead(updated);
    }
    return url;
  }

  /// Save locally when offline; sync later.
  static Future<void> saveOfflineOrUpload({
    required String leadId,
    required Uint8List bytes,
    required int durationMs,
  }) async {
    final sync = OfflineSyncService.instance;
    if (!sync.isOnline) {
      await sync.enqueueVoiceNote(
        leadId: leadId,
        bytes: bytes,
        durationMs: durationMs,
      );
      final lead =
          AppStore.instance.leads.where((l) => l.leadId == leadId).firstOrNull;
      if (lead != null) {
        final stamp = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());
        final secs = (durationMs / 1000).round();
        final line =
            '[$stamp] [Voice Note] (queued offline) · ${secs}s — will sync when online';
        final notes =
            lead.notes.trim().isEmpty ? line : '${lead.notes.trim()}\n$line';
        AppStore.instance.replaceLead(lead.copyWith(notes: notes));
      }
      return;
    }
    await uploadAndAttach(
      leadId: leadId,
      bytes: bytes,
      durationMs: durationMs,
    );
  }

  static String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return 'audio/mp4';
  }

  /// Extract playable audio URLs from a notes line.
  static String? audioUrlFromNotesLine(String line) {
    final m = RegExp(r'audio:(https?://\S+)').firstMatch(line);
    return m?.group(1);
  }
}
