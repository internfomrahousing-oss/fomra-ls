/// The common monthly target (number of sites/deals) every employee is measured
/// against. Management sets one per month; there is never more than one for the
/// same month.
class MonthlyTarget {
  final String id;
  final int year;

  /// 1-12.
  final int month;

  /// Sites/deals expected across the month.
  final int target;

  final DateTime updatedAt;
  final String updatedByName;

  const MonthlyTarget({
    required this.id,
    required this.year,
    required this.month,
    required this.target,
    required this.updatedAt,
    this.updatedByName = '',
  });

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
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      updatedByName: j['updated_by_name'] as String? ?? '',
    );
  }
}
