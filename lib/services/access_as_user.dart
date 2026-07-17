import '../models/employee_profile.dart';
import 'audit_log_service.dart';
import 'auth_service.dart';

/// Starts/stops "Access as User" and records each session in the audit log.
///
/// Ordering matters so the audit rows are attributed to management, not the
/// accessed user: the START is logged before switching, and the STOP is logged
/// after switching back.
abstract final class AccessAsUser {
  /// Whether an access session is currently active.
  static bool get isActive => AuthService.instance.isImpersonating;

  /// Begin accessing the app as [user]. No-op if already in a session (nested
  /// access is not allowed).
  static Future<void> start(EmployeeProfile user) async {
    if (AuthService.instance.isImpersonating) return;
    // Logged while still management, so the actor is the management user.
    await AuditLogService.log(
      action: 'Access as user started',
      entityType: 'user_access',
      entityId: user.email,
      newValue: user.fullName,
      module: 'Access as User',
    );
    AuthService.instance.startImpersonation(user);
  }

  /// End the session and restore management. Logs the end (with the start time,
  /// so a row pair captures management user + accessed user + start + end).
  static Future<void> stop() async {
    final user = AuthService.instance.impersonatedUser;
    final start = AuthService.instance.impersonationStart;
    if (user == null) return;
    // Revert first so the audit row is attributed back to management.
    AuthService.instance.stopImpersonation();
    await AuditLogService.log(
      action: 'Access as user ended',
      entityType: 'user_access',
      entityId: user.email,
      newValue: user.fullName,
      oldValue: start != null ? 'started ${start.toIso8601String()}' : '',
      module: 'Access as User',
    );
  }
}
