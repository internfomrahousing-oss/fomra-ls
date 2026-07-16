import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/widgets/ui/app_feedback.dart';

// The real thing management needs to read: Supabase's rate-limit explanation.
const _reason =
    'Email rate limit reached. Supabase\'s built-in email service only allows '
    'a few messages per hour — configure a custom SMTP provider in Supabase → '
    'Authentication → Emails → SMTP Settings, then re-send.';

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => AppFeedback.errorDetails(
            context,
            title: 'Invite email failed',
            message: _reason,
          ),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the whole reason, not a truncated flash', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _open(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Invite email failed'), findsOneWidget);
    // The full text is present and selectable so it can be copied out.
    final body = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(body.data, _reason);
  });

  testWidgets('stays put instead of fading away like a toast', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _open(tester);

    // Well past the 4s an error toast would have lived for.
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('closes on Close', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _open(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('Copy puts the reason on the clipboard and closes',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    await _open(tester);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copied, _reason);
    expect(find.byType(SelectableText), findsNothing);
  });
}
