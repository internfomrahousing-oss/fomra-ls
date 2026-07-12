import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/land_lead.dart';
import '../services/gps_verification_service.dart';
import '../services/land_lead_legal_service.dart';
import '../services/land_lead_service.dart';
import '../services/offline_sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_feedback.dart';
import '../utils/employee_lead_next_action.dart';
import '../utils/image_compressor.dart';
import 'voice_note_recorder_dialog.dart';

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
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('Camera — ${kind.label}'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Gallery — ${kind.label}'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (file == null || !mounted) return;

    final raw = await file.readAsBytes();
    final compressed = await ImageCompressor.compressTo1Mb(Uint8List.fromList(raw));
    final name = kind.filePrefix(
      file.name.toLowerCase().endsWith('.jpg') ||
              file.name.toLowerCase().endsWith('.jpeg')
          ? file.name
          : '${kind.label.toLowerCase()}.jpg',
    );

    await LandLeadLegalService.uploadDocument(
      leadId: widget.lead.leadId,
      bytes: compressed,
      fileName: name,
    );
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

  Future<void> _uploadSitePhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null || !mounted) return;

    final raw = await file.readAsBytes();
    final compressed =
        await ImageCompressor.compressTo250Kb(Uint8List.fromList(raw));
    if (widget.lead.sitePhotoUrls.length >= 4) {
      if (!mounted) return;
      AppFeedback.warning(context, 'Maximum 4 site photos allowed');
      return;
    }

    final sync = OfflineSyncService.instance;
    if (!sync.isOnline) {
      await sync.enqueuePhoto(
        leadId: widget.lead.leadId,
        bytes: compressed,
      );
      if (!mounted) return;
      AppFeedback.warning(
          context, 'Photo queued offline — will sync when online');
      widget.onActivityChanged?.call();
      return;
    }

    final updated = await LandLeadService.update(
      widget.lead,
      sitePhotoBytes: [compressed],
    );
    widget.onLeadUpdated?.call(updated);
    if (!mounted) return;
    AppFeedback.success(context, 'Site photo uploaded');
    widget.onActivityChanged?.call();
  }

  Future<void> _voiceNote() async {
    final ok = await showVoiceNoteRecorderDialog(
      context,
      leadId: widget.lead.leadId,
    );
    if (ok == true && mounted) {
      widget.onActivityChanged?.call();
      AppFeedback.success(context, 'Voice note saved');
    }
  }

  Future<void> _gpsCheckIn() async {
    try {
      final fix = await GpsVerificationService.captureLive();
      final stamp = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());
      final line =
          '[$stamp] [GPS Check-in] ${fix.displayCoords} · '
          '±${fix.accuracyMeters.toStringAsFixed(0)} m · live';
      final existing = widget.lead.notes.trim();
      final notes = existing.isEmpty ? line : '$existing\n$line';
      final withGps = widget.lead.copyWith(
        notes: notes,
        gpsCoordinates: fix.toStorage(),
      );

      final sync = OfflineSyncService.instance;
      if (!sync.isOnline) {
        await sync.enqueueUpdateLead(lead: withGps);
        widget.onLeadUpdated?.call(withGps);
      } else {
        final saved = await LandLeadService.update(withGps);
        widget.onLeadUpdated?.call(saved);
      }

      final maps = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${fix.latitude},${fix.longitude}',
      );
      await launchUrl(maps, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      AppFeedback.success(context, 'Checked in · ${fix.summaryLabel}');
      widget.onActivityChanged?.call();
    } on GpsVerificationException catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.message);
    }
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
        icon: Icons.mic_none_rounded,
        label: 'Voice Note',
        color: AppColors.secondary,
        onTap: () => _run(_voiceNote),
      ),
      (
        icon: Icons.photo_camera_outlined,
        label: 'Upload Photo',
        color: AppColors.warning,
        onTap: () => _run(_uploadSitePhoto),
      ),
      (
        icon: Icons.upload_file_outlined,
        label: 'Upload Document',
        color: AppColors.info,
        onTap: () => _run(_showDocCaptureSheet),
      ),
      (
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        color: const Color(0xFF25D366),
        onTap: () => _run(() => widget.onLaunchContact('https://wa.me')),
      ),
      (
        icon: Icons.my_location_rounded,
        label: 'GPS Check-in',
        color: AppColors.error,
        onTap: () => _run(_gpsCheckIn),
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
