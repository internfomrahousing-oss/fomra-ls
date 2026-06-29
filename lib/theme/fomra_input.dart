import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared input field styling — matches the login screen fill-up size.
class FomraInput {
  FomraInput._();

  static const double borderRadius = 10;
  static const EdgeInsets contentPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 14);

  static OutlineInputBorder _outline(BuildContext? context, {BorderSide? side}) {
    final borderColor = context != null && Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkBorder
        : const Color(0xFFE0E0E0);
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: side ?? BorderSide(color: borderColor),
    );
  }

  static InputDecoration decoration({
    required BuildContext context,
    String? label,
    String? hint,
    IconData? icon,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool required = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? AppColors.darkSurfaceVar : Colors.white;
    final iconColor = isDark ? AppColors.primaryLight : AppColors.primary;
    const focusedSide = BorderSide(color: AppColors.primary, width: 2);

    return InputDecoration(
      labelText: label != null ? label + (required ? ' *' : '') : null,
      hintText: hint,
      isDense: true,
      prefixIcon: prefixIcon ??
          (icon != null ? Icon(icon, size: 20, color: iconColor) : null),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      border: _outline(context),
      enabledBorder: _outline(context),
      focusedBorder: _outline(context, side: focusedSide),
      errorBorder: _outline(context, side: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: _outline(
        context,
        side: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: contentPadding,
    );
  }
}
