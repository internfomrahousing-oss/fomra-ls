import 'auth_service.dart';
import 'team_hierarchy.dart';
import '../models/employee_profile.dart';

/// Application roles for RBAC. Mapped from portal + optional user metadata.
enum AppAccessRole { admin, manager, executive }

extension AppAccessRoleX on AppAccessRole {
  String get label => switch (this) {
        AppAccessRole.admin => 'Admin',
        AppAccessRole.manager => 'Manager',
        AppAccessRole.executive => 'Executive',
      };
}

/// Restrict Create / Edit / Delete / Approve / Export by role.
abstract final class RoleAccess {
  static AppAccessRole get currentRole {
    // The shared management/admin login is unaffected by the 2026-08
    // consolidation below — it keeps resolving exactly as before.
    if (!AuthService.instance.isEmployee) {
      final meta =
          (AuthService.instance.currentUser?.role ?? '').trim().toLowerCase();
      if (meta.contains('admin')) return AppAccessRole.admin;
      return AppAccessRole.manager;
    }
    // Individual employee logins previously always resolved to Executive
    // here, regardless of designation — even though TeamHierarchy already
    // gives a Reporting Manager or Head team visibility and approval
    // routing. That meant an RM/Head could see and approve their team's
    // requests but had no way to get delete/export/audit-trail rights
    // without being handed the single shared management login. Elevate
    // them to Manager-tier here to match the access they already
    // effectively have; hard delete stays Admin-only either way (see
    // canDelete below), so this does not hand out delete rights.
    final designation = TeamHierarchy.currentDesignation;
    if (designation == EmployeeDesignations.reportingManager ||
        designation == EmployeeDesignations.head) {
      return AppAccessRole.manager;
    }
    return AppAccessRole.executive;
  }

  static bool get canCreate => true;

  static bool get canEdit => true;

  /// Hard deletes restricted to Admin.
  static bool get canDelete => currentRole == AppAccessRole.admin;

  /// Approvals: Admin + Manager only.
  static bool get canApprove =>
      currentRole == AppAccessRole.admin ||
      currentRole == AppAccessRole.manager;

  /// Export reports: Admin + Manager.
  static bool get canExport =>
      currentRole == AppAccessRole.admin ||
      currentRole == AppAccessRole.manager;

  static bool get canViewAudit =>
      currentRole == AppAccessRole.admin ||
      currentRole == AppAccessRole.manager;

  static String deniedMessage(String action) =>
      'Your role (${currentRole.label}) cannot $action.';
}
