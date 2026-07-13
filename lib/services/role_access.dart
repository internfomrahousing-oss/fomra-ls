import 'auth_service.dart';

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
    if (AuthService.instance.isEmployee) return AppAccessRole.executive;
    final meta =
        (AuthService.instance.currentUser?.role ?? '').trim().toLowerCase();
    if (meta.contains('admin')) return AppAccessRole.admin;
    // Management portal defaults to Manager (elevate via role metadata).
    return AppAccessRole.manager;
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
