import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomra_ls/screens/settings/settings_screen.dart';
import 'package:fomra_ls/services/auth_service.dart';
import 'package:fomra_ls/services/theme_controller.dart';
import 'package:fomra_ls/theme/app_theme.dart';

/// Wraps SettingsScreen in an app shell that honours ThemeController, so theme
/// switching is observable exactly as it is in the real app.
Widget _app() => ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (_, mode, __) => MaterialApp(
        theme: appTheme(),
        darkTheme: appThemeDark(),
        themeMode: mode,
        home: const SettingsScreen(),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ThemeController.instance.mode.value = ThemeMode.light;
    await AuthService.instance.logout(); // reset singleton state
  });

  Future<void> phoneSurface(WidgetTester tester) async {
    // Roomy logical surface (1200x2000) so the app-bar title row doesn't
    // overflow at narrow widths — a cosmetic layout concern, not under test.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('change password validates empty and mismatched input',
      (tester) async {
    await phoneSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();

    // Empty submit -> field validator fires.
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    // Invalid email format.
    final field = find.byType(TextFormField).first;
    await tester.enterText(field, 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  // Note: login and password-change now go through real Supabase Auth only
  // (no default/offline fallback), so those end-to-end flows are covered by
  // manual/live testing rather than these offline widget tests.
}
