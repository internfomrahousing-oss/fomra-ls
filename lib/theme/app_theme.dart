import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // ── Brand blue ──────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF2563EB); // blue-600
  static const Color primaryLight  = Color(0xFF60A5FA); // blue-400
  static const Color primaryDark   = Color(0xFF1D4ED8); // blue-700
  static const Color primaryDarker = Color(0xFF1E3A8A); // blue-900
  static const Color secondary     = Color(0xFF3B82F6); // blue-500
  static const Color accent        = Color(0xFF60A5FA);
  static const Color accentLight   = Color(0xFF93C5FD); // blue-300
  /// Legacy alias — maps to brand blue for older call sites.
  static const Color purple        = Color(0xFF3B82F6);

  // ── Surface (light, blue-tinted) ────────────────────────────────────────────
  static const Color background = Color(0xFFF4F8FF);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color surfaceVar = Color(0xFFEFF6FF);
  static const Color border     = Color(0xFFDBEAFE);

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary  = Color(0xFF94A3B8);

  // ── Dark surfaces (navy blue) ─────────────────────────────────────────────────
  static const Color darkBackground   = Color(0xFF0A1628);
  static const Color darkSurface      = Color(0xFF0F1F3D);
  static const Color darkSurfaceVar   = Color(0xFF152A52);
  static const Color darkBorder       = Color(0xFF1E3A5F);
  static const Color darkTextPrimary   = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary  = Color(0xFF64748B);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF2563EB);

  // ── Gradients ────────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF0A1628), Color(0xFF0F2447), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Radius tokens ── design-brief scale, rounder cards ────────────────────────
  static const double radiusXs = 12; // chips, small controls
  static const double radiusSm = 16; // buttons, inputs
  static const double radiusMd = 24; // cards (noticeably rounded)
  static const double radiusLg = 28; // large cards, bottom sheets
  static const double radiusXl = 32; // hero surfaces

  // ── Shadow tokens ── soft but clearly visible depth ───────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x18000000), blurRadius: 28, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0C000000), blurRadius: 8,  offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x28000000), blurRadius: 40, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.26), blurRadius: 18, offset: const Offset(0, 7)),
    BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 6,  offset: const Offset(0, 2)),
  ];
}

/// Spacing scale from the design brief: 4 · 8 · 12 · 16 · 24 · 32 · 48.
/// Use these instead of magic numbers so gaps stay consistent app-wide.
class AppSpacing {
  const AppSpacing._();
  static const double xxs = 4;
  static const double xs  = 8;
  static const double sm  = 12;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  // Ready-made SizedBox gaps for column/row layouts.
  static const SizedBox gapXxs = SizedBox(height: xxs, width: xxs);
  static const SizedBox gapXs  = SizedBox(height: xs,  width: xs);
  static const SizedBox gapSm  = SizedBox(height: sm,  width: sm);
  static const SizedBox gapMd  = SizedBox(height: md,  width: md);
  static const SizedBox gapLg  = SizedBox(height: lg,  width: lg);
  static const SizedBox gapXl  = SizedBox(height: xl,  width: xl);
}

/// Consistent icon sizing from the brief: primary 28 · secondary 22 · small 18.
class AppIconSize {
  const AppIconSize._();
  static const double primary   = 28;
  static const double secondary = 22;
  static const double small     = 18;
}

/// Motion tokens — brief calls for 150–250ms with easing.
class AppMotion {
  const AppMotion._();
  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow   = Duration(milliseconds: 250);
  static const Curve curve     = Curves.easeOutCubic;
}

const _fontFamily = 'Inter';

TextTheme _textTheme({
  required Color primary,
  required Color secondary,
  required Color tertiary,
}) =>
    TextTheme(
      displayLarge:  TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1.08, color: primary),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.9, height: 1.12, color: primary),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.18, color: primary),
      headlineMedium:TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.22, color: primary),
      titleLarge:    TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.28, color: primary),
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
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accentLight,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryDark,
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
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
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
      backgroundColor: AppColors.primaryDark,
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
      primary: AppColors.primaryLight,
      secondary: AppColors.secondary,
      tertiary: AppColors.accentLight,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryDark,
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
      backgroundColor: AppColors.primary,
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
