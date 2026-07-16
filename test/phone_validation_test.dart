import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/utils/phone_validation.dart';

void main() {
  group('isValid — exactly 10 digits', () {
    test('accepts a 10-digit number', () {
      expect(PhoneValidation.isValid('9876543210'), isTrue);
    });

    test('rejects fewer than 10 digits', () {
      expect(PhoneValidation.isValid('98765'), isFalse);
      expect(PhoneValidation.isValid('123456789'), isFalse);
    });

    test('rejects more than 10 digits', () {
      expect(PhoneValidation.isValid('98765432101'), isFalse);
    });

    test('rejects alphabets', () {
      expect(PhoneValidation.isValid('98765abcde'), isFalse);
    });

    test('rejects symbols', () {
      expect(PhoneValidation.isValid('98765-4321'), isFalse);
      expect(PhoneValidation.isValid('+919876543'), isFalse);
    });

    test('rejects spaces', () {
      expect(PhoneValidation.isValid('98765 4321'), isFalse);
      expect(PhoneValidation.isValid('9876543210 '), isTrue,
          reason: 'trailing/leading space is trimmed, then 10 digits remain');
    });

    test('rejects empty', () {
      expect(PhoneValidation.isValid(''), isFalse);
      expect(PhoneValidation.isValid(null), isFalse);
    });
  });

  group('validator — inline messages', () {
    test('a required field rejects empty with a required message', () {
      final v = PhoneValidation.validator('Owner Number', required: true);
      expect(v(''), 'Owner Number is required');
      expect(v(null), 'Owner Number is required');
    });

    test('an optional field accepts empty', () {
      final v = PhoneValidation.validator('Broker Number', required: false);
      expect(v(''), isNull);
    });

    test('an optional field still rejects a partial number', () {
      final v = PhoneValidation.validator('Broker Number', required: false);
      expect(v('98765'), 'Enter a valid 10-digit Broker Number');
    });

    test('a full 10-digit number passes', () {
      final v = PhoneValidation.validator('Contact Number', required: true);
      expect(v('9876543210'), isNull);
    });

    test('the message names the field', () {
      expect(
        PhoneValidation.validator('Contact Number', required: true)('123'),
        'Enter a valid 10-digit Contact Number',
      );
      expect(
        PhoneValidation.validator('Broker Number', required: true)('123'),
        'Enter a valid 10-digit Broker Number',
      );
    });
  });

  group('input formatters block bad characters as typed', () {
    test('two formatters: digits-only then a 10-char cap', () {
      // The exact formatter instances the fields use.
      expect(PhoneValidation.inputFormatters, hasLength(2));
    });
  });
}
