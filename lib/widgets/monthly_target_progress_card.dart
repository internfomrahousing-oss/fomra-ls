import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics/monthly_target_progress.dart';
import '../models/monthly_target.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';

/// One named category tracked on the progress card (Leads / Site Visits /
/// Meetings), with its own colour and day-by-day progress series.
class MonthlyTargetCategoryProgress {
  final String label;
  final Color color;
  final MonthlyTargetProgress progress;

  const MonthlyTargetCategoryProgress({
    required this.label,
    required this.color,
    required this.progress,
  });
}

/// An employee's progress against their monthly target: the headline numbers,
/// then actual vs the ideal run-rate across the days of the month.
///
/// Green when at or above the run-rate, orange when behind.
class MonthlyTargetProgressCard extends StatelessWidget {
  final MonthlyTargetProgress progress;

  /// The month being shown — for the "no target" wording.
  final DateTime month;

  /// When true, the employee has submitted targets that are still awaiting
  /// management approval — so the empty state can explain the wait.
  final bool pendingApproval;

  /// Opens Settings › Set Monthly Targets so the employee can propose/resubmit.
  final VoidCallback? onSetTarget;

  /// Per-category series (Leads / Site Visits / Meetings). When non-empty the
  /// card shows a box per category plus a line per category; otherwise it shows
  /// the single overall series.
  final List<MonthlyTargetCategoryProgress> categories;

  const MonthlyTargetProgressCard({
    super.key,
    required this.progress,
    required this.month,
    this.pendingApproval = false,
    this.onSetTarget,
    this.categories = const [],
  });

  Color get _accent =>
      progress.isOnTrack ? AppColors.success : AppColors.warning;

  String get _statusLabel => progress.isOnTrack ? 'On track' : 'Behind target';

  @override
  Widget build(BuildContext context) {
    if (!progress.hasTarget) {
      final monthLabel = MonthlyTarget.monthName(month.month);
      final message = pendingApproval
          ? 'Your $monthLabel targets are awaiting management approval.'
          : 'No target set for $monthLabel yet. Propose yours under '
              'Settings › Set Monthly Targets.';
      return AppCard(
        interactive: false,
        child: Column(
          children: [
            EmptyState(
              icon: pendingApproval
                  ? Icons.hourglass_top_outlined
                  : Icons.flag_outlined,
              title: pendingApproval ? 'Awaiting approval' : 'No target set',
              message: message,
            ),
            if (onSetTarget != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onSetTarget,
                icon: Icon(
                  pendingApproval
                      ? Icons.visibility_outlined
                      : Icons.flag_outlined,
                  size: 18,
                ),
                label: Text(
                  pendingApproval ? 'View my submission' : 'Set my targets',
                ),
              ),
            ],
          ],
        ),
      );
    }

    final multi = categories.isNotEmpty;
    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: AppSpacing.md),
          if (multi) ...[
            _categoryBoxes(context),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 190, child: _multiChart(context)),
            const SizedBox(height: AppSpacing.sm),
            _multiLegend(context),
          ] else ...[
            _summary(context),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 190, child: _chart(context)),
            const SizedBox(height: AppSpacing.sm),
            _legend(context),
          ],
        ],
      ),
    );
  }

  /// A box per category showing completed / total (achieved / target).
  Widget _categoryBoxes(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _categoryBox(context, categories[i])),
          ],
        ],
      );

  Widget _categoryBox(BuildContext context, MonthlyTargetCategoryProgress c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${c.progress.achieved}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.color,
                ),
              ),
              Text(
                ' / ${c.progress.target}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            c.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// One line per category — cumulative achieved across the days of the month.
  Widget _multiChart(BuildContext context) {
    var maxVal = 1.0;
    for (final c in categories) {
      if (c.progress.target > maxVal) maxVal = c.progress.target.toDouble();
      for (final a in c.progress.actualByDay) {
        if (a > maxVal) maxVal = a.toDouble();
      }
    }
    final daysInMonth =
        categories.isEmpty ? 30 : categories.first.progress.daysInMonth;

    Widget axisText(String s) =>
        Text(s, style: TextStyle(fontSize: 9, color: context.fomraTextTertiary));

    return LineChart(
      LineChartData(
        minX: 1,
        maxX: daysInMonth.toDouble(),
        minY: 0,
        maxY: maxVal * 1.1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.fomraBorder.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                if (v != v.roundToDouble() || v == meta.max) {
                  return const SizedBox.shrink();
                }
                return axisText('${v.toInt()}');
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 5,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: axisText('${v.toInt()}'),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${categories[s.barIndex].label}: ${s.y.toStringAsFixed(0)}',
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: categories[s.barIndex].color,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final c in categories)
            LineChartBarData(
              spots: [
                for (var i = 0; i < c.progress.actualByDay.length; i++)
                  FlSpot((i + 1).toDouble(), c.progress.actualByDay[i].toDouble()),
              ],
              isCurved: false,
              color: c.color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _multiLegend(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final c in categories)
            _legendDot(context, c.color, c.label, dashed: false),
        ],
      );

  Widget _header(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              '${MonthlyTarget.monthName(month.month)} ${month.year}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
          ),
        ],
      );

  Widget _summary(BuildContext context) {
    final pct = progress.completionPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${progress.achieved}',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: context.fomraTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '/ ${progress.target} sites',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.fomraTextSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chart(BuildContext context) {
    final target = progress.target.toDouble();
    final maxAchieved = progress.actualByDay.isEmpty
        ? 0
        : progress.actualByDay.reduce((a, b) => a > b ? a : b);
    // Headroom so a line that beats the target isn't clipped.
    final maxY = (maxAchieved > target ? maxAchieved.toDouble() : target) * 1.1;

    return LineChart(
      LineChartData(
        minX: 1,
        maxX: progress.daysInMonth.toDouble(),
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.fomraBorder.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                if (v != v.roundToDouble() || v == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${v.toInt()}',
                  style: TextStyle(fontSize: 9, color: context.fomraTextTertiary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              // Every 5th day keeps the axis readable on a phone.
              interval: 5,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${v.toInt()}',
                  style: TextStyle(fontSize: 9, color: context.fomraTextTertiary),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${s.barIndex == 0 ? 'Achieved' : 'Target'}: '
                  '${s.y.toStringAsFixed(s.barIndex == 0 ? 0 : 1)}',
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: s.barIndex == 0 ? _accent : context.fomraTextSecondary,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          // Actual progress.
          LineChartBarData(
            spots: [
              for (var i = 0; i < progress.actualByDay.length; i++)
                FlSpot((i + 1).toDouble(), progress.actualByDay[i].toDouble()),
            ],
            isCurved: false,
            color: _accent,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _accent.withValues(alpha: 0.10),
            ),
          ),
          // Ideal run-rate.
          LineChartBarData(
            spots: [
              for (var i = 0; i < progress.targetByDay.length; i++)
                FlSpot((i + 1).toDouble(), progress.targetByDay[i]),
            ],
            isCurved: false,
            color: context.fomraTextTertiary,
            barWidth: 1.5,
            dashArray: const [5, 4],
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  // Wraps rather than a Row: the two labels don't fit side by side on a narrow
  // phone once the text scales up.
  Widget _legend(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          _legendDot(context, _accent, 'Actual progress', dashed: false),
          _legendDot(context, context.fomraTextTertiary, 'Target progress',
              dashed: true),
        ],
      );

  Widget _legendDot(BuildContext context, Color color, String label,
          {required bool dashed}) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: dashed ? null : color,
              borderRadius: BorderRadius.circular(2),
              border: dashed ? Border.all(color: color, width: 1.2) : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.fomraTextSecondary),
          ),
        ],
      );

}
