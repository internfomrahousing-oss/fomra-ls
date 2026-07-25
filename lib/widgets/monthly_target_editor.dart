import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/monthly_target_submission.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

/// The four-category target picker used by both the employee submission form
/// and the management edit modal: a checkbox per category and, when selected,
/// a whole-number input (0–999). Reports the current selection via [onChanged].
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
  State<MonthlyTargetEditor> createState() => _MonthlyTargetEditorState();
}

class _MonthlyTargetEditorState extends State<MonthlyTargetEditor> {
  final Map<TargetCategory, TextEditingController> _ctrls = {};
  final Set<TargetCategory> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final c in TargetCategory.values) {
      final has = widget.initial.containsKey(c.key);
      if (has) _selected.add(c);
      _ctrls[c] = TextEditingController(
        text: has ? widget.initial[c.key].toString() : '',
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

  /// Current selection → value map, used by the parent on submit.
  Map<String, int> get values {
    final out = <String, int>{};
    for (final c in _selected) {
      out[c.key] = int.tryParse(_ctrls[c]!.text.trim()) ?? 0;
    }
    return out;
  }

  void _emit() => widget.onChanged(values);

  void _toggle(TargetCategory c, bool on) {
    if (widget.readOnly) return;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in TargetCategory.values) ...[
          _row(context, c),
          if (c != TargetCategory.values.last) const SizedBox(height: 8),
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
            child: Checkbox(
              value: selected,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: widget.readOnly ? null : (v) => _toggle(c, v ?? false),
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
