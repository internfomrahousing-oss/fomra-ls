import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/monthly_target.dart';
import '../../services/monthly_target_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_input.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_feedback.dart';

/// Management sets ONE common monthly target that every employee is measured
/// against. Pushed from Settings, which only shows the tile to management.
class MonthlyTargetsPage extends StatefulWidget {
  const MonthlyTargetsPage({super.key});

  @override
  State<MonthlyTargetsPage> createState() => _MonthlyTargetsPageState();
}

class _MonthlyTargetsPageState extends State<MonthlyTargetsPage> {
  final _targetCtrl = TextEditingController();

  late int _year;
  late int _month;
  List<MonthlyTarget> _targets = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  DateTime get _now => DateTime.now();

  @override
  void initState() {
    super.initState();
    _year = _now.year;
    _month = _now.month;
    _load();
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await MonthlyTargetService.getAll();
    if (!mounted) return;
    setState(() {
      _targets = all;
      _loading = false;
    });
    _syncFieldToSelection();
  }

  /// The target already saved for the selected month, if any.
  MonthlyTarget? get _selected {
    for (final t in _targets) {
      if (t.year == _year && t.month == _month) return t;
    }
    return null;
  }

  MonthlyTarget? get _active {
    for (final t in _targets) {
      if (t.isActiveAt(_now)) return t;
    }
    return null;
  }

  /// Picking a month that already has a target loads it for editing; a month
  /// without one starts empty, ready for a new target.
  void _syncFieldToSelection() {
    final existing = _selected;
    _targetCtrl.text = existing == null ? '' : existing.target.toString();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final value = int.tryParse(_targetCtrl.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter the number of sites/deals for the month.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      // Upserts on the month, so this creates July or edits it — earlier months
      // are never touched.
      await MonthlyTargetService.save(
        year: _year,
        month: _month,
        target: value,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      AppFeedback.success(
        context,
        'Target for ${MonthlyTarget.monthName(_month)} $_year saved.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save the target: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Past / current / future, from the month itself.
  ({String label, Color color}) _status(MonthlyTarget t) {
    if (t.isActiveAt(_now)) return (label: 'Active', color: AppColors.success);
    final isPast = t.year < _now.year || (t.year == _now.year && t.month < _now.month);
    return isPast
        ? (label: 'Completed', color: AppColors.textSecondary)
        : (label: 'Upcoming', color: AppColors.info);
  }

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      appBar: const FomraAppBar(moduleName: 'Monthly Targets'),
      backgroundColor: context.fomraPageBg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionHeader(
            title: 'Monthly Targets',
            subtitle:
                'One common target per month — every employee is measured against it.',
            icon: Icons.flag_outlined,
          ),
          _activeCard(context),
          const SizedBox(height: AppSpacing.md),
          _formCard(context),
          const SizedBox(height: AppSpacing.md),
          _historyCard(context),
        ],
      ),
    );
  }

  Widget _activeCard(BuildContext context) {
    final active = _active;
    return AppCard(
      interactive: false,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.track_changes_outlined,
                color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current active target · ${MonthlyTarget.monthName(_now.month)} ${_now.year}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.fomraTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loading
                      ? '—'
                      : active == null
                          ? 'No target set for this month'
                          : '${active.target} sites/deals',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary,
                  ),
                ),
                if (active != null && active.updatedByName.trim().isNotEmpty)
                  Text(
                    'Set by ${active.updatedByName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.fomraTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    final existing = _selected;
    // A month that already has a target is edited, not duplicated.
    final isEdit = existing != null;

    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEdit ? 'Edit target' : 'Set target',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEdit
                ? 'This month already has a target — saving updates it.'
                : 'Pick a month and set its target. Earlier months are unaffected.',
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 620;
              final fields = <Widget>[
                _monthField(context),
                _yearField(context),
                _countField(context),
              ];
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in fields) ...[
                      f,
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: fields[0]),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: fields[1]),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 3, child: fields[2]),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(isEdit ? 'Update target' : 'Save target'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthField(BuildContext context) => DropdownButtonFormField<int>(
        initialValue: _month,
        isExpanded: true,
        decoration: FomraInput.decoration(
          context: context,
          label: 'Month',
          icon: Icons.calendar_month_outlined,
        ),
        items: [
          for (var m = 1; m <= 12; m++)
            DropdownMenuItem(value: m, child: Text(MonthlyTarget.monthName(m))),
        ],
        onChanged: (v) {
          if (v == null) return;
          _month = v;
          _error = null;
          _syncFieldToSelection();
        },
      );

  Widget _yearField(BuildContext context) {
    // A year either side covers setting next January in December.
    final years = [_now.year - 1, _now.year, _now.year + 1];
    return DropdownButtonFormField<int>(
      initialValue: years.contains(_year) ? _year : _now.year,
      isExpanded: true,
      decoration: FomraInput.decoration(
        context: context,
        label: 'Year',
        icon: Icons.event_outlined,
      ),
      items: [
        for (final y in years)
          DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: (v) {
        if (v == null) return;
        _year = v;
        _error = null;
        _syncFieldToSelection();
      },
    );
  }

  Widget _countField(BuildContext context) => TextField(
        controller: _targetCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: FomraInput.decoration(
          context: context,
          label: 'Monthly target',
          hint: 'Sites / deals',
          icon: Icons.flag_outlined,
          required: true,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      );

  Widget _historyCard(BuildContext context) {
    if (_loading) {
      return const AppCard(
        interactive: false,
        child: Center(child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        )),
      );
    }
    if (_targets.isEmpty) {
      return const AppCard(
        interactive: false,
        child: EmptyState(
          icon: Icons.flag_outlined,
          title: 'No targets yet',
          message: 'Set a target above and it will be listed here.',
        ),
      );
    }

    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Target history',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width < 720 ? 480 : 0,
              ),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                headingRowColor: WidgetStateProperty.all(context.fomraSurfaceVar),
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Target')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final t in _targets)
                    DataRow(
                      cells: [
                        DataCell(Text(t.label)),
                        DataCell(Text('${t.target}')),
                        DataCell(_statusChip(t)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(MonthlyTarget t) {
    final s = _status(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.color,
        ),
      ),
    );
  }
}
