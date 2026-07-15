import 'package:flutter/foundation.dart';

import '../models/land_lead.dart';
import 'auth_service.dart';
import 'team_hierarchy.dart';
import 'view_scope.dart';

/// The one rule for which leads the signed-in user may see.
///
/// Management sees every site. An Executive only ever sees their own. A
/// Reporting Manager / Head sees either the reporting line *under* them or just
/// their own sites, depending on [ViewScope] — which is what the header's
/// Team / Individual toggle drives. Those two views are disjoint: Team is the
/// people under you, Individual is you.
///
/// Every lead list, count, chart, report and map marker resolves through this
/// (via [AppStore.visibleLeads], [leadsVisibleToCurrentUser], or directly), so
/// access control and the team scope stay consistent across the whole app.
abstract final class LeadVisibility {
  static String _norm(String s) => s.trim().toLowerCase();

  static String get _currentName {
    try {
      return _norm(AuthService.instance.currentUser?.fullName ?? '');
    } catch (_) {
      // Supabase may not be initialized yet (e.g. widget tests).
      return '';
    }
  }

  static String? get _currentEmail {
    try {
      return AuthService.instance.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Lowercased creator names the current user may see, or null when they may
  /// see everything (Management, or a user we can't identify — matching the
  /// long-standing fallback of showing all rather than none).
  static Set<String>? allowedCreatorNames() => namesFor(
        isManagement: AuthService.instance.isManagement,
        me: _currentName,
        email: _currentEmail,
      );

  /// The rule itself, with the signed-in identity passed in so it can be
  /// exercised without a Supabase session. The roster and the team scope are
  /// read from [AppStore] / [ViewScope], both of which tests can set.
  ///
  /// [me] is matched against `createdByName`; [email] resolves the roster entry
  /// (emails are unique, display names are not).
  @visibleForTesting
  static Set<String>? namesFor({
    required bool isManagement,
    required String me,
    String? email,
  }) {
    if (isManagement) return null;
    final name = _norm(me);
    if (name.isEmpty) return null;

    // Individual view — and every Executive — is always just your own sites.
    if (!ViewScope.instance.isTeam) return {name};

    final profile = TeamHierarchy.byEmail(email);
    if (profile == null) return {name};
    if (!profile.isReportingManager && !profile.isHead) return {name};

    // Team view is the reporting line *under* this manager and excludes their
    // own sites — Team and Individual are disjoint, so a Reporting Manager's
    // Team view is their assigned Executives and a Head's is every Reporting
    // Manager and Executive beneath them. A manager with nobody assigned
    // therefore sees nothing here, which is the honest answer: their own sites
    // are one toggle away in Individual.
    // teamMemberNames() returns a fresh set that includes the manager, keyed by
    // their roster name — drop that and the signed-in name, which can differ.
    return TeamHierarchy.teamMemberNames(profile)
      ..remove(_norm(profile.fullName))
      ..remove(name);
  }

  static bool allows(LandLead lead) {
    final names = allowedCreatorNames();
    return names == null || names.contains(_norm(lead.createdByName));
  }

  static List<LandLead> scope(List<LandLead> leads) {
    final names = allowedCreatorNames();
    if (names == null) return leads;
    return leads.where((l) => names.contains(_norm(l.createdByName))).toList();
  }
}
