import '../models/app_notification.dart';
import '../models/land_lead.dart';
import '../models/lead_drop_reason.dart';
import '../services/app_store.dart';
import '../services/auth_service.dart';
import '../services/land_lead_service.dart';
import '../services/notifications_service.dart';

class LeadDropApprovalRequest {
  final AppNotification notification;
  final LeadDropReason reason;
  final String notes;
  final String requestedByName;

  const LeadDropApprovalRequest({
    required this.notification,
    required this.reason,
    required this.notes,
    required this.requestedByName,
  });

  String get id => notification.id;
  String get leadId => notification.leadId ?? '';
  DateTime get createdAt => notification.time;
  bool get isPending => !notification.isRead;
}

class LeadDropApprovalService {
  static const _requestPrefix = 'Drop request · ';

  static bool isDropRequest(AppNotification notification) =>
      notification.type == NotificationType.pendingApproval &&
      notification.title.startsWith(_requestPrefix);

  static LeadDropApprovalRequest? toRequest(AppNotification notification) {
    if (!isDropRequest(notification)) return null;
    final reasonLabel = notification.title.substring(_requestPrefix.length).trim();
    final reason = LeadDropReason(
      id: normalizeLeadDropReasonId(reasonLabel),
      label: reasonLabel,
    );
    return LeadDropApprovalRequest(
      notification: notification,
      reason: reason,
      notes: _extractNotes(notification.message),
      requestedByName: _extractRequestedBy(notification.message),
    );
  }

  static Future<LeadDropApprovalRequest> submit({
    required String leadId,
    required LeadDropReason reason,
    required String notes,
  }) async {
    final by = AuthService.instance.currentUser?.fullName ?? 'Employee';
    final created = await NotificationsService.createAndReturn(
      audience: 'management',
      type: 'pending_approval',
      title: 'Drop request · ${reason.label}',
      message: [
        'Requested by: ${by.trim().isEmpty ? 'Employee' : by.trim()}',
        'Notes: ${notes.trim().isEmpty ? '—' : notes.trim()}',
      ].join('\n'),
      leadId: leadId,
      referenceId: leadId,
    );
    return LeadDropApprovalRequest(
      notification: created,
      reason: reason,
      notes: notes.trim(),
      requestedByName: by.trim().isEmpty ? 'Employee' : by.trim(),
    );
  }

  static Future<List<LeadDropApprovalRequest>> getPending() async {
    final notifications =
        await NotificationsService.getAll(audience: 'management');
    return notifications
        .where(isDropRequest)
        .where((notification) => !notification.isRead)
        .map(toRequest)
        .whereType<LeadDropApprovalRequest>()
        .toList();
  }

  static Future<void> review({
    required LeadDropApprovalRequest request,
    required bool approve,
  }) async {
    if (approve) {
      await LandLeadService.markDropped(
        leadId: request.leadId,
        reasonLabel: request.reason.label,
        notes: request.notes,
      );
      AppStore.instance.updateLeadStatus(request.leadId, LeadStatus.dropped);
    }

    await NotificationsService.markRead(request.id);
    await NotificationsService.create(
      audience: 'employee',
      type: approve ? 'verification' : 'alert',
      title: approve ? 'Drop request approved' : 'Drop request rejected',
      message: approve
          ? 'Lead #${request.leadId} was approved and marked as Dropped'
          : 'Lead #${request.leadId} drop request was rejected',
      leadId: request.leadId,
      referenceId: request.id,
    );
  }

  static String _extractRequestedBy(String message) {
    for (final line in message.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('requested by:')) {
        return trimmed.substring('requested by:'.length).trim();
      }
    }
    return 'Employee';
  }

  static String _extractNotes(String message) {
    for (final line in message.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('notes:')) {
        return trimmed.substring('notes:'.length).trim();
      }
    }
    return '';
  }
}