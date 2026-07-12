import 'package:flutter/material.dart';

import '../../models/land_lead_site_visit.dart';
import '../../services/land_lead_site_visit_service.dart';
import '../../services/role_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/separate_date_time_fields.dart';
import '../../widgets/ui/app_feedback.dart';

Future<bool?> showManagementVisitReviewDialog(
  BuildContext context, {
  required String visitId,
  String? leadId,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => ManagementVisitReviewDialog(
      visitId: visitId,
      leadId: leadId,
    ),
  );
}

class ManagementVisitReviewDialog extends StatefulWidget {
  final String visitId;
  final String? leadId;

  const ManagementVisitReviewDialog({
    super.key,
    required this.visitId,
    this.leadId,
  });

  @override
  State<ManagementVisitReviewDialog> createState() =>
      _ManagementVisitReviewDialogState();
}

class _ManagementVisitReviewDialogState
    extends State<ManagementVisitReviewDialog> {
  final _notesCtrl = TextEditingController();
  LandLeadSiteVisit? _visit;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final visit = await LandLeadSiteVisitService.getById(widget.visitId);
      if (!mounted) return;
      setState(() {
        _visit = visit;
        _loading = false;
        if (visit == null) _error = 'Visit request not found.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submit(SiteVisitApprovalStatus status) async {
    if (_saving || _visit == null) return;
    if (!RoleAccess.canApprove) {
      if (!mounted) return;
      AppFeedback.error(context, RoleAccess.deniedMessage('approve visits'));
      return;
    }
    setState(() => _saving = true);
    try {
      await LandLeadSiteVisitService.review(
        visitId: _visit!.id,
        status: status,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      AppFeedback.success(
        context,
        status == SiteVisitApprovalStatus.approved
            ? 'Management site visit approved'
            : 'Management site visit rejected',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not save review: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = _visit;
    final leadLabel = widget.leadId ?? visit?.leadId ?? '—';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.apartment_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review management visit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        Text(
                          'Lead #$leadLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                )
              else if (visit != null) ...[
                if (visit.loggedByName.isNotEmpty)
                  Text(
                    'Requested by ${visit.loggedByName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                const SizedBox(height: 12),
                IgnorePointer(
                  child: SeparateDateTimeFields(
                    value: visit.visitedAt,
                    onEditDate: () async {},
                    onEditTime: () async {},
                  ),
                ),
                if (visit.approvalStatus != SiteVisitApprovalStatus.pending) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.fomraSurfaceVar,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.fomraBorder),
                    ),
                    child: Text(
                      'Already ${visit.approvalStatus.label.toLowerCase()}'
                      '${visit.managementNotes.isNotEmpty ? ': ${visit.managementNotes}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Add approval or rejection notes…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  if (visit != null &&
                      visit.approvalStatus == SiteVisitApprovalStatus.pending) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _submit(SiteVisitApprovalStatus.rejected),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _submit(SiteVisitApprovalStatus.approved),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
