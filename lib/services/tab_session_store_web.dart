import 'dart:html' as html;

// Web implementation. Uses window.sessionStorage, which is scoped to a single
// browser tab: each tab keeps its own login, a reload preserves it, and closing
// the tab ends that tab's session. This is what lets Management and Employee be
// signed in side-by-side in different tabs.

Future<String?> tabGetString(String key) async =>
    html.window.sessionStorage[key];

Future<void> tabSetString(String key, String value) async =>
    html.window.sessionStorage[key] = value;

Future<void> tabRemove(String key) async =>
    html.window.sessionStorage.remove(key);
