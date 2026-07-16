import 'package:flutter/services.dart';

/// Shared validation for the app's phone-number fields (owner, broker, contact).
/// An Indian mobile number: exactly 10 digits, nothing else.
abstract final class PhoneValidation {
  /// Digits-only input, capped at 10 — blocks alphabets, symbols and spaces as
  /// they're typed, and stops the 11th digit.
  static final inputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  /// Whether [value] is a valid 10-digit number.
  static bool isValid(String? value) {
    final v = (value ?? '').trim();
    return v.length == 10 && !v.split('').any((c) => c.codeUnitAt(0) < 48 || c.codeUnitAt(0) > 57);
  }

  /// A form validator: exactly 10 digits. A [required] field also rejects an
  /// empty value; an optional one accepts blank but still rejects a partial
  /// number. [label] names the field in the message.
  static String? Function(String?) validator(String label, {required bool required}) {
    return (value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return required ? '$label is required' : null;
      if (!isValid(v)) return 'Enter a valid 10-digit $label';
      return null;
    };
  }
}
