import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lead_call_log.dart';
import '../../services/lead_call_log_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';

String formatCallDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

class CallsLogDialog extends StatefulWidget {
  final String leadId;
  final String ownerName;

  const CallsLogDialog({
    super.key,
    required this.leadId,
    this.ownerName = '',
  });

  @override
  State<CallsLogDialog> createState() => _CallsLogDialogState();
}

class _CallsLogDialogState extends State<CallsLogDialog> {
  late DateTime _calledAt = DateTime.now();
  final _durationCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  bool _saving = false;
  bool _loading = true;
  List<LeadCallLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await LeadCallLogService.getForLead(widget.leadId);
      if (mounted) setState(() => _logs = logs);
    } catch (_) {
      // Table may not exist yet — form still works for first save attempt.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _calledAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_calledAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _calledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final duration = _durationCtrl.text.trim();
    final details = _detailsCtrl.text.trim();
    if (duration.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter call duration')),
      );
      return;
    }
    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter call details')),
      );
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final log = await LeadCallLogService.create(
        leadId: widget.leadId,
        calledAt: _calledAt,
        duration: duration,
        details: details,
      );
      if (!mounted) return;
      setState(() {
        _logs = [log, ..._logs];
        _durationCtrl.clear();
        _detailsCtrl.clear();
        _calledAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call logged')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save call: $e')),
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
                      Icons.call_outlined,
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
                          'Calls',
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
                'Log your call $withLabel',
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
                      _DateTimeField(
                        value: formatCallDateTime(_calledAt),
                        onEdit: _editDateTime,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Call duration (minutes)',
                          hintText: 'e.g. 5',
                          filled: true,
                          fillColor:
                              context.fomraSurfaceVar.withValues(alpha: 0.55),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.fomraBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.fomraBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _detailsCtrl,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: 'Call details',
                          hintText: 'What was discussed with the landowner?',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor:
                              context.fomraSurfaceVar.withValues(alpha: 0.55),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.fomraBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.fomraBorder),
                          ),
                        ),
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
                      else if (_logs.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Previous calls',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final log in _logs.take(5))
                          _PreviousCallTile(log: log),
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
                        : const Text('Save Call'),
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

class _DateTimeField extends StatelessWidget {
  final String value;
  final VoidCallback onEdit;

  const _DateTimeField({required this.value, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date & time',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: context.fomraTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviousCallTile extends StatelessWidget {
  final LeadCallLog log;

  const _PreviousCallTile({required this.log});

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
                  formatCallDateTime(log.calledAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ),
              Text(
                '${log.duration} min',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          if (log.loggedByName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              log.loggedByName,
              style: TextStyle(
                fontSize: 11,
                color: context.fomraTextSecondary,
              ),
            ),
          ],
          if (log.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              log.details,
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
