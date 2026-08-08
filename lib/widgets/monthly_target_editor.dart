import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/monthly_target_submission.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

/// The five-category target picker used by both the employee submission form
/// and the management edit modal. Site Visits / Self Meetings / Management
/// Meetings are mandatory — always shown, always required, no way to
/// deselect them. New Brokers / Broker Meetings are optional — a checkbox
/// per category and, when selected, a whole-number input (0–999). Reports
/// the current selection via [onChanged].
class MonthlyTargetEditor extends StatefulWidget {
  final Map<String, int> initial;
  final bool readOnly;
  final ValueChanged<Map<String, int>> onChanged;

  const MonthlyTargetEditor({
    super.key,
    this.initial = const {},
    this.readOnly = false,
    required this.onChanged,
  });

  @override
  State<MonthlyTargetEditor> createState() => MonthlyTargetEditorState();
}

/// Public so callers can hold a GlobalKey<MonthlyTargetEditorState> and
/// check [missingMandatory] at submit time — the values map alone can't
/// distinguish "left blank" from "explicitly entered 0" for a mandatory
/// category, so validation has to read the controllers directly.
class MonthlyTargetEditorState extends State<MonthlyTargetEditor> {
  final Map<TargetCategory, TextEditingController> _ctrls = {};
  final Set<TargetCategory> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final c in TargetCategory.values) {
      // Mandatory categories are always "selected" — there's no checkbox to
      // toggle them off. Optional ones start selected only if the existing
      // submission already had a value for them.
      final has = c.mandatory || widget.initial.containsKey(c.key);
      if (has) _selected.add(c);
      _ctrls[c] = TextEditingController(
        text: widget.initial.containsKey(c.key)
            ? widget.initial[c.key].toString()
            : '',
      );
    }
  }

  @override
  void dispose() {
    for (final ctrl in _ctrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Current selection → value map, used by the parent on submit. Mandatory
  /// categories are always included (blank reads as 0, which the parent's
  /// submit validation catches and rejects — a mandatory target left blank
  /// should not silently become "0 leads expected").
  Map<String, int> get values {
    final out = <String, int>{};
    for (final c in _selected) {
      out[c.key] = int.tryParse(_ctrls[c]!.text.trim()) ?? 0;
    }
    return out;
  }

  /// Mandatory categories that are still blank — used by the submission
  /// page to block submit with a clear, specific error instead of a generic
  /// "fill something in" message.
  List<TargetCategory> get missingMandatory => [
        for (final c in TargetCategory.values)
          if (c.mandatory && _ctrls[c]!.text.trim().isEmpty) c,
      ];

  void _emit() => widget.onChanged(values);

  void _toggle(TargetCategory c, bool on) {
    if (widget.readOnly || c.mandatory) return;
    setState(() {
      if (on) {
        _selected.add(c);
      } else {
        _selected.remove(c);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final mandatory =
        TargetCategory.values.where((c) => c.mandatory).toList();
    final optional =
        TargetCategory.values.where((c) => !c.mandatory).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in mandatory) ...[
          _row(context, c),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Optional',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: context.fomraTextSecondary,
            ),
          ),
        ),
        for (final c in optional) ...[
          _row(context, c),
          if (c != optional.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, TargetCategory c) {
    final selected = _selected.contains(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.05)
            : context.fomraSurfaceVar.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.35)
              : context.fomraBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: c.mandatory
                // Mandatory categories show a lock, not a checkbox — there's
                // nothing to toggle, it's always required.
                ? Icon(Icons.lock_outline_rounded,
                    size: 15, color: context.fomraTextSecondary)
                : Checkbox(
                    value: selected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged:
                        widget.readOnly ? null : (v) => _toggle(c, v ?? false),
                  ),
          ),
          const SizedBox(width: 6),
          Icon(c.icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.fomraTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: TextField(
              controller: _ctrls[c],
              enabled: selected && !widget.readOnly,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3), // 0–999
              ],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: context.fomraSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.fomraBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.fomraBorder),
                ),
              ),
              onChanged: (_) => _emit(),
            ),
          ),
        ],
      ),
    );
  }
}
