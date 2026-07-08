/// Captures the URL the app was first opened with.
///
/// On web the app uses hash-based routing, so Flutter rewrites the URL `#`
/// fragment on startup — the same place Supabase puts invite / password-recovery
/// tokens. We snapshot [Uri.base] at the very first line of `main()` (before the
/// router runs) so those tokens survive for the set-password flow.
class AuthLink {
  static Uri initialUri = Uri.base;

  /// Records the launch URL. Call this first thing in `main()`.
  static void capture() {
    initialUri = Uri.base;
  }

  /// Whether the launch URL carries Supabase auth tokens from an email link.
  static bool get isAuthCallback {
    final blob = '${initialUri.query}&${initialUri.fragment}';
    return blob.contains('type=invite') ||
        blob.contains('type=recovery') ||
        blob.contains('access_token=') ||
        blob.contains('error_code=') ||
        blob.contains('code=');
  }
}
