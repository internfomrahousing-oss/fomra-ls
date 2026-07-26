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

/// An employee's progress toward their monthly per-category targets, shown as a
/// clean "progress timeline" per KPI: a milestone track that fills toward the
/// monthly goal (completed = brand colour, remaining = muted), with today's
/// cumulative marker, a dashed target line, and an on-track / behind badge.
class MonthlyTargetProgressCard extends StatelessWidget {
  final MonthlyTargetProgress progress;

  /// The month being shown — also "today" for the timeline markers/tooltip.
  final DateTime month;

  /// When true, the employee has submitted targets that are still awaiting
  /// management approval — so the empty state can explain the wait.
  final bool pendingApproval;

  /// Opens Settings › Set Monthly Targets so the employee can propose/resubmit.
  final VoidCallback? onSetTarget;

  /// Per-category series (Leads / Site Visits / Meetings). When non-empty the
  /// card shows a progress timeline per category; otherwise a set-target prompt.
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
    if (categories.isEmpty) return _setTargetMessage(context);

    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: 22),
            _ProgressTimeline(category: categories[i], today: month),
          ],
          const SizedBox(height: 4),
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

  /// Shown when there are no approved per-category targets to graph: either the
  /// submission is awaiting approval, or the user hasn't set targets yet.
  Widget _setTargetMessage(BuildContext context) {
    final monthLabel = MonthlyTarget.monthName(month.month);
    final message = pendingApproval
        ? 'Your $monthLabel targets are awaiting management approval.'
        : 'Set your monthly targets under Settings › Set Monthly Targets to '
            'track your Leads, Site Visits and Meetings here.';
    return AppCard(
      interactive: false,
      child: Column(
        children: [
          EmptyState(
            icon: pendingApproval
                ? Icons.hourglass_top_outlined
                : Icons.flag_outlined,
            title: pendingApproval ? 'Awaiting approval' : 'Set your targets',
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
}

/// A single KPI's progress timeline: a rounded milestone track that fills toward
/// the monthly target. Completed portion is the KPI colour (with a subtle
/// gradient), the remaining portion is muted; milestone checkpoints light up as
/// they are reached, today's cumulative point is a larger glowing marker, a
/// faint tick shows the ideal run-rate for today, and a dashed line marks the
/// goal. The fill animates in. Hover shows a rich tooltip.
class _ProgressTimeline extends StatelessWidget {
  final MonthlyTargetCategoryProgress category;
  final DateTime today;

  const _ProgressTimeline({required this.category, required this.today});

  /// Milestone checkpoints along the track, as fractions of the target.
  static const _milestones = [0.25, 0.5, 0.75, 1.0];

  int get _dailyIncrement {
    final days = category.progress.actualByDay;
    if (days.isEmpty) return 0;
    if (days.length == 1) return days.first;
    return days[days.length - 1] - days[days.length - 2];
  }

  @override
  Widget build(BuildContext context) {
    final p = category.progress;
    final color = category.color;
    final target = p.target;
    final achieved = p.achieved;
    final frac = target <= 0 ? 0.0 : (achieved / target).clamp(0.0, 1.0);
    final expectedFrac =
        target <= 0 ? 0.0 : (p.expectedToday / target).clamp(0.0, 1.0);
    final pct = (frac * 100).round();

    final tooltip = [
      'Date: ${today.day} ${MonthlyTarget.monthName(today.month)} ${today.year}',
      'Current value: $achieved',
      'Target: $target',
      'Remaining: ${p.remaining}',
      'Achievement: $pct%',
      'Daily increment: +$_dailyIncrement',
    ].join('\n');

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      textStyle: const TextStyle(
          color: Colors.white, fontSize: 12, height: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xF2111827),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _labelRow(context, color, pct),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: LayoutBuilder(
              builder: (context, c) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, animFrac, _) => _track(
                  context,
                  width: c.maxWidth,
                  frac: animFrac,
                  expectedFrac: expectedFrac,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelRow(BuildContext context, Color color, int pct) {
    final p = category.progress;
    return Row(
      children: [
        Icon(_iconFor(category.label), size: 15, color: color),
        const SizedBox(width: 7),
        Text(
          category.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.fomraTextPrimary,
          ),
        ),
        const Spacer(),
        Text(
          '${p.achieved}',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          ' / ${p.target}',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.fomraTextSecondary),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$pct%',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(String label) => switch (label) {
        'Leads' => Icons.person_add_alt_1_outlined,
        'Site Visits' => Icons.location_on_outlined,
        'Meetings' => Icons.groups_outlined,
        _ => Icons.flag_outlined,
      };

  static const _trackTop = 16.0;
  static const _trackHeight = 10.0;
  double get _trackCenter => _trackTop + _trackHeight / 2;

  Widget _track(
    BuildContext context, {
    required double width,
    required double frac,
    required double expectedFrac,
    required Color color,
  }) {
    final fillW = (frac * width).clamp(frac > 0 ? _trackHeight : 0.0, width);
    return SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dashed target line marking the monthly goal.
          Positioned(
            left: 0,
            right: 0,
            top: 3,
            height: 2,
            child: CustomPaint(
              painter: _DashedLinePainter(color.withValues(alpha: 0.45)),
            ),
          ),
          // Remaining (muted) track.
          Positioned(
            left: 0,
            right: 0,
            top: _trackTop,
            height: _trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.fomraSurfaceVar,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.fomraBorder),
              ),
            ),
          ),
          // Completed portion — brand colour with a subtle gradient.
          Positioned(
            left: 0,
            top: _trackTop,
            width: fillW,
            height: _trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.75), color],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Ideal run-rate for today — a faint vertical indicator.
          Positioned(
            left: (expectedFrac * width).clamp(0.0, width),
            top: 8,
            height: 26,
            child: Container(
              width: 1.5,
              color: context.fomraTextTertiary.withValues(alpha: 0.6),
            ),
          ),
          // Milestone checkpoints — solid once reached, faded ring otherwise.
          for (final m in _milestones)
            Positioned(
              left: (m * width) - 7,
              top: _trackCenter - 7,
              child: _milestone(context, reached: frac >= m - 0.001, color: color),
            ),
          // Today's cumulative progress — larger glowing marker.
          Positioned(
            left: (fillW - 9).clamp(0.0, width - 18),
            top: _trackCenter - 9,
            child: _todayMarker(context, color),
          ),
        ],
      ),
    );
  }

  Widget _milestone(BuildContext context,
          {required bool reached, required Color color}) =>
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: reached ? color : context.fomraSurface,
          border: Border.all(
            color: reached ? color : context.fomraBorder,
            width: 2,
          ),
          boxShadow: reached
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      );

  Widget _todayMarker(BuildContext context, Color color) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: context.fomraSurface, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      );
}

/// Thin horizontal dashed line, painted across the available width.
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 5.0;
    const gap = 4.0;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
