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
/// Persistence & display: at startup the service reconciles against the bucket
/// (listing the stored objects) and records each photo's `updatedAt` as a
/// cache-busting version. Every avatar then renders a versioned URL, so an
/// uploaded picture reappears after refresh / re-login on any device and can
/// never be masked by a browser that cached the bare URL as a 404 before the
/// first upload.
///
/// Degrades gracefully: if the bucket is missing an upload surfaces an error,
/// and avatars simply fall back to the user's initials when no photo exists.
class ProfilePhotoService extends ChangeNotifier {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  static const _bucket = 'profile-photos';
  static const _prefsKey = 'profile_photo_versions_v2';

  static SupabaseClient get _db => Supabase.instance.client;

  /// sanitized file basename (e.g. `vijay_fomra_com`) -> cache-busting version.
  final Map<String, int> _versions = {};
  bool _loaded = false;

  String _sanitize(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  /// Loads persisted versions and reconciles with the bucket so every stored
  /// photo is versioned. Call once at startup.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _restorePersisted();
    if (_versions.isNotEmpty) notifyListeners();
    await reconcileWithBucket();
  }

  Future<void> _restorePersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final v = value is int ? value : int.tryParse('$value');
          if (v != null) _versions[key.toString()] = v;
        });
      }
    } catch (_) {
      // Ignore — versions just start empty.
    }
  }

  /// Lists the storage bucket and versions every existing photo by its
  /// `updatedAt`, so photos show consistently across devices/sessions.
  Future<void> reconcileWithBucket() async {
    try {
      final objects = await _db.storage.from(_bucket).list(
            searchOptions: const SearchOptions(
              limit: 1000,
            ),
          );
      var changed = false;
      for (final o in objects) {
        final name = o.name;
        if (!name.toLowerCase().endsWith('.jpg')) continue;
        final basename = name.substring(0, name.length - 4);
        final updated = o.updatedAt ?? o.createdAt;
        final ts = updated != null
            ? (DateTime.tryParse(updated)?.millisecondsSinceEpoch ??
                name.hashCode)
            : name.hashCode;
        if (_versions[basename] != ts) {
          _versions[basename] = ts;
          changed = true;
        }
      }
      if (changed) {
        await _persist();
        notifyListeners();
      }
    } catch (_) {
      // Bucket may be missing / unlistable — fall back to persisted versions.
    }
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
      final name = _sanitize(e);
      final base = _db.storage.from(_bucket).getPublicUrl('$name.jpg');
      final v = _versions[name];
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
    final name = _sanitize(email);
    await _db.storage.from(_bucket).uploadBinary(
          '$name.jpg',
          compressed,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    _versions[name] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _persist();
  }
}
