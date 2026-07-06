import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Theme-aware colors for screens that previously hard-coded light palette.
extension FomraThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get fomraPageBg =>
      isDarkMode ? AppColors.darkBackground : AppColors.background;

  Color get fomraSurface => Theme.of(this).colorScheme.surface;

  Color get fomraSurfaceVar =>
      isDarkMode ? AppColors.darkSurfaceVar : AppColors.surfaceVar;

  Color get fomraBorder =>
      isDarkMode ? AppColors.darkBorder : AppColors.border;

  Color get fomraTextPrimary => Theme.of(this).colorScheme.onSurface;

  Color get fomraTextSecondary =>
      isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;

  Color get fomraTextTertiary =>
      isDarkMode ? AppColors.darkTextTertiary : AppColors.textTertiary;

  List<BoxShadow> get fomraCardShadow => isDarkMode
      ? const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ]
      : AppColors.cardShadow;

  LinearGradient get fomraHeroGradient => isDarkMode
      ? const LinearGradient(
          colors: [
            Color(0xFF0B1220),
            Color(0xFF152A52),
            Color(0xFF1E293B),
            Color(0xFF231B4A),
          ],
          stops: [0.0, 0.38, 0.72, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : AppColors.heroGradient;
}
