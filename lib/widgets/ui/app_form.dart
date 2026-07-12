import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/fomra_input.dart';
import '../../theme/fomra_theme_context.dart';
import 'app_components.dart';

/// ============================================================================
/// Lightweight form scaffolding so screens stop hand-rolling labels, spacing
/// and button rows. Built on the existing [FomraInput] decoration and design
/// tokens. Pure presentation.
/// ============================================================================

/// A labelled text field with consistent spacing and optional inline helper.
///
/// Wraps a [TextFormField] using [FomraInput.decoration]. All behaviour
/// (controller, validator, callbacks) is passed straight through.
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.prefixIcon,
    this.suffixIcon,
    this.required = false,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.initialValue,
    this.textInputAction,
    this.autofocus = false,
    this.helperText,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool required;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final String? initialValue;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      style: TextStyle(color: context.fomraTextPrimary, fontSize: 15),
      decoration: FomraInput.decoration(
        context: context,
        label: label,
        hint: hint,
        icon: icon,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        required: required,
      ).copyWith(helperText: helperText),
    );
  }
}

/// A titled group of form fields with consistent vertical rhythm.
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.children,
    this.spacing = AppSpacing.md,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: title, subtitle: subtitle, icon: icon),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}

/// A right-aligned action bar for dialogs / forms: optional cancel + a primary
/// submit button with a built-in loading state.
class FormActionBar extends StatelessWidget {
  const FormActionBar({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.onCancel,
    this.cancelLabel = 'Cancel',
    this.loading = false,
    this.submitIcon,
    this.destructive = false,
    this.expand = false,
  });

  final String submitLabel;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;
  final String cancelLabel;
  final bool loading;
  final IconData? submitIcon;
  final bool destructive;

  /// When true the submit button fills the row (mobile-friendly).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final submit = destructive
        ? DangerButton(
            label: submitLabel,
            icon: submitIcon,
            loading: loading,
            onPressed: onSubmit,
            expand: expand && onCancel == null,
          )
        : PrimaryButton(
            label: submitLabel,
            icon: submitIcon,
            loading: loading,
            onPressed: onSubmit,
            expand: expand && onCancel == null,
          );

    if (onCancel == null) {
      return expand ? SizedBox(width: double.infinity, child: submit) : submit;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: loading ? null : onCancel,
          child: Text(cancelLabel),
        ),
        const SizedBox(width: AppSpacing.sm),
        submit,
      ],
    );
  }
}
