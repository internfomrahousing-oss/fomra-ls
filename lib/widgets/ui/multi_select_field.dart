import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';

/// A compact, tap-to-open multi-select filter field — the same shape as a
/// standard dropdown, but lets the user tick more than one option (e.g.
/// picking both "BASHA" and "basha" at once, or several pipeline stages).
///
/// Shows "All" when nothing is selected, the single label when exactly one
/// option is picked, and "N selected" otherwise. Tapping opens a searchable
/// checklist bottom sheet — built once here so every filter panel in the
/// app (Project Map, Leads list, Reports, etc.) can share the same pattern
/// instead of each screen reinventing single-select dropdowns.
class MultiSelectField<T> extends StatelessWidget {
  final String label;
  final List<T> options;
  final Set<T> selected;
  final String Function(T) labelOf;
  final ValueChanged<Set<T>> onChanged;
  final IconData? icon;

  const MultiSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.icon,
  });

  String get _summary {
    if (selected.isEmpty) return 'All';
    if (selected.length == 1) return labelOf(selected.first);
    return '${selected.length} selected';
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final result = await showModalBottomSheet<Set<T>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: context.fomraSurface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => _MultiSelectSheet<T>(
            title: label,
            options: options,
            initiallySelected: selected,
            labelOf: labelOf,
          ),
        );
        if (result != null) onChanged(result);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: icon != null
              ? Icon(icon, size: 16, color: context.fomraTextSecondary)
              : null,
          suffixIcon: hasSelection
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  splashRadius: 18,
                  onPressed: () => onChanged({}),
                )
              : const Icon(Icons.arrow_drop_down_rounded),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.fomraBorder),
          ),
        ),
        child: Text(
          _summary,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w400,
            color: hasSelection
                ? AppColors.primary
                : context.fomraTextPrimary,
          ),
        ),
      ),
    );
  }
}

class _MultiSelectSheet<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final Set<T> initiallySelected;
  final String Function(T) labelOf;

  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initiallySelected,
    required this.labelOf,
  });

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late Set<T> _picked = {...widget.initiallySelected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = _query.isEmpty
        ? widget.options
        : widget.options
            .where((o) =>
                widget.labelOf(o).toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.fomraTextPrimary)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _picked = {}),
                    child: const Text('Clear'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _picked = {...widget.options}),
                    child: const Text('Select all'),
                  ),
                ],
              ),
            ),
            if (widget.options.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in visible)
                    CheckboxListTile(
                      value: _picked.contains(o),
                      title: Text(widget.labelOf(o)),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _picked.add(o);
                        } else {
                          _picked.remove(o);
                        }
                      }),
                    ),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matches'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _picked),
                  child: Text(_picked.isEmpty
                      ? 'Show all'
                      : 'Apply (${_picked.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
