import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../models/monthly_target_submission.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/monthly_target_submission_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/monthly_target_editor.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_feedback.dart';

/// Employee page (inside Settings) to propose this month's targets across the
/// four categories and submit them for management approval. Once submitted the
/// form is read-only until approved, or unlocked again if rejected.
class EmployeeMonthlyTargetsPage extends StatefulWidget {
  const EmployeeMonthlyTargetsPage({super.key});

  @override
  State<EmployeeMonthlyTargetsPage> createState() =>
      _EmployeeMonthlyTargetsPageState();
}

class _EmployeeMonthlyTargetsPageState
    extends State<EmployeeMonthlyTargetsPage> {
  final DateTime _now = DateTime.now();

  Map<String, int> _values = const {};
  EmployeeProfile? _profile;
  List<MonthlyTargetSubmission> _history = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  var _editorKey = GlobalKey<MonthlyTargetEditorState>();

  String get _email =>
      (AuthService.instance.currentUser?.email ?? '').trim().toLowerCase();
  String get _name => AuthService.instance.currentUser?.fullName ?? '';

  /// The month this page is for — always the *next* calendar month, since
  /// targets are meant to be set before the month they cover begins, not
  /// during it.
  DateTime get _targetMonth => DateTime(_now.year, _now.month + 1);
  String get _period =>
      MonthlyTargetSubmission.periodOf(_targetMonth.year, _targetMonth.month);

  /// The current month's period — used only to check whether it was ever
  /// submitted, so a missed deadline can be surfaced clearly.
  String get _currentPeriod =>
      MonthlyTargetSubmission.periodOf(_now.year, _now.month);

  MonthlyTargetSubmission? _forPeriod(String period) {
    for (final s in _history) {
      if (s.period == period) return s;
    }
    return null;
  }

  /// This month's submission, if the employee already has one.
  MonthlyTargetSubmission? get _current => _forPeriod(_period);

  /// True when there's no submission at all for the month that's already
  /// under way — the deadline (before that month began) has passed.
  bool get _currentMonthMissed => _forPeriod(_currentPeriod) == null;

  /// Editable when there's no submission yet, or the last one was rejected.
  bool get _editable {
    final c = _current;
    return c == null || c.isRejected;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      MonthlyTargetSubmissionService.getForEmployee(_email),
      EmployeeService.findByEmail(_email),
    ]);
    if (!mounted) return;
    setState(() {
      _history = results[0] as List<MonthlyTargetSubmission>;
      _profile = results[1] as EmployeeProfile?;
      _values = _current?.submittedValues ?? const {};
      _editorKey = GlobalKey<MonthlyTargetEditorState>();
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final missing = _editorKey.currentState?.missingMandatory ?? const [];
    if (missing.isNotEmpty) {
      setState(() => _error =
          '${missing.map((c) => c.label).join(', ')} ${missing.length == 1 ? 'is' : 'are'} required.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await MonthlyTargetSubmissionService.submit(
        year: _targetMonth.year,
        month: _targetMonth.month,
        values: _values,
        employeeEmail: _email,
        employeeName: _name,
        employeeCode: _profile?.id ?? '',
        department: _profile?.department ?? '',
        designation: _profile?.designation ?? '',
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      AppFeedback.success(context, 'Targets submitted for approval.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      appBar: FomraSubPageAppBar(
        title: 'Set Monthly Targets',
        breadcrumbs: FomraBreadcrumbs.forSettingsChild('Set Monthly Targets'),
      ),
      backgroundColor: context.fomraPageBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                SectionHeader(
                  title: 'My Monthly Targets',
                  subtitle:
                      'Propose your targets for ${MonthlyTargetSubmission.monthName(_targetMonth.month)} ${_targetMonth.year} and submit them for management approval before that month begins.',
                  icon: Icons.flag_outlined,
                ),
                if (_currentMonthMissed) ...[
                  const SizedBox(height: AppSpacing.md),
                  _missedDeadlineBanner(context),
                ],
                if (_current != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _statusBanner(context, _current!),
                  const SizedBox(height: AppSpacing.md),
                ],
                _formCard(context),
                const SizedBox(height: AppSpacing.md),
                _historyCard(context),
              ],
            ),
    );
  }

  Widget _missedDeadlineBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No target was set for ${MonthlyTargetSubmission.monthName(_now.month)} '
              '${_now.year} before it began. Targets are due before the month they '
              "cover starts — this month's window has passed.",
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.error,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(BuildContext context, MonthlyTargetSubmission s) {
    final color = s.status.color;
    final message = s.isPending
        ? 'Submitted and awaiting management approval. The form is locked until it is reviewed.'
        : s.isApproved
            ? (s.managementEdited
                ? 'Approved with modifications by management.'
                : 'Approved by management.')
            : 'Rejected — review and resubmit below.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            s.isApproved
                ? Icons.check_circle_outline
                : s.isRejected
                    ? Icons.cancel_outlined
                    : Icons.hourglass_top_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fomraTextSecondary,
                  ),
                ),
                if (s.isApproved && s.managementEdited) ...[
                  const SizedBox(height: 6),
                  _valuesLine(context, 'Approved', s.approvedValues ?? const {}),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valuesLine(BuildContext context, String label, Map<String, int> v) {
    final parts = [
      for (final c in TargetCategory.values)
        if (v.containsKey(c.key)) '${c.label} ${v[c.key]}',
    ];
    return Text(
      '$label: ${parts.isEmpty ? '—' : parts.join(' · ')}',
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: context.fomraTextPrimary,
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    final editable = _editable;
    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editable ? 'Set your targets' : 'Submitted targets',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            editable
                ? 'Tick each category you want a target for and enter a whole number (0–999).'
                : 'These are locked while under review. You can edit again only if they are rejected.',
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          MonthlyTargetEditor(
            key: _editorKey,
            initial: _values,
            readOnly: !editable,
            onChanged: (v) {
              _values = v;
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ],
          if (editable) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(_current?.isRejected == true
                    ? 'Resubmit for approval'
                    : 'Submit for approval'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(BuildContext context) {
    if (_history.isEmpty) {
      return const AppCard(
        interactive: false,
        child: EmptyState(
          icon: Icons.history_outlined,
          title: 'No submissions yet',
          message: 'Submit your targets above and they will be listed here.',
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
                minWidth: MediaQuery.sizeOf(context).width < 760 ? 560 : 0,
              ),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 60,
                headingRowColor:
                    WidgetStateProperty.all(context.fomraSurfaceVar),
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Submitted')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Approval details')),
                ],
                rows: [
                  for (final s in _history)
                    DataRow(cells: [
                      DataCell(Text(s.monthLabel)),
                      DataCell(Text(_fmtDate(s.submittedAt))),
                      DataCell(_statusChip(s)),
                      DataCell(Text(_approvalDetail(s))),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _approvalDetail(MonthlyTargetSubmission s) {
    if (s.isPending) return 'Awaiting approval';
    final who = s.approvedBy.isEmpty ? 'Management' : s.approvedBy;
    final when = s.approvedAt == null ? '' : ' · ${_fmtDate(s.approvedAt!)}';
    if (s.isApproved) {
      return '${s.managementEdited ? 'Approved (modified)' : 'Approved'} by $who$when';
    }
    return 'Rejected by $who$when';
  }

  Widget _statusChip(MonthlyTargetSubmission s) {
    final color = s.status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        s.status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}
