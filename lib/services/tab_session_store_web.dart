import 'dart:html' as html;

// Web implementation. Uses window.sessionStorage, which is scoped to a single
// browser tab: each tab keeps its own login, a reload preserves it, and closing
// the tab ends that tab's session. This is what lets Management and Employee be
// signed in side-by-side in different tabs.

// All three calls are wrapped: sessionStorage access throws in some real
// mobile situations (notably Safari Private Browsing, which sets storage
// quota to 0, and some locked-down mobile browsers). Before this guard, a
// throw here during signInWithPassword's internal session-save step was
// caught by the generic error handling in auth_service.dart and reported
// as "Invalid email or password" — even when Supabase had already accepted
// the correct credentials (confirmed via auth.users.last_sign_in_at
// updating on the exact failed attempt). Persistence is best-effort: if it
// fails, the user is still correctly logged in for this page load, they
// just won't survive a manual reload — a much better failure mode than a
// false "wrong password".
Future<String?> tabGetString(String key) async {
  try {
    return html.window.sessionStorage[key];
  } catch (_) {
    return null;
  }
}

Future<void> tabSetString(String key, String value) async {
  try {
    html.window.sessionStorage[key] = value;
  } catch (_) {
    // Best-effort only — see note above.
  }
}

Future<void> tabRemove(String key) async {
  try {
    html.window.sessionStorage.remove(key);
  } catch (_) {
    // Best-effort only — see note above.
  }
}
