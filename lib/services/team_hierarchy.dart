import '../models/employee_profile.dart';
import 'app_store.dart';
import 'auth_service.dart';

/// Read-only helpers over the employee roster ([AppStore.employees]) for the
/// Executive → Reporting Manager → Head → Management hierarchy.
abstract final class TeamHierarchy {
  static List<EmployeeProfile> get _all => AppStore.instance.employees;

  static String _norm(String s) => s.trim().toLowerCase();

  static EmployeeProfile? byEmail(String? email) {
    final e = _norm(email ?? '');
    if (e.isEmpty) return null;
    for (final p in _all) {
      if (_norm(p.email) == e) return p;
    }
    return null;
  }

  /// The signed-in user's employee profile (null for the shared management
  /// account or when the roster isn't loaded).
  static EmployeeProfile? get currentProfile =>
      byEmail(AuthService.instance.currentUser?.email);

  /// Effective designation of the current user (Management for the management
  /// portal; otherwise the roster designation, defaulting to Executive).
  static String get currentDesignation {
    if (AuthService.instance.isManagement) {
      return EmployeeDesignations.management;
    }
    final p = currentProfile;
    if (p == null || p.designation.trim().isEmpty) {
      return EmployeeDesignations.executive;
    }
    return p.designation;
  }

  /// Direct reports of [managerEmail].
  static List<EmployeeProfile> directReports(String managerEmail) {
    final m = _norm(managerEmail);
    if (m.isEmpty) return const [];
    return _all.where((p) => _norm(p.reportsTo) == m).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  /// Executives reporting to [rmEmail].
  static List<EmployeeProfile> executivesUnder(String rmEmail) =>
      directReports(rmEmail).where((p) => p.isExecutive).toList();

  /// Reporting Managers reporting to [headEmail].
  static List<EmployeeProfile> managersUnder(String headEmail) =>
      directReports(headEmail).where((p) => p.isReportingManager).toList();

  /// Whether [p] is genuinely on someone's team — i.e. reports to an existing
  /// ACTIVE manager. A reports_to pointing at a deleted / missing account is
  /// treated as orphaned (available), so such members aren't stranded forever.
  static bool _onRealTeam(EmployeeProfile p) {
    if (p.reportsTo.trim().isEmpty) return false;
    final mgr = byEmail(p.reportsTo);
    return mgr != null && mgr.status == EmployeeStatus.active;
  }

  /// Active Executives a Reporting Manager can add: everyone except those
  /// already on THEIR team. Executives on another manager's team still appear
  /// (labelled with that team) so they can be reassigned; only the manager's
  /// own current members are hidden as redundant.
  static List<EmployeeProfile> assignableExecutivesFor(String rmEmail) {
    final me = _norm(rmEmail);
    return _all
        .where((p) =>
            p.status == EmployeeStatus.active &&
            p.isExecutive &&
            _norm(p.reportsTo) != me)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  /// Active Reporting Managers a Head can add (everyone except their own).
  static List<EmployeeProfile> assignableManagersFor(String headEmail) {
    final me = _norm(headEmail);
    return _all
        .where((p) =>
            p.status == EmployeeStatus.active &&
            p.isReportingManager &&
            _norm(p.reportsTo) != me)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  /// A short label for who a member currently reports to (for the add picker).
  /// Orphaned members (manager missing/inactive) read as Unassigned.
  static String currentTeamLabel(EmployeeProfile p) {
    if (!_onRealTeam(p)) return 'Unassigned';
    return 'On ${byEmail(p.reportsTo)!.fullName}\'s team';
  }

  /// All member NAMES in [manager]'s team (recursively down the chain),
  /// including the manager — used to scope performance/leads by team.
  static Set<String> teamMemberNames(EmployeeProfile manager) {
    final names = <String>{_norm(manager.fullName)};
    void collect(String email) {
      for (final r in directReports(email)) {
        if (names.add(_norm(r.fullName))) collect(r.email);
      }
    }

    collect(manager.email);
    return names;
  }

  /// Emails of the manager and everyone under them, recursively. Email is a
  /// stable identifier (display names drift), so attribution — e.g. monthly
  /// target progress — should key off this rather than [teamMemberNames].
  static Set<String> teamMemberEmails(EmployeeProfile manager) {
    final emails = <String>{_norm(manager.email)};
    void collect(String email) {
      for (final r in directReports(email)) {
        if (emails.add(_norm(r.email))) collect(r.email);
      }
    }

    collect(manager.email);
    return emails;
  }
}
