import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF2454FF);
  static const Color primaryLight = Color(0xFF5B7FFF);
  static const Color primaryDark  = Color(0xFF1A43E2);
  static const Color secondary    = Color(0xFF7C3AED); // purple accent
  static const Color accent       = Color(0xFF5B7FFF);
  static const Color accentLight  = Color(0xFFFBBF24);

  // ── Surface ───────────────────────────────────────────────────────────────────
  static const Color background   = Color(0xFFF6F8FC);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceVar   = Color(0xFFF8FAFF);
  static const Color border       = Color(0xFFE4E8F0);

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary  = Color(0xFF9CA3AF);

  // ── Dark surfaces ─────────────────────────────────────────────────────────────
  static const Color darkBackground   = Color(0xFF0F172A); // slate-900
  static const Color darkSurface      = Color(0xFF1E293B); // slate-800
  static const Color darkSurfaceVar   = Color(0xFF273449);
  static const Color darkBorder       = Color(0xFF334155); // slate-700
  static const Color darkTextPrimary   = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary  = Color(0xFF64748B);

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16C47F);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF2563EB);

  // ── Gradients ────────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F3EB5), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D2E8A), Color(0xFF1A56DB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Radius tokens ── softer, rounder corners ──────────────────────────────────
  static const double radiusXs = 8;
  static const double radiusSm = 14;
  static const double radiusMd = 22;
  static const double radiusLg = 24;
  static const double radiusXl = 28;

  // ── Shadow tokens ── soft, diffuse (Opendoor-style) ───────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 30, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x08000000), blurRadius: 8,  offset: Offset(0, 3)),
  ];

  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.26), blurRadius: 18, offset: const Offset(0, 7)),
    BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 6,  offset: const Offset(0, 2)),
  ];
}

const _fontFamily = 'Inter';

TextTheme _textTheme({
  required Color primary,
  required Color secondary,
  required Color tertiary,
}) =>
    TextTheme(
      displayLarge:  TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.1, height: 1.12, color: primary),
      displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.15, color: primary),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2,  color: primary),
      headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: primary),
      titleLarge:    TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.1, height: 1.3,  color: primary),
      titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.0,  height: 1.35, color: primary),
      titleSmall:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1,  height: 1.35, color: primary),
      bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.0,  height: 1.55, color: primary),
      bodyMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.0,  height: 1.55, color: secondary),
      bodySmall:     TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.0,  height: 1.5,  color: secondary),
      labelLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2,  color: primary),
      labelMedium:   TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4,  color: secondary),
      labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5,  color: tertiary),
    );

ThemeData appTheme() {
  const fontFamily = _fontFamily;

  final textTheme = _textTheme(
    primary: AppColors.textPrimary,
    secondary: AppColors.textSecondary,
    tertiary: AppColors.textTertiary,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary:   AppColors.primary,
      secondary: AppColors.secondary,
      tertiary:  AppColors.accent,
      surface:   AppColors.surface,
      error:     AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.primaryDark),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textTertiary,
          fontSize: 14),
      labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
          fontSize: 14),
    ),
    chipTheme: ChipThemeData(
      labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXs)),
      side: const BorderSide(color: AppColors.border),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
        color: AppColors.border, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}

ThemeData appThemeDark() {
  const fontFamily = _fontFamily;

  final textTheme = _textTheme(
    primary: AppColors.darkTextPrimary,
    secondary: AppColors.darkTextSecondary,
    tertiary: AppColors.darkTextTertiary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: fontFamily,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary:   AppColors.primaryLight,
      secondary: AppColors.secondary,
      tertiary:  AppColors.accent,
      surface:   AppColors.darkSurface,
      error:     AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.darkSurface),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceVar,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.darkTextTertiary,
          fontSize: 14),
      labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.darkTextSecondary,
          fontSize: 14),
    ),
    chipTheme: ChipThemeData(
      labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXs)),
      side: const BorderSide(color: AppColors.darkBorder),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSurfaceVar,
      contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}
