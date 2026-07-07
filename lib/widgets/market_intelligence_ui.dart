import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

/// Premium section shell — icon, title, optional subtitle, 16px radius.
class MarketIntelSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const MarketIntelSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.fomraBorder.withValues(alpha: 0.55)),
        boxShadow: context.fomraCardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.14),
                      AppColors.accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

/// Label / value tile for parcel and record summaries.
class MarketIntelInfoTile extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  const MarketIntelInfoTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  @override
  State<MarketIntelInfoTile> createState() => _MarketIntelInfoTileState();
}

class _MarketIntelInfoTileState extends State<MarketIntelInfoTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? AppColors.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? accent.withValues(alpha: 0.35)
                : context.fomraBorder.withValues(alpha: 0.75),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 17, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted floating control for map overlays.
class MarketIntelGlassButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool primary;

  const MarketIntelGlassButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
    this.primary = false,
  });

  @override
  State<MarketIntelGlassButton> createState() => _MarketIntelGlassButtonState();
}

class _MarketIntelGlassButtonState extends State<MarketIntelGlassButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ??
        (widget.primary ? Colors.white : context.fomraTextPrimary);
    final enabled = widget.onTap != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: AppMotion.fast,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hovered ? 0.16 : 0.1),
                  blurRadius: _hovered ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.primary
                        ? AppColors.primary.withValues(
                            alpha: enabled ? (_hovered ? 0.92 : 0.86) : 0.45,
                          )
                        : context.fomraSurface.withValues(
                            alpha: _hovered ? 0.92 : 0.82,
                          ),
                    border: Border.all(
                      color: widget.primary
                          ? Colors.white.withValues(alpha: 0.18)
                          : context.fomraBorder.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: enabled
                        ? iconColor
                        : iconColor.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Radius / filter chip with enterprise styling.
class MarketIntelFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const MarketIntelFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: context.fomraSurfaceVar,
      side: BorderSide(
        color: selected
            ? AppColors.primary
            : context.fomraBorder.withValues(alpha: 0.8),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : context.fomraTextSecondary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onSelected: onSelected,
    );
  }
}

IconData marketIntelIconForField(String label) {
  final key = label.toLowerCase();
  if (key.contains('district')) return Icons.map_outlined;
  if (key.contains('taluk')) return Icons.location_city_outlined;
  if (key.contains('village')) return Icons.home_work_outlined;
  if (key.contains('survey')) return Icons.grid_on_outlined;
  if (key.contains('sub')) return Icons.view_column_outlined;
  if (key.contains('ulpin')) return Icons.fingerprint_outlined;
  if (key.contains('area')) return Icons.square_foot_outlined;
  if (key.contains('land')) return Icons.landscape_outlined;
  return Icons.info_outline;
}
