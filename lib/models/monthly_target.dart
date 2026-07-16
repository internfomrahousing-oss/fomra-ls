/// A monthly target (number of sites/deals) management sets. Either COMMON —
/// applies to every active employee ([employeeEmail] empty) — or PERSONAL to one
/// employee. Each (month, employee) pair has at most one.
class MonthlyTarget {
  final String id;
  final int year;

  /// 1-12.
  final int month;

  /// Sites/deals expected across the month.
  final int target;

  /// Empty for the common target; otherwise the employee this target is for.
  final String employeeEmail;

  /// Display name for a personal target ('' for the common one).
  final String employeeName;

  final DateTime updatedAt;
  final String updatedByName;

  const MonthlyTarget({
    required this.id,
    required this.year,
    required this.month,
    required this.target,
    required this.updatedAt,
    this.employeeEmail = '',
    this.employeeName = '',
    this.updatedByName = '',
  });

  /// Whether this is the common target shared by every active employee.
  bool get isCommon => employeeEmail.trim().isEmpty;

  /// Who the target applies to, for display.
  String get appliesToLabel => isCommon
      ? 'All employees'
      : (employeeName.trim().isNotEmpty ? employeeName.trim() : employeeEmail);

  /// The target an employee is measured against, given the [candidates] for one
  /// month: their personal target if present, else the common one, else null. A
  /// personal target always overrides the common one.
  static MonthlyTarget? pickFor(
    Iterable<MonthlyTarget> candidates,
    String employeeEmail,
  ) {
    final email = employeeEmail.trim().toLowerCase();
    MonthlyTarget? common;
    for (final t in candidates) {
      if (email.isNotEmpty && t.employeeEmail == email) return t;
      if (t.isCommon) common = t;
    }
    return common;
  }

  /// The stored key for a month — also the table's UNIQUE column, which is what
  /// keeps a month to a single target.
  static String periodOf(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  String get period => periodOf(year, month);

  /// The target covering the month [now] falls in.
  bool isActiveAt(DateTime now) => year == now.year && month == now.month;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String monthName(int month) => _monthNames[month - 1];

  String get label => '${monthName(month)} $year';

  factory MonthlyTarget.fromJson(Map<String, dynamic> j) {
    final period = (j['period'] as String? ?? '').split('-');
    return MonthlyTarget(
      id: j['id'] as String,
      year: int.tryParse(period.isNotEmpty ? period[0] : '') ?? 0,
      month: int.tryParse(period.length > 1 ? period[1] : '') ?? 1,
      target: (j['target_count'] as num?)?.toInt() ?? 0,
      // Older rows (pre per-employee) have no employee column → common target.
      employeeEmail: (j['employee_email'] as String? ?? '').trim().toLowerCase(),
      employeeName: j['employee_name'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      updatedByName: j['updated_by_name'] as String? ?? '',
    );
  }
}
