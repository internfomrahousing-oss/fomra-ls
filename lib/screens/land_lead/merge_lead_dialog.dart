import 'package:flutter/material.dart';

import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/ui/app_components.dart';

/// Merges another lead's survey numbers into this one. The other lead is
/// never deleted — it's kept, gets a note, and stays visible in history.
/// Writes through [LandLeadService.mergeLeads].
class MergeLeadDialog extends StatefulWidget {
  final LandLead target;

  const MergeLeadDialog({super.key, required this.target});

  @override
  State<MergeLeadDialog> createState() => _MergeLeadDialogState();
}

class _MergeLeadDialogState extends State<MergeLeadDialog> {
  final _idCtrl = TextEditingController();
  LandLead? _found;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  void _lookup() {
    final query = _idCtrl.text.trim();
    setState(() {
      _error = null;
      _found = null;
      if (query.isEmpty) return;
      for (final l in AppStore.instance.leads) {
        if (l.leadId.toLowerCase() == query.toLowerCase()) {
          _found = l;
          return;
        }
      }
      _error = 'No lead found with ID "$query".';
    });
  }

  Future<void> _save() async {
    final source = _found;
    if (source == null) {
      setState(() => _error = 'Look up a valid lead ID first.');
      return;
    }
    if (source.leadId == widget.target.leadId) {
      setState(() => _error = 'Cannot merge a lead into itself.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await LandLeadService.mergeLeads(
        target: widget.target,
        source: source,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not merge: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: fomraDialogInset(context),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints:
            fomraDialogConstraints(context, maxWidth: 460, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Merge Another Lead In',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.target.leadId} will absorb the other lead\'s survey '
                'numbers. The other lead is kept (not deleted) and gets a note '
                'pointing here — closing it out is a separate step.',
                style: TextStyle(fontSize: 12.5, color: context.fomraTextSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Other lead\'s ID',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _lookup(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _lookup, child: const Text('Find')),
                ],
              ),
              if (_found != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_found!.ownerName.isEmpty ? '(no name)' : _found!.ownerName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        'Survey ${_found!.surveyNumber} · ${_found!.village} · ${_found!.status.label}',
                        style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving || _found == null ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Merge In'),
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
