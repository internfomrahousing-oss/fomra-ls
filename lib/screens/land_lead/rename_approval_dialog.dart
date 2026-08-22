import 'package:flutter/material.dart';

import '../../models/land_lead_rename_request.dart';
import '../../services/land_lead_rename_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/ui/app_feedback.dart';

/// Approve/reject a lead rename request. Closes a real gap found while
/// fixing a related bug: LandLeadRenameService.approve()/reject() and
/// getPending() existed and were correct, but nothing in the UI ever
/// called them — tapping a "Lead rename request" notification did
/// nothing at all (it fell through every case in openNotificationTarget,
/// since that only handled site-visit and monthly-target approvals).
Future<bool?> showRenameApprovalDialog(
  BuildContext context, {
  required String leadId,
}) async {
  final pending = await LandLeadRenameService.getPending();
  final request = pending.where((r) => r.leadId == leadId).firstOrNull;
  if (request == null) {
    if (context.mounted) {
      AppFeedback.warning(context, 'No pending rename request found for this lead.');
    }
    return null;
  }
  if (!context.mounted) return null;
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => _RenameApprovalDialog(request: request),
  );
}

class _RenameApprovalDialog extends StatefulWidget {
  final LandLeadRenameRequest request;
  const _RenameApprovalDialog({required this.request});

  @override
  State<_RenameApprovalDialog> createState() => _RenameApprovalDialogState();
}

class _RenameApprovalDialogState extends State<_RenameApprovalDialog> {
  final _reasonCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    try {
      if (approve) {
        await LandLeadRenameService.approve(widget.request);
      } else {
        await LandLeadRenameService.reject(widget.request,
            reason: _reasonCtrl.text.trim());
      }
      if (!mounted) return;
      Navigator.pop(context, approve);
      AppFeedback.success(
          context, approve ? 'Rename approved.' : 'Rename rejected.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, 'Could not save decision: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return AlertDialog(
      title: const Text('Lead Rename Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Requested by ${r.requestedByName.isEmpty ? 'an executive' : r.requestedByName}',
              style: TextStyle(fontSize: 12, color: context.fomraTextSecondary)),
          const SizedBox(height: 12),
          _renameRow('From', r.previousName, context),
          const SizedBox(height: 6),
          _renameRow('To', r.requestedName, context, emphasize: true),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason (only needed if rejecting)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _decide(false),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _decide(true),
          child: const Text('Approve'),
        ),
      ],
    );
  }

  Widget _renameRow(String label, String value, BuildContext context,
      {bool emphasize = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: context.fomraTextSecondary)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
              color: emphasize ? AppColors.primary : context.fomraTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
