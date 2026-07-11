import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/land_lead_meeting.dart';
import '../../services/land_lead_meeting_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/separate_date_time_fields.dart';

class MeetingLogDialog extends StatefulWidget {
  final String leadId;
  final String ownerName;
  final VoidCallback? onMeetingSaved;

  const MeetingLogDialog({
    super.key,
    required this.leadId,
    this.ownerName = '',
    this.onMeetingSaved,
  });

  @override
  State<MeetingLogDialog> createState() => _MeetingLogDialogState();
}

class _MeetingLogDialogState extends State<MeetingLogDialog> {
  late DateTime _metAt = DateTime.now();
  final _durationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  bool _loading = true;
  List<LandLeadMeeting> _meetings = [];

  @override
  void initState() {
    super.initState();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter meeting duration')),
      );
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final meeting = await LandLeadMeetingService.create(
        leadId: widget.leadId,
        metAt: _metAt,
        duration: duration,
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _meetings = [meeting, ..._meetings];
        _durationCtrl.clear();
        _notesCtrl.clear();
        _metAt = DateTime.now();
      });
      widget.onMeetingSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting logged')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save meeting: $e')),
        );
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
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
              Text(
                'Log your meeting $withLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
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
                        maxLength: 2000,
                        decoration: _fieldDecoration(
                          context,
                          'Meeting notes (optional)',
                          hint: 'What was discussed?',
                        ).copyWith(alignLabelWithHint: true),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (_meetings.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Previous meetings',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final meeting in _meetings.take(5))
                          _PreviousMeetingTile(meeting: meeting),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
            ],
          ),
        ),
      ),
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
