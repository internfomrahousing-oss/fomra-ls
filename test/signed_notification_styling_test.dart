import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/app_notification.dart';
import 'package:fomra_ls/models/notification_type_ext.dart';
import 'package:fomra_ls/theme/app_theme.dart';

AppNotification _row(String type) => AppNotification.fromRow({
      'id': '1',
      'title': 'Project approved & signed',
      'message': 'Lead #12 is now Signed',
      'type': type,
      'created_at': '2026-07-16T00:00:00.000Z',
      'is_read': false,
    });

void main() {
  group('Signed notifications read as success, not danger', () {
    test("a 'signed' notification parses to the signed type, not alert", () {
      expect(_row('signed').type, NotificationType.signed);
    });

    test('the signed type is green success, not red error', () {
      expect(NotificationType.signed.color, AppColors.success);
      expect(NotificationType.signed.color, isNot(AppColors.error));
    });

    test('the signed type uses a check-circle, not a warning icon', () {
      expect(NotificationType.signed.icon, Icons.check_circle);
    });

    test('signed round-trips through its db value', () {
      expect(NotificationType.signed.dbValue, 'signed');
      expect(_row(NotificationType.signed.dbValue).type, NotificationType.signed);
    });

    test('an unknown type still falls back to alert', () {
      expect(_row('something_new').type, NotificationType.alert);
    });
  });
}
