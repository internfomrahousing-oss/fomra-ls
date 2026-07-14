import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/image_compressor.dart';
import 'auth_service.dart';

/// Per-account profile photos stored in the Supabase `profile-photos` storage
/// bucket at a deterministic path derived from the account email, so each
/// employee keeps their own picture. Images are compressed before upload.
///
/// Degrades gracefully: if the bucket is missing an upload surfaces an error,
/// and avatars simply fall back to the user's initials when no photo exists.
class ProfilePhotoService extends ChangeNotifier {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  static const _bucket = 'profile-photos';

  static SupabaseClient get _db => Supabase.instance.client;

  /// email (lowercased) -> cache-busting version so a freshly uploaded photo
  /// replaces the cached one immediately after upload.
  final Map<String, int> _versions = {};

  String _sanitize(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

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
  }
}
