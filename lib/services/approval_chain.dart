import '../models/employee_profile.dart';
import 'auth_service.dart';
import 'team_hierarchy.dart';

/// Where an approval request currently sits in the org chain.
enum ApprovalLevel {
  reportingManager,
  head,
  management;

  String get dbValue => name;

  String get label => switch (this) {
        ApprovalLevel.reportingManager => 'Reporting Manager',
        ApprovalLevel.head => 'Head',
        ApprovalLevel.management => 'Management',
      };

  static ApprovalLevel parse(String? raw) {
    final v = (raw ?? '').trim();
    for (final l in ApprovalLevel.values) {
      if (l.name == v) return l;
    }
    // Legacy rows (and anyone without a reporting line) are management-level,
    // which preserves the original single-step behaviour.
    return ApprovalLevel.management;
  }
}

/// One approver in the chain. [approverEmail] is empty for Management, which is
/// a shared account rather than a roster member.
class ApprovalStep {
  final ApprovalLevel level;
  final String approverEmail;
  final String approverName;

  const ApprovalStep({
    required this.level,
    required this.approverEmail,
    required this.approverName,
  });

  static const managementStep = ApprovalStep(
    level: ApprovalLevel.management,
    approverEmail: '',
    approverName: 'Management',
  );
}

/// Resolves the Executive → Reporting Manager → Head → Management approval
/// chain from the roster's reporting lines ([EmployeeProfile.reportsTo]).
///
/// IMPORTANT: when a submitter has no reporting line the chain is just
/// `[Management]` — identical to the original single-step flow — so approvals
/// keep working exactly as before until management assigns reporting lines.
abstract final class ApprovalChain {
  /// Ordered approvers for a request submitted by [submitterEmail].
  static List<ApprovalStep> chainFor(String? submitterEmail) {
    final steps = <ApprovalStep>[];
    final me = TeamHierarchy.byEmail(submitterEmail);

    EmployeeProfile? rm;
    EmployeeProfile? head;

    if (me != null && me.reportsTo.trim().isNotEmpty) {
      final manager = TeamHierarchy.byEmail(me.reportsTo);
      if (manager != null) {
        if (manager.isReportingManager) {
          rm = manager;
          if (manager.reportsTo.trim().isNotEmpty) {
            final h = TeamHierarchy.byEmail(manager.reportsTo);
            if (h != null && h.isHead) head = h;
          }
        } else if (manager.isHead) {
          // Executive reporting straight to a Head.
          head = manager;
        }
      }
    }

    if (rm != null) {
      steps.add(ApprovalStep(
        level: ApprovalLevel.reportingManager,
        approverEmail: rm.email,
        approverName: rm.fullName,
      ));
    }
    if (head != null) {
      steps.add(ApprovalStep(
        level: ApprovalLevel.head,
        approverEmail: head.email,
        approverName: head.fullName,
      ));
    }
    steps.add(ApprovalStep.managementStep);
    return steps;
  }

  /// Where a newly submitted request starts.
  static ApprovalStep firstStepFor(String? submitterEmail) =>
      chainFor(submitterEmail).first;

  /// The next approver after [current], or null when [current] was the final
  /// (Management) step.
  static ApprovalStep? nextStepAfter(String? submitterEmail, ApprovalLevel current) {
    if (current == ApprovalLevel.management) return null;
    final chain = chainFor(submitterEmail);
    final idx = chain.indexWhere((s) => s.level == current);
    if (idx == -1 || idx + 1 >= chain.length) return null;
    return chain[idx + 1];
  }

  /// Whether the signed-in user may approve/reject a request sitting at
  /// [level] with [pendingWith].
  static bool canActOn({
    required ApprovalLevel level,
    required String pendingWith,
  }) {
    if (level == ApprovalLevel.management) {
      return AuthService.instance.isManagement;
    }
    if (AuthService.instance.isManagement) return false;
    final me = (AuthService.instance.currentUser?.email ?? '').trim().toLowerCase();
    if (me.isEmpty) return false;
    return me == pendingWith.trim().toLowerCase();
  }

  /// The notification audience for an approver step: Management uses the shared
  /// 'management' audience; RM/Head are addressed personally by email (the
  /// notifications table's `audience` column is free-form text).
  static String audienceFor(ApprovalStep step) =>
      step.level == ApprovalLevel.management
          ? 'management'
          : step.approverEmail.trim().toLowerCase();
}
