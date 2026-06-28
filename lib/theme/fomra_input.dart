import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared input field styling — matches the login screen fill-up size.
class FomraInput {
  FomraInput._();

  static const double borderRadius = 10;
  static const EdgeInsets contentPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 14);
  static const BorderSide borderSide = BorderSide(color: Color(0xFFE0E0E0));
  static const BorderSide focusedBorderSide =
      BorderSide(color: AppColors.primary, width: 2);

  static OutlineInputBorder _outline({BorderSide? side}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: side ?? borderSide,
      );

  static InputDecoration decoration({
    String? label,
    String? hint,
    IconData? icon,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool required = false,
  }) {
    return InputDecoration(
      labelText: label != null ? label + (required ? ' *' : '') : null,
      hintText: hint,
      isDense: true,
      prefixIcon: prefixIcon ??
          (icon != null
              ? Icon(icon, size: 20, color: AppColors.primary)
              : null),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: _outline(),
      enabledBorder: _outline(),
      focusedBorder: _outline(side: focusedBorderSide),
      errorBorder: _outline(side: const BorderSide(color: AppColors.error)),
      focusedErrorBorder:
          _outline(side: const BorderSide(color: AppColors.error, width: 2)),
      contentPadding: contentPadding,
    );
  }
}
