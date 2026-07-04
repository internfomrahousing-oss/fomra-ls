import 'package:supabase_flutter/supabase_flutter.dart';

import 'tab_session_store.dart';

/// Supabase [LocalStorage] backed by per-tab storage (sessionStorage on web),
/// so each browser tab persists its own auth session independently.
class SessionScopedLocalStorage extends LocalStorage {
  final String persistSessionKey;
  const SessionScopedLocalStorage({required this.persistSessionKey});

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await tabGetString(persistSessionKey)) != null;

  @override
  Future<String?> accessToken() => tabGetString(persistSessionKey);

  @override
  Future<void> removePersistedSession() => tabRemove(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      tabSetString(persistSessionKey, persistSessionString);
}
