import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics/monthly_target_progress.dart';
import '../models/monthly_target.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';

/// An employee's progress against the common monthly target: the headline
/// numbers, then actual vs the ideal run-rate across the days of the month.
///
/// Green when at or above the run-rate, orange when behind.
class MonthlyTargetProgressCard extends StatelessWidget {
  final MonthlyTargetProgress progress;

  /// The month being shown — for the "no target" wording.
  final DateTime month;

  const MonthlyTargetProgressCard({
    super.key,
    required this.progress,
    required this.month,
  });

  Color get _accent =>
      progress.isOnTrack ? AppColors.success : AppColors.warning;

  String get _statusLabel => progress.isOnTrack ? 'On track' : 'Behind target';

  @override
  Widget build(BuildContext context) {
    if (!progress.hasTarget) {
      return AppCard(
        interactive: false,
        child: EmptyState(
          icon: Icons.flag_outlined,
          title: 'No target set',
          message:
              'Management has not set a target for ${MonthlyTarget.monthName(month.month)} yet.',
        ),
      );
    }

    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: AppSpacing.md),
          _summary(context),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 190, child: _chart(context)),
          const SizedBox(height: AppSpacing.sm),
          _legend(context),
          const Divider(height: AppSpacing.lg * 1.2),
          _footStats(context),
        ],
      ),
    );
  }

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
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: context.fomraSurfaceVar,
            valueColor: AlwaysStoppedAnimation(_accent),
          ),
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

  Widget _footStats(BuildContext context) {
    final stats = <({String label, String value, Color color})>[
      (
        label: 'Current target',
        value: '${progress.target}',
        color: context.fomraTextPrimary
      ),
      (label: 'Achieved', value: '${progress.achieved}', color: _accent),
      (
        label: 'Remaining',
        value: '${progress.remaining}',
        color: context.fomraTextPrimary
      ),
      (
        label: 'Expected today',
        // Display only — the underlying expectedToday stays a precise double
        // and still drives isOnTrack/variance.
        value: '${progress.expectedToday.round()}',
        color: context.fomraTextSecondary
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // Two rows of two on a phone, one row of four with room.
        final perRow = c.maxWidth < 420 ? 2 : 4;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in stats)
              SizedBox(
                width: (c.maxWidth - AppSpacing.sm * (perRow - 1)) / perRow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: s.color,
                      ),
                    ),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
