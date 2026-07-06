import 'dart:ui';

import 'package:flutter/material.dart';

import 'fomra_theme_context.dart';

/// Responsive layout tokens for a polished mobile + web experience.
class FomraLayout {
  const FomraLayout._();

  static const double maxContentWidth = 1140;
  static const double tabletBreakpoint = 640;
  static const double desktopBreakpoint = 960;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
    if (w >= tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 22, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  static Widget constrain(
    BuildContext context, {
    required Widget child,
    bool center = true,
  }) {
    final box = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isDesktop(context) ? maxContentWidth : double.infinity,
      ),
      child: child,
    );
    return center ? Align(alignment: Alignment.topCenter, child: box) : box;
  }
}

/// Frosted glass panel — iOS-style floating surface.
class FomraGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const FomraGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: context.isDarkMode ? 0.82 : 0.9),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: context.isDarkMode ? 0.1 : 0.7,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

extension FomraLayoutContext on BuildContext {
  bool get fomraIsDesktop => FomraLayout.isDesktop(this);
  bool get fomraIsTablet => FomraLayout.isTablet(this);
}
