import 'package:flutter/material.dart';
import '../../widgets/ui/app_components.dart';
import 'package:flutter/services.dart';

import '../../models/land_lead_meeting.dart';
import '../../services/land_lead_meeting_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/log_dialog_tabs.dart';
import '../../widgets/separate_date_time_fields.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/ui/dialog_error_banner.dart';

class MeetingLogDialog extends StatefulWidget {
  final String leadId;
  final String ownerName;
  final VoidCallback? onMeetingSaved;
  final bool readOnly;

  const MeetingLogDialog({
    super.key,
    required this.leadId,
    this.ownerName = '',
    this.onMeetingSaved,
    this.readOnly = false,
  });

  @override
  State<MeetingLogDialog> createState() => _MeetingLogDialogState();
}

class _MeetingLogDialogState extends State<MeetingLogDialog> {
  int _tabIndex = 0;
  late DateTime _metAt = DateTime.now();
  final _durationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  String? _formError;
  bool _loading = true;
  List<LandLeadMeeting> _meetings = [];

  @override
  void initState() {
    super.initState();
    if (widget.readOnly) _tabIndex = 1;
    _loadMeetings();
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings() async {
    try {
      final meetings = await LandLeadMeetingService.getForLead(widget.leadId);
      if (mounted) setState(() => _meetings = meetings);
    } catch (_) {
      // Table may not exist yet.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDate() async {
    final updated = await pickLogDate(context, _metAt);
    if (updated == null || !mounted) return;
    setState(() => _metAt = updated);
  }

  Future<void> _editTime() async {
    final updated = await pickLogTime(context, _metAt);
    if (updated == null || !mounted) return;
    setState(() => _metAt = updated);
  }

  InputDecoration _fieldDecoration(BuildContext context, String label,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: context.fomraSurfaceVar.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.fomraBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.fomraBorder),
      ),
    );
  }

  Future<void> _save() async {
    final duration = _durationCtrl.text.trim();
    if (duration.isEmpty) {
      setState(() => _formError = 'Enter meeting duration');
      return;
    }
    if (_saving) return;

    setState(() {
      _formError = null;
      _saving = true;
    });
    try {
      await LandLeadMeetingService.create(
        leadId: widget.leadId,
        metAt: _metAt,
        duration: duration,
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      widget.onMeetingSaved?.call();
      AppFeedback.success(context, 'Meeting logged');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _formError = 'Could not save meeting: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final withLabel = widget.ownerName.trim().isNotEmpty
        ? 'with ${widget.ownerName.trim()}'
        : 'with landowner';

    return Dialog(
      insetPadding: fomraDialogInset(context),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: fomraDialogConstraints(context, maxWidth: 440, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
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
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.groups_outlined,
                      color: AppColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        Text(
                          'Lead #${widget.leadId}',
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
              const SizedBox(height: 4),
              if (!widget.readOnly)
                Text(
                  'Log your meeting $withLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fomraTextSecondary,
                  ),
                )
              else
                Text(
                  'Meeting history for this lead',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fomraTextSecondary,
                  ),
                ),
              const SizedBox(height: 14),
              if (!widget.readOnly)
                LogDialogTabBar(
                  selectedIndex: _tabIndex,
                  onChanged: (index) => setState(() => _tabIndex = index),
                  historyCount: _meetings.length,
                ),
              if (!widget.readOnly) const SizedBox(height: 14),
              Flexible(
                child: widget.readOnly || _tabIndex == 1
                    ? _buildHistory(context)
                    : SingleChildScrollView(child: _buildNewForm(context)),
              ),
              if (!widget.readOnly && _tabIndex == 0) ...[
                const SizedBox(height: 14),
                DialogErrorBanner(message: _formError),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
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
                          : const Text('Save Meeting'),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeparateDateTimeFields(
          value: _metAt,
          onEditDate: _editDate,
          onEditTime: _editTime,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _durationCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: _fieldDecoration(
            context,
            'Meeting duration (minutes)',
            hint: 'e.g. 30',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: _fieldDecoration(
            context,
            'Meeting notes (optional)',
            hint: 'What was discussed?',
          ).copyWith(alignLabelWithHint: true),
        ),
      ],
    );
  }

  Widget _buildHistory(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_meetings.isEmpty) {
      return const LogDialogHistoryEmpty(message: 'No previous meetings yet.');
    }
    return ListView.separated(
      itemCount: _meetings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) =>
          _PreviousMeetingTile(meeting: _meetings[index]),
    );
  }
}

class _PreviousMeetingTile extends StatelessWidget {
  final LandLeadMeeting meeting;

  const _PreviousMeetingTile({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.fomraBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatCallDateTime(meeting.metAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ),
              Text(
                '${meeting.duration} min',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          if (meeting.loggedByName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              meeting.loggedByName,
              style: TextStyle(
                fontSize: 11,
                color: context.fomraTextSecondary,
              ),
            ),
          ],
          if (meeting.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meeting.notes,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: context.fomraTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
