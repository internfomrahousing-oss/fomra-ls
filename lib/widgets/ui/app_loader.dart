import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';

/// ============================================================================
/// Standard branded loading indicators.
///
/// Replaces bare `CircularProgressIndicator()` call sites so every spinner in
/// app content shares one look: brand primary colour, correct stroke weight and
/// consistent sizing.
///
/// - [AppLoader.inline]  → small spinner for buttons / inline content
/// - [AppLoader.center]  → centered spinner (+ optional message) for panels
/// - [showAppLoadingOverlay] / [hideAppLoadingOverlay] → modal blocking loader
///
/// For list/card placeholders, prefer the shimmering `LoadingSkeleton` in
/// `app_components.dart` instead of a spinner.
/// ============================================================================
class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth,
  });

  final double size;
  final Color? color;
  final double? strokeWidth;

  /// A small inline spinner (default 22px) tinted with the brand primary.
  factory AppLoader.inline({double size = 22, Color? color}) =>
      AppLoader(size: size, color: color);

  /// A centered spinner with an optional caption, for empty panels while
  /// their content loads.
  static Widget center({String? message, double size = 32}) =>
      _CenteredLoader(message: message, size: size);

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth ?? (size <= 24 ? 2.4 : 3),
        valueColor: AlwaysStoppedAnimation<Color>(c),
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader({this.message, this.size = 32});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLoader(size: size),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.fomraTextSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows a modal blocking loader over the whole screen. Call
/// [hideAppLoadingOverlay] (or pop the returned route) when the work finishes.
///
/// ```dart
/// showAppLoadingOverlay(context);
/// try { await doWork(); } finally { hideAppLoadingOverlay(context); }
/// ```
void showAppLoadingOverlay(BuildContext context, {String? message}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.modalScrim,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: ctx.fomraSurface,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            boxShadow: ctx.fomraElevatedShadow,
            border: Border.all(color: ctx.fomraBorder),
          ),
          child: _CenteredLoader(message: message),
        ),
      ),
    ),
  );
}

/// Dismisses the overlay opened by [showAppLoadingOverlay].
void hideAppLoadingOverlay(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
