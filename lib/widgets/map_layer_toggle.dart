import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

/// Standard/Satellite toggle chips, meant to sit as a `Positioned` overlay
/// on top of a `FlutterMap`. Extracted from Market Intelligence's map (the
/// one screen that already had this working) so every other map in the app
/// can use the same tested toggle instead of only ever showing the
/// standard layer — confirmed directly in code that Project Map, Lead
/// Detail's embedded map, and Add Lead's map were all hardcoded to
/// MapTilerTiles.standard with no way to switch to satellite at all.
class MapLayerToggle extends StatelessWidget {
  final bool satellite;
  final ValueChanged<bool> onChanged;

  const MapLayerToggle({
    super.key,
    required this.satellite,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(context, selected: !satellite, label: 'Standard',
            icon: Icons.map_outlined, onTap: () => onChanged(false)),
        const SizedBox(width: 6),
        _chip(context, selected: satellite, label: 'Satellite',
            icon: Icons.satellite_alt_outlined, onTap: () => onChanged(true)),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDarkMode;
    const darkSurface = Color(0xFF1E293B);
    final selectedBg = isDark ? AppColors.primaryLight : AppColors.primary;
    final unselectedBg =
        (isDark ? darkSurface : Colors.white).withValues(alpha: 0.94);
    const selectedFg = Colors.white;
    final unselectedFg =
        isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.primary;
    final borderColor = selected
        ? Colors.transparent
        : (isDark
            ? Colors.white.withValues(alpha: 0.18)
            : context.fomraBorder.withValues(alpha: 0.85));

    return Material(
      color: selected ? selectedBg : unselectedBg,
      elevation: selected ? 2 : 1,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? selectedFg : unselectedFg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? selectedFg : unselectedFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
