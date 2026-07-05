import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';

/// ============================================================================
/// FomraLS reusable UI component library.
///
/// Pure presentation widgets built on the shared design tokens (AppColors,
/// AppSpacing, AppIconSize, AppMotion). They contain NO business logic — every
/// value/label/callback is passed in — so screens can adopt them without any
/// change to providers, services, models or routing.
/// ============================================================================

/// A premium surface card: white/dark surface, subtle border, soft shadow, and
/// a smooth press/hover elevation animation when [onTap] is provided.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.radius = AppColors.radiusMd,
    this.color,
    this.border = true,
    this.interactive = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final bool border;

  /// When false, disables the hover/press elevation animation.
  final bool interactive;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _lift => widget.interactive && (widget.onTap != null) && (_hovered || _pressed);

  @override
  Widget build(BuildContext context) {
    final surface = widget.color ?? context.fomraSurface;
    final radius = BorderRadius.circular(widget.radius);

    final card = AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      transform: _lift ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: radius,
        border: widget.border
            ? Border.all(color: context.fomraBorder, width: 1)
            : null,
        boxShadow: _lift ? AppColors.elevatedShadow : context.fomraCardShadow,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (widget.onTap == null) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            splashColor: AppColors.primary.withValues(alpha: 0.06),
            highlightColor: AppColors.primary.withValues(alpha: 0.03),
            child: card,
          ),
        ),
      ),
    );
  }
}

/// A KPI / statistic tile: icon chip, animated value, label and optional trend.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent = AppColors.primary,
    this.trendLabel,
    this.trendUp,
    this.onTap,
    this.animateValue = true,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color accent;
  final String? trendLabel;
  final bool? trendUp;
  final VoidCallback? onTap;

  /// When [value] is purely numeric, count up to it on first build.
  final bool animateValue;

  @override
  Widget build(BuildContext context) {
    final numeric = int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Icon(icon, color: accent, size: AppIconSize.secondary),
                ),
              const Spacer(),
              if (trendLabel != null) _TrendPill(label: trendLabel!, up: trendUp ?? true),
            ],
          ),
          AppSpacing.gapMd,
          (animateValue && numeric != null)
              ? AnimatedCounter(
                  value: numeric,
                  prefix: value.startsWith(RegExp(r'[^0-9-]'))
                      ? value.replaceAll(RegExp(r'[0-9].*'), '')
                      : '',
                  style: Theme.of(context).textTheme.displaySmall ??
                      Theme.of(context).textTheme.headlineLarge,
                )
              : Text(
                  value,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary,
                      ),
                ),
          AppSpacing.gapXxs,
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.fomraTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// Backwards-friendly alias — the brief lists both MetricCard and StatisticCard.
typedef StatisticCard = MetricCard;

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.label, required this.up});
  final String label;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: color),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Semantic status badge used across lists, tables and detail screens.
enum StatusTone { neutral, primary, success, warning, danger, purple, info }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.filled = true,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool filled;

  Color get _color {
    switch (tone) {
      case StatusTone.primary:
        return AppColors.primary;
      case StatusTone.success:
        return AppColors.success;
      case StatusTone.warning:
        return AppColors.warning;
      case StatusTone.danger:
        return AppColors.error;
      case StatusTone.purple:
        return AppColors.purple;
      case StatusTone.info:
        return AppColors.info;
      case StatusTone.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.0 : 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}

/// A titled section divider with optional subtitle and trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.secondary, color: AppColors.primary),
            AppSpacing.gapSm,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: context.fomraTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.fomraTextSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A friendly empty / zero-state with icon, message and optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            AppSpacing.gapLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.fomraTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (message != null) ...[
              AppSpacing.gapXs,
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.fomraTextSecondary,
                    ),
              ),
            ],
            if (action != null) ...[
              AppSpacing.gapLg,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmering skeleton block for loading placeholders.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppColors.radiusXs,
  });

  final double? width;
  final double height;
  final double radius;

  /// Convenience: a vertical stack of skeleton lines.
  static Widget lines(BuildContext context,
      {int count = 3, double spacing = AppSpacing.sm}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : spacing),
          child: LoadingSkeleton(width: i.isEven ? double.infinity : 180),
        ),
      ),
    );
  }

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.isDarkMode ? const Color(0xFF273449) : const Color(0xFFE9EEF5);
    final highlight =
        context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFF5F8FC);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(-1.0 - 2 * _c.value, 0),
              end: Alignment(1.0 - 2 * _c.value, 0),
            ),
          ),
        );
      },
    );
  }
}

/// A compact horizontal info row: leading icon chip, title and subtitle.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent = AppColors.primary,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: accent, size: AppIconSize.small),
            ),
            AppSpacing.gapSm,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.fomraTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.fomraTextSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A large tappable navigation tile for dashboards / home grids.
class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = AppColors.primary,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              boxShadow: AppColors.coloredShadow(accent),
            ),
            child: Icon(icon, color: Colors.white, size: AppIconSize.primary),
          ),
          AppSpacing.gapMd,
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.fomraTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.fomraTextSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded, theme-aware search field.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onClear,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: context.fomraTextPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search_rounded,
            size: AppIconSize.small, color: context.fomraTextTertiary),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
                tooltip: 'Clear',
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: context.fomraBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: context.fomraBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

/// ── Buttons ────────────────────────────────────────────────────────────────
/// Thin wrappers over the theme's button styles that add a press-scale
/// animation and a built-in loading state. They keep functionality identical —
/// [onPressed] is called through unchanged.

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.enabled});
  final Widget child;
  final bool enabled;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => setState(() => _scale = 0.96),
      onPointerUp: (_) => setState(() => _scale = 1.0),
      onPointerCancel: (_) => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

class _ButtonBody extends StatelessWidget {
  const _ButtonBody({required this.label, this.icon, this.loading = false, this.foreground});
  final String label;
  final IconData? icon;
  final bool loading;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(foreground ?? Colors.white),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppIconSize.small),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = _PressScale(
      enabled: onPressed != null && !loading,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: _ButtonBody(label: label, icon: icon, loading: loading),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = _PressScale(
      enabled: onPressed != null && !loading,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: _ButtonBody(
            label: label, icon: icon, loading: loading, foreground: AppColors.primary),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = _PressScale(
      enabled: onPressed != null && !loading,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
        child: _ButtonBody(label: label, icon: icon, loading: loading),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// A number that animates from 0 → [value] whenever [value] changes.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final effective = (style ??
            Theme.of(context).textTheme.headlineLarge ??
            const TextStyle())
        .copyWith(fontWeight: FontWeight.w800, color: context.fomraTextPrimary);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix$v$suffix', style: effective),
    );
  }
}
