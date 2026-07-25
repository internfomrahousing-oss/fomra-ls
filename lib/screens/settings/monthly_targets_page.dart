import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/employee_profile.dart';
import '../../models/monthly_target.dart';
import '../../services/employee_service.dart';
import '../../services/monthly_target_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_input.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';
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

  /// Sentinel for the "All Employees" option — a common target has no email.
  static const _allEmployees = '';

  late int _month;
  String _employeeEmail = _allEmployees;
  List<MonthlyTarget> _targets = const [];
  List<EmployeeProfile> _employees = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  DateTime get _now => DateTime.now();

  /// The year is always the current one — management no longer picks it.
  int get _year => _now.year;

  @override
  void initState() {
    super.initState();
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
    final results = await Future.wait([
      MonthlyTargetService.getAll(),
      EmployeeService.getAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _targets = results[0] as List<MonthlyTarget>;
      _employees = (results[1] as List<EmployeeProfile>)
          .where((e) => e.status == EmployeeStatus.active)
          .toList()
        ..sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      _loading = false;
    });
    _syncFieldToSelection();
  }

  /// The target saved for the selected month AND employee, if any.
  MonthlyTarget? get _selected {
    for (final t in _targets) {
      if (t.year == _year &&
          t.month == _month &&
          t.employeeEmail == _employeeEmail) {
        return t;
      }
    }
    return null;
  }

  /// The common (all-employees) target for the current month, for the headline.
  MonthlyTarget? get _active {
    for (final t in _targets) {
      if (t.isActiveAt(_now) && t.isCommon) return t;
    }
    return null;
  }

  /// History order: newest month first, and within a month the common target
  /// before the personal ones, then personal targets by name.
  List<MonthlyTarget> get _sortedTargets {
    final list = List<MonthlyTarget>.from(_targets);
    list.sort((a, b) {
      final byPeriod = b.period.compareTo(a.period);
      if (byPeriod != 0) return byPeriod;
      if (a.isCommon != b.isCommon) return a.isCommon ? -1 : 1;
      return a.appliesToLabel.toLowerCase().compareTo(
            b.appliesToLabel.toLowerCase(),
          );
    });
    return list;
  }

  String get _employeeName {
    if (_employeeEmail == _allEmployees) return '';
    for (final e in _employees) {
      if (e.email.trim().toLowerCase() == _employeeEmail) return e.fullName;
    }
    return '';
  }

  /// Picking a month + employee that already has a target loads it for editing;
  /// a pair without one starts empty, ready for a new target.
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
      // Upserts on (month, employee), so this creates or edits exactly that
      // target — other months, other employees, and the common target are never
      // touched.
      await MonthlyTargetService.save(
        year: _year,
        month: _month,
        target: value,
        employeeEmail: _employeeEmail,
        employeeName: _employeeName,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final who = _employeeEmail == _allEmployees
          ? 'all employees'
          : (_employeeName.isNotEmpty ? _employeeName : _employeeEmail);
      AppFeedback.success(
        context,
        'Target for ${MonthlyTarget.monthName(_month)} $_year ($who) saved.',
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
      appBar: FomraSubPageAppBar(
        title: 'Monthly Targets',
        breadcrumbs: FomraBreadcrumbs.forSettingsChild('Monthly Targets'),
      ),
      backgroundColor: context.fomraPageBg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionHeader(
            title: 'Monthly Targets',
            subtitle:
                'Set a common target for all employees, or a personal target for '
                'one. A personal target overrides the common one for that person.',
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
                ? 'This month + employee already has a target — saving updates it.'
                : 'Pick a month and who it is for, then set the target. Other '
                    'months and employees are unaffected.',
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 620;
              // Order per spec: Month, Employee, then Monthly Target.
              final fields = <Widget>[
                _monthField(context),
                _employeeField(context),
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
                  Expanded(flex: 4, child: fields[1]),
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

  /// All Employees (common target) plus every active employee. Selecting a
  /// person scopes the target to them.
  Widget _employeeField(BuildContext context) {
    // Guard against a stale selection (e.g. an employee deactivated between
    // loads) so the dropdown always has a matching item.
    final emails = {_allEmployees, for (final e in _employees) e.email.trim().toLowerCase()};
    final value = emails.contains(_employeeEmail) ? _employeeEmail : _allEmployees;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: FomraInput.decoration(
        context: context,
        label: 'Employee',
        icon: Icons.person_outline,
      ),
      items: [
        const DropdownMenuItem(
          value: _allEmployees,
          child: Text('All Employees'),
        ),
        for (final e in _employees)
          DropdownMenuItem(
            value: e.email.trim().toLowerCase(),
            child: Text(
              e.fullName.trim().isEmpty ? e.email : e.fullName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _employeeEmail = v);
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
                  DataColumn(label: Text('Applies to')),
                  DataColumn(label: Text('Target')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final t in _sortedTargets)
                    DataRow(
                      cells: [
                        DataCell(Text(t.label)),
                        DataCell(Text(t.appliesToLabel)),
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
