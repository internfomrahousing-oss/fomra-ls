import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/land_lead.dart';
import '../services/land_lead_legal_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_feedback.dart';
import '../utils/employee_lead_next_action.dart';
import '../utils/image_compressor.dart';

String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d.toLocal());

Color _priorityColor(EmployeeActionPriority p) => switch (p) {
      EmployeeActionPriority.low => AppColors.success,
      EmployeeActionPriority.medium => AppColors.info,
      EmployeeActionPriority.high => AppColors.warning,
      EmployeeActionPriority.urgent => AppColors.error,
    };

/// Next-action + pending-task banners for employee lead detail.
class EmployeeLeadGuidanceBanners extends StatelessWidget {
  final EmployeeLeadWorkflowInsight insight;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onNextActionTap;

  const EmployeeLeadGuidanceBanners({
    super.key,
    required this.insight,
    this.onOpenTasks,
    this.onNextActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NextActionBanner(
          action: insight.nextAction,
          onTap: onNextActionTap,
        ),
        const SizedBox(height: 8),
        _PendingTaskBanner(
          summary: insight.tasks,
          onTap: onOpenTasks,
        ),
      ],
    );
  }
}

class _NextActionBanner extends StatelessWidget {
  final EmployeeNextAction action;
  final VoidCallback? onTap;

  const _NextActionBanner({required this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = action.isOverdue;
    final accent = overdue ? AppColors.error : _priorityColor(action.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'NEXT ACTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  if (overdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'OVERDUE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        action.priorityLabel.toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Meta(
                    icon: Icons.event_outlined,
                    text: 'Due ${_fmtDate(action.dueDate)}',
                  ),
                  _Meta(
                    icon: Icons.hourglass_bottom_rounded,
                    text: action.pendingDays <= 0
                        ? 'Pending since today'
                        : 'Pending ${action.pendingDays}d',
                  ),
                  _Meta(
                    icon: Icons.flag_outlined,
                    text: 'Priority ${action.priorityLabel}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingTaskBanner extends StatelessWidget {
  final EmployeePendingTaskSummary summary;
  final VoidCallback? onTap;

  const _PendingTaskBanner({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: context.fomraSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.fomraBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: _TaskStat(
                  label: 'Due Today',
                  value: '${summary.dueToday}',
                  color: AppColors.warning,
                ),
              ),
              Container(width: 1, height: 28, color: context.fomraBorder),
              Expanded(
                child: _TaskStat(
                  label: 'Overdue',
                  value: '${summary.overdue}',
                  color: AppColors.error,
                ),
              ),
              Container(width: 1, height: 28, color: context.fomraBorder),
              Expanded(
                child: _TaskStat(
                  label: 'Pending Since',
                  value: summary.pendingSinceDays <= 0
                      ? '—'
                      : '${summary.pendingSinceDays}d',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TaskStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.fomraTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.fomraTextSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.fomraTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Expandable floating quick-action menu for employee lead detail.
class EmployeeLeadQuickFab extends StatefulWidget {
  final LandLead lead;
  final Future<void> Function(String scheme) onLaunchContact;
  final ValueChanged<String> onDetailAction;
  final ValueChanged<LandLead>? onLeadUpdated;
  final VoidCallback? onActivityChanged;

  const EmployeeLeadQuickFab({
    super.key,
    required this.lead,
    required this.onLaunchContact,
    required this.onDetailAction,
    this.onLeadUpdated,
    this.onActivityChanged,
  });

  @override
  State<EmployeeLeadQuickFab> createState() => _EmployeeLeadQuickFabState();
}

class _EmployeeLeadQuickFabState extends State<EmployeeLeadQuickFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  bool _busy = false;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _open = false;
    });
    _c.reverse();
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureDocument(LegalDocCaptureKind kind) async {
    // Open the OS file chooser directly. On web the picker must be triggered
    // as close to the user gesture as possible, so we avoid an intermediate
    // Camera/Gallery sheet here (that extra hop stops the dialog opening).
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      AppFeedback.error(context, 'Could not read the selected file');
      return;
    }

    final lowerName = file.name.toLowerCase();
    final isImage = lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png');

    Uint8List uploadBytes = bytes;
    String fileName = file.name;
    if (isImage) {
      uploadBytes = await ImageCompressor.compressTo1Mb(bytes);
      final dot = fileName.lastIndexOf('.');
      fileName = '${dot > 0 ? fileName.substring(0, dot) : fileName}.jpg';
    } else if (bytes.length > ImageCompressor.maxBytes1Mb) {
      AppFeedback.error(
        context,
        '${kind.label} exceeds 1 MB. Use a smaller file or a JPG/PNG image.',
      );
      return;
    }

    final name = kind.filePrefix(fileName);

    try {
      await LandLeadLegalService.uploadDocument(
        leadId: widget.lead.leadId,
        bytes: uploadBytes,
        fileName: name,
      );
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${kind.label} upload failed: $e');
      }
      return;
    }
    if (!mounted) return;
    AppFeedback.success(context, '${kind.label} uploaded');
    widget.onActivityChanged?.call();
  }

  Future<void> _showDocCaptureSheet() async {
    final kind = await showModalBottomSheet<LegalDocCaptureKind>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Capture document',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Images are compressed before upload'),
            ),
            for (final k in LegalDocCaptureKind.values)
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: Text(k.label),
                onTap: () => Navigator.pop(ctx, k),
              ),
          ],
        ),
      ),
    );
    if (kind == null) return;
    await _captureDocument(kind);
  }

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, Color color, VoidCallback onTap})>[
      (
        icon: Icons.call_outlined,
        label: 'Call',
        color: AppColors.success,
        onTap: () => _run(() => widget.onLaunchContact('tel')),
      ),
      (
        icon: Icons.location_on_outlined,
        label: 'Visit',
        color: AppColors.primary,
        onTap: () => _run(() async {
          widget.onDetailAction('Site visit');
        }),
      ),
      (
        icon: Icons.upload_file_outlined,
        label: 'Upload Document',
        color: AppColors.info,
        onTap: () => _run(_showDocCaptureSheet),
      ),
      (
        icon: Icons.chat_rounded,
        label: 'WhatsApp',
        color: const Color(0xFF25D366),
        onTap: () => _run(() => widget.onLaunchContact('https://wa.me')),
      ),
      (
        icon: Icons.map_outlined,
        label: 'Land Bank',
        color: AppColors.purple,
        onTap: () => _run(() async {
          Navigator.pushNamed(context, '/land-bank');
        }),
      ),
      (
        icon: Icons.calendar_month_outlined,
        label: 'Field Calendar',
        color: AppColors.accent,
        onTap: () => _run(() async {
          Navigator.pushNamed(context, '/field-calendar');
        }),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open)
          ...[
            for (var i = 0; i < actions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeTransition(
                  opacity: _c,
                  child: ScaleTransition(
                    scale: _c,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: context.fomraSurface,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              actions[i].label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          heroTag: 'lead_fab_${actions[i].label}',
                          backgroundColor: actions[i].color,
                          onPressed: actions[i].onTap,
                          child: Icon(actions[i].icon, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        FloatingActionButton(
          heroTag: 'lead_fab_main',
          onPressed: _busy ? null : _toggle,
          backgroundColor: AppColors.primary,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(_open ? Icons.close_rounded : Icons.bolt_rounded),
        ),
      ],
    );
  }
}
