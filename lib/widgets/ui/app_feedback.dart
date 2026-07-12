import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';

/// Semantic tone for a feedback toast.
enum FeedbackTone { success, error, info, warning }

/// ============================================================================
/// Standardized, typed toast/snackbar feedback.
///
/// Replaces raw `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))`
/// call sites with a one-liner that carries a semantic tone (colour + icon):
///
/// ```dart
/// AppFeedback.success(context, 'Lead updated');
/// AppFeedback.error(context, 'Could not update status: $e');
/// AppFeedback.info(context, 'Management view is read-only');
/// ```
///
/// Pure presentation — no business logic. Every toast is a floating, rounded,
/// theme-aware surface with a coloured leading icon chip, an optional action,
/// and an accessible live-region announcement.
/// ============================================================================
class AppFeedback {
  const AppFeedback._();

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) =>
      _show(context, message, FeedbackTone.success,
          actionLabel: actionLabel, onAction: onAction, duration: duration);

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) =>
      _show(context, message, FeedbackTone.error,
          actionLabel: actionLabel, onAction: onAction, duration: duration);

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) =>
      _show(context, message, FeedbackTone.info,
          actionLabel: actionLabel, onAction: onAction, duration: duration);

  static void warning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) =>
      _show(context, message, FeedbackTone.warning,
          actionLabel: actionLabel, onAction: onAction, duration: duration);

  static Color _color(FeedbackTone tone) {
    switch (tone) {
      case FeedbackTone.success:
        return AppColors.success;
      case FeedbackTone.error:
        return AppColors.error;
      case FeedbackTone.info:
        return AppColors.info;
      case FeedbackTone.warning:
        return AppColors.warning;
    }
  }

  static IconData _icon(FeedbackTone tone) {
    switch (tone) {
      case FeedbackTone.success:
        return Icons.check_circle_rounded;
      case FeedbackTone.error:
        return Icons.error_rounded;
      case FeedbackTone.info:
        return Icons.info_rounded;
      case FeedbackTone.warning:
        return Icons.warning_rounded;
    }
  }

  static void _show(
    BuildContext context,
    String message,
    FeedbackTone tone, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final tokenColor = _color(tone);
    final isDark = context.isDarkMode;
    final surface = context.fomraSurface;
    final textColor = context.fomraTextPrimary;

    final defaultDuration = (tone == FeedbackTone.error ||
            tone == FeedbackTone.warning)
        ? const Duration(seconds: 4)
        : const Duration(seconds: 3);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        elevation: 0,
        duration: duration ?? defaultDuration,
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          side: BorderSide(
            color: tokenColor.withValues(alpha: isDark ? 0.55 : 0.35),
          ),
        ),
        content: Semantics(
          liveRegion: true,
          container: true,
          label: '${tone.name}: $message',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokenColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppColors.radiusXs),
                ),
                child: Icon(_icon(tone), color: tokenColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        action: (actionLabel != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: tokenColor,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }
}
