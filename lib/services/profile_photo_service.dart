import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/image_compressor.dart';
import 'auth_service.dart';

/// Per-account profile photos stored in the Supabase `profile-photos` storage
/// bucket at a deterministic path derived from the account email, so each
/// employee keeps their own picture. Images are compressed before upload.
///
/// Persistence: the image lives server-side at a stable path, and an upload
/// "version" (timestamp) is persisted locally so the cache-busted URL survives
/// a refresh / re-login — without this, a browser that cached a 404 before the
/// first upload would keep showing the default avatar after reload.
///
/// Degrades gracefully: if the bucket is missing an upload surfaces an error,
/// and avatars simply fall back to the user's initials when no photo exists.
class ProfilePhotoService extends ChangeNotifier {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  static const _bucket = 'profile-photos';
  static const _prefsKey = 'profile_photo_versions_v1';

  static SupabaseClient get _db => Supabase.instance.client;

  /// email (lowercased) -> upload version (ms). Stable across refresh once
  /// persisted, and bumped on every new upload for immediate cache invalidation.
  final Map<String, int> _versions = {};
  bool _loaded = false;

  String _sanitize(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  /// Loads persisted photo versions so uploaded pictures reappear after a
  /// refresh / re-login. Call once at startup.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final v = value is int ? value : int.tryParse('$value');
            if (v != null) _versions[key.toString()] = v;
          });
        }
      }
    } catch (_) {
      // Ignore — versions just start empty.
    }
    if (_versions.isNotEmpty) notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_versions));
    } catch (_) {
      // Non-fatal — persistence is best-effort.
    }
  }

  /// Public URL of the photo for [email], or null when unavailable. The URL is
  /// deterministic; [Image.network] falls back to initials if the file is
  /// missing (404), so callers can render it unconditionally.
  String? urlFor(String? email) {
    final e = (email ?? '').trim().toLowerCase();
    if (e.isEmpty) return null;
    try {
      final base =
          _db.storage.from(_bucket).getPublicUrl('${_sanitize(e)}.jpg');
      final v = _versions[e];
      return v == null ? base : '$base?v=$v';
    } catch (_) {
      return null;
    }
  }

  String? get currentUserUrl =>
      urlFor(AuthService.instance.currentUser?.email);

  /// Compresses [bytes] and uploads them as the current account's photo.
  Future<void> uploadForCurrentUser(Uint8List bytes) async {
    final email =
        (AuthService.instance.currentUser?.email ?? '').trim().toLowerCase();
    if (email.isEmpty) {
      throw Exception('You are not signed in.');
    }
    final compressed = await ImageCompressor.compressTo250Kb(bytes);
    final path = '${_sanitize(email)}.jpg';
    await _db.storage.from(_bucket).uploadBinary(
          path,
          compressed,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    _versions[email] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _persist();
  }
}
