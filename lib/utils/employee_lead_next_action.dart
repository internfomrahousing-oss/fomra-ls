import '../models/land_lead.dart';
import '../models/land_lead_meeting.dart';
import '../models/land_lead_site_visit.dart';
import '../models/lead_call_log.dart';
import '../screens/task_management/task_management_screen.dart';

enum EmployeeNextActionKind {
  callOwner,
  scheduleVisit,
  scheduleMeeting,
  collectChitta,
  collectFmb,
  collectPatta,
  uploadDocuments,
  uploadSaleDeed,
  followUpTask,
  none,
}

enum EmployeeActionPriority { low, medium, high, urgent }

class EmployeeNextAction {
  final EmployeeNextActionKind kind;
  final String label;
  final DateTime dueDate;
  final DateTime pendingSince;
  final EmployeeActionPriority priority;
  final bool isOverdue;
  final String? taskId;

  const EmployeeNextAction({
    required this.kind,
    required this.label,
    required this.dueDate,
    required this.pendingSince,
    required this.priority,
    required this.isOverdue,
    this.taskId,
  });

  String get priorityLabel => switch (priority) {
        EmployeeActionPriority.low => 'Low',
        EmployeeActionPriority.medium => 'Medium',
        EmployeeActionPriority.high => 'High',
        EmployeeActionPriority.urgent => 'Urgent',
      };

  int get pendingDays {
    final a = DateTime(
      pendingSince.year,
      pendingSince.month,
      pendingSince.day,
    );
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return today.difference(a).inDays;
  }
}

class EmployeePendingTaskSummary {
  final int dueToday;
  final int overdue;
  final int pendingSinceDays;
  final List<Task> dueTodayTasks;
  final List<Task> overdueTasks;

  const EmployeePendingTaskSummary({
    required this.dueToday,
    required this.overdue,
    required this.pendingSinceDays,
    required this.dueTodayTasks,
    required this.overdueTasks,
  });
}

class EmployeeLeadWorkflowInsight {
  final EmployeeNextAction nextAction;
  final EmployeePendingTaskSummary tasks;

  const EmployeeLeadWorkflowInsight({
    required this.nextAction,
    required this.tasks,
  });
}

class EmployeeLeadWorkflow {
  static EmployeeLeadWorkflowInsight build({
    required LandLead lead,
    required List<LeadCallLog> callLogs,
    required List<LandLeadSiteVisit> siteVisits,
    required List<LandLeadMeeting> meetings,
    required int legalDocCount,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final tasks = tasksForLead(lead.leadId);
    return EmployeeLeadWorkflowInsight(
      nextAction: _nextAction(
        lead: lead,
        callLogs: callLogs,
        siteVisits: siteVisits,
        meetings: meetings,
        legalDocCount: legalDocCount,
        tasks: tasks,
        now: clock,
      ),
      tasks: _taskSummary(tasks, clock),
    );
  }

  static EmployeePendingTaskSummary _taskSummary(
    List<Task> tasks,
    DateTime now,
  ) {
    final open = tasks.where((t) => t.status != TaskStatus.done).toList();
    final today = DateTime(now.year, now.month, now.day);
    final dueToday = <Task>[];
    final overdue = <Task>[];
    var oldestPending = 0;

    for (final t in open) {
      final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      if (t.isOverdue || due.isBefore(today)) {
        overdue.add(t);
      } else if (due == today) {
        dueToday.add(t);
      }
      final pending = today
          .difference(DateTime(
            t.createdAt.year,
            t.createdAt.month,
            t.createdAt.day,
          ))
          .inDays;
      if (pending > oldestPending) oldestPending = pending;
    }

    return EmployeePendingTaskSummary(
      dueToday: dueToday.length,
      overdue: overdue.length,
      pendingSinceDays: oldestPending,
      dueTodayTasks: dueToday,
      overdueTasks: overdue,
    );
  }

  static EmployeeNextAction _nextAction({
    required LandLead lead,
    required List<LeadCallLog> callLogs,
    required List<LandLeadSiteVisit> siteVisits,
    required List<LandLeadMeeting> meetings,
    required int legalDocCount,
    required List<Task> tasks,
    required DateTime now,
  }) {
    // Prefer urgent/overdue linked tasks first.
    final openTasks = tasks.where((t) => t.status != TaskStatus.done).toList()
      ..sort((a, b) {
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        return a.dueDate.compareTo(b.dueDate);
      });
    if (openTasks.isNotEmpty &&
        (openTasks.first.isOverdue ||
            openTasks.first.priority == TaskPriority.urgent ||
            openTasks.first.priority == TaskPriority.high)) {
      final t = openTasks.first;
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.followUpTask,
        label: t.title.trim().isEmpty ? 'Complete task' : t.title.trim(),
        dueDate: t.dueDate,
        pendingSince: t.createdAt,
        priority: _mapPriority(t.priority),
        isOverdue: t.isOverdue,
        taskId: t.id,
      );
    }

    if (lead.status == LeadStatus.signed) {
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.none,
        label: 'Deal closed — no pending action',
        dueDate: now,
        pendingSince: lead.addedOn,
        priority: EmployeeActionPriority.low,
        isOverdue: false,
      );
    }

    if (lead.status == LeadStatus.dropped) {
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.none,
        label: 'Lead dropped',
        dueDate: now,
        pendingSince: lead.addedOn,
        priority: EmployeeActionPriority.low,
        isOverdue: false,
      );
    }

    final ageDays = _ageDays(lead.addedOn, now);
    final hasCall = callLogs.isNotEmpty;
    final hasVisit = siteVisits.isNotEmpty;
    final hasMeeting = meetings.isNotEmpty;

    if (!hasCall) {
      final due = lead.addedOn.add(const Duration(days: 1));
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.callOwner,
        label: 'Call Owner',
        dueDate: due,
        pendingSince: lead.addedOn,
        priority: ageDays >= 2
            ? EmployeeActionPriority.urgent
            : EmployeeActionPriority.high,
        isOverdue: now.isAfter(due),
      );
    }

    if (!hasVisit &&
        (lead.status.isProspect || lead.status == LeadStatus.negotiation)) {
      final due = lead.addedOn.add(const Duration(days: 7));
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.scheduleVisit,
        label: 'Schedule Visit',
        dueDate: due,
        pendingSince: callLogs.first.calledAt,
        priority: ageDays >= 7
            ? EmployeeActionPriority.urgent
            : EmployeeActionPriority.high,
        isOverdue: now.isAfter(due),
      );
    }

    if (!hasMeeting && lead.status == LeadStatus.prospectMeetingPending) {
      final due = lead.addedOn.add(const Duration(days: 5));
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.scheduleMeeting,
        label: 'Schedule Meeting',
        dueDate: due,
        pendingSince: lead.addedOn,
        priority: EmployeeActionPriority.medium,
        isOverdue: now.isAfter(due),
      );
    }

    if (lead.status == LeadStatus.negotiation ||
        lead.status == LeadStatus.legal) {
      // Document collection guidance (filename prefixes from camera capture).
      // Without loaded names, use survey/legal heuristics.
      if (lead.surveyNumber.trim().isEmpty &&
          lead.status == LeadStatus.negotiation) {
        final due = lead.addedOn.add(const Duration(days: 14));
        return EmployeeNextAction(
          kind: EmployeeNextActionKind.collectChitta,
          label: 'Collect Chitta',
          dueDate: due,
          pendingSince: lead.addedOn,
          priority: EmployeeActionPriority.high,
          isOverdue: now.isAfter(due),
        );
      }
      if (lead.status == LeadStatus.negotiation) {
        final due = lead.addedOn.add(const Duration(days: 14));
        return EmployeeNextAction(
          kind: EmployeeNextActionKind.collectFmb,
          label: 'Collect FMB',
          dueDate: due,
          pendingSince: lead.addedOn,
          priority: EmployeeActionPriority.medium,
          isOverdue: now.isAfter(due),
        );
      }
      if (legalDocCount == 0) {
        final due = lead.addedOn.add(const Duration(days: 21));
        return EmployeeNextAction(
          kind: EmployeeNextActionKind.uploadDocuments,
          label: 'Upload Documents',
          dueDate: due,
          pendingSince: lead.addedOn,
          priority: EmployeeActionPriority.high,
          isOverdue: now.isAfter(due),
        );
      }
      if (lead.status == LeadStatus.legal) {
        final due = lead.addedOn.add(const Duration(days: 30));
        return EmployeeNextAction(
          kind: EmployeeNextActionKind.uploadSaleDeed,
          label: 'Upload Sale Deed',
          dueDate: due,
          pendingSince: lead.addedOn,
          priority: EmployeeActionPriority.medium,
          isOverdue: now.isAfter(due),
        );
      }
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.collectPatta,
        label: 'Collect Patta',
        dueDate: lead.addedOn.add(const Duration(days: 21)),
        pendingSince: lead.addedOn,
        priority: EmployeeActionPriority.medium,
        isOverdue: ageDays > 21,
      );
    }

    if (openTasks.isNotEmpty) {
      final t = openTasks.first;
      return EmployeeNextAction(
        kind: EmployeeNextActionKind.followUpTask,
        label: t.title.trim().isEmpty ? 'Complete task' : t.title.trim(),
        dueDate: t.dueDate,
        pendingSince: t.createdAt,
        priority: _mapPriority(t.priority),
        isOverdue: t.isOverdue,
        taskId: t.id,
      );
    }

    return EmployeeNextAction(
      kind: EmployeeNextActionKind.callOwner,
      label: 'Follow up with owner',
      dueDate: now.add(const Duration(days: 2)),
      pendingSince: lead.addedOn,
      priority: EmployeeActionPriority.medium,
      isOverdue: false,
    );
  }

  static EmployeeActionPriority _mapPriority(TaskPriority p) => switch (p) {
        TaskPriority.low => EmployeeActionPriority.low,
        TaskPriority.medium => EmployeeActionPriority.medium,
        TaskPriority.high => EmployeeActionPriority.high,
        TaskPriority.urgent => EmployeeActionPriority.urgent,
      };

  static int _ageDays(DateTime from, DateTime now) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }
}

/// Legal document kinds for camera capture.
enum LegalDocCaptureKind { patta, chitta, fmb, saleDeed }

extension LegalDocCaptureKindX on LegalDocCaptureKind {
  String get label => switch (this) {
        LegalDocCaptureKind.patta => 'Patta',
        LegalDocCaptureKind.chitta => 'Chitta',
        LegalDocCaptureKind.fmb => 'FMB',
        LegalDocCaptureKind.saleDeed => 'Sale Deed',
      };

  String filePrefix(String original) => '${label}_$original';
}
