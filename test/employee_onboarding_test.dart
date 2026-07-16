import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/services/employee_service.dart';
import 'package:fomra_ls/widgets/credentials_dialog.dart';

void main() {
  group('generated temporary passwords', () {
    test('are the requested length', () {
      expect(EmployeeService.generatePassword().length, 10);
      expect(EmployeeService.generatePassword(length: 14).length, 14);
    });

    test('contain no ambiguous characters (0 O 1 l I)', () {
      // Excludes uppercase I/O, lowercase l, and digits 0/1 — keeps everything
      // else (including lowercase i, which reads fine).
      final allowed = RegExp(r'^[A-HJ-NP-Za-km-z2-9]+$');
      final banned = RegExp(r'[OIl01]');
      for (var i = 0; i < 200; i++) {
        final p = EmployeeService.generatePassword();
        expect(allowed.hasMatch(p), isTrue, reason: 'unexpected char in "$p"');
        expect(banned.hasMatch(p), isFalse, reason: 'ambiguous char in "$p"');
      }
    });

    test('are effectively unique each call', () {
      final seen = {for (var i = 0; i < 500; i++) EmployeeService.generatePassword()};
      // 500 draws from a 56^10 space should never collide.
      expect(seen.length, 500);
    });
  });

  group('the credentials dialog', () {
    Widget host(void Function(BuildContext) onTap) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => onTap(context),
                child: const Text('go'),
              ),
            ),
          ),
        );

    testWidgets('shows the email and password to hand over', (tester) async {
      await tester.pumpWidget(host((ctx) => showCredentialsDialog(
            ctx,
            email: 'sara@fomrahousing.in',
            password: 'Xy7k9pQrTz',
          )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('sara@fomrahousing.in'), findsOneWidget);
      expect(find.text('Xy7k9pQrTz'), findsOneWidget);
      expect(find.text('Login created'), findsOneWidget);
    });

    testWidgets('Copy puts both on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(host((ctx) => showCredentialsDialog(
            ctx,
            email: 'sara@fomrahousing.in',
            password: 'Xy7k9pQrTz',
          )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // The dialog's footer "Copy" button copies both lines.
      await tester.tap(find.widgetWithText(TextButton, 'Copy'));
      await tester.pumpAndSettle();

      expect(copied, 'Email: sara@fomrahousing.in\nPassword: Xy7k9pQrTz');
    });

    testWidgets('the title can name the employee', (tester) async {
      await tester.pumpWidget(host((ctx) => showCredentialsDialog(
            ctx,
            email: 'x@y.in',
            password: 'abcd',
            title: 'Sara added',
          )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Sara added'), findsOneWidget);
    });
  });
}
