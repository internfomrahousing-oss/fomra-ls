import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'team_hierarchy.dart';

enum TeamViewScope { team, individual }

extension TeamViewScopeX on TeamViewScope {
  String get label => switch (this) {
        TeamViewScope.team => 'Team',
        TeamViewScope.individual => 'Individual',
      };

  String get storageValue => switch (this) {
        TeamViewScope.team => 'team',
        TeamViewScope.individual => 'individual',
      };
}

/// Whether a Reporting Manager / Head is looking at their whole team's data or
/// only their own.
///
/// Read by [LeadVisibility], which every lead list, count, chart and map goes
/// through — so flipping this re-scopes the whole app at once. Persisted, and
/// defaults to Team.
class ViewScope extends ChangeNotifier {
  static final ViewScope instance = ViewScope._();
  ViewScope._();

  static const _key = 'team_view_scope_v1';

  TeamViewScope _scope = TeamViewScope.team;
  TeamViewScope get scope => _scope;

  bool get isTeam => _scope == TeamViewScope.team;

  /// Only Reporting Managers and Heads have a team to switch between. Everyone
  /// else (Executives, Management) has a single view, so the toggle is hidden
  /// and this scope is ignored.
  ///
  /// Returns false until the employee roster loads — [TeamHierarchy] reads it to
  /// find the signed-in user's designation. Callers should rebuild on
  /// [AppStore] so the toggle appears once the roster arrives.
  bool get canToggle {
    if (AuthService.instance.isManagement) return false;
    try {
      final profile = TeamHierarchy.currentProfile;
      if (profile == null) return false;
      return profile.isReportingManager || profile.isHead;
    } catch (_) {
      // Reads the signed-in user, so it throws before Supabase is initialized.
      // This renders in the shared header on every page — never let it take the
      // app bar down; just hide the toggle.
      return false;
    }
  }

  bool _loaded = false;

  /// Restores the persisted selection. Safe to call more than once; a no-op
  /// after the first success.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      _loaded = true;
      if (raw == null) return;
      final restored = TeamViewScope.values
          .where((s) => s.storageValue == raw)
          .firstOrNull;
      if (restored == null || restored == _scope) return;
      _scope = restored;
      notifyListeners();
    } catch (_) {
      // No stored preference available — stay on the Team default.
      _loaded = true;
    }
  }

  Future<void> set(TeamViewScope next) async {
    if (_scope == next) return;
    _scope = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, next.storageValue);
    } catch (_) {
      // Selection still applies for this session even if it can't be stored.
    }
  }

  /// Drops back to the default — call on sign-out so the next user doesn't
  /// inherit the previous one's view.
  void reset() {
    _loaded = false;
    if (_scope == TeamViewScope.team) return;
    _scope = TeamViewScope.team;
    notifyListeners();
  }
}
