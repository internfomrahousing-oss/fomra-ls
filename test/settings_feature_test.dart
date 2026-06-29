import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomra_ls/screens/settings/settings_screen.dart';
import 'package:fomra_ls/services/api_client.dart';
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

  testWidgets('theme toggle switches the app between light and dark',
      (tester) async {
    await phoneSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(ThemeController.instance.mode.value, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(ThemeController.instance.mode.value, ThemeMode.light);
  });

  testWidgets('change password validates empty and mismatched input',
      (tester) async {
    await phoneSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Empty submit -> field validators fire.
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your current password'), findsOneWidget);
    expect(find.text('Enter a new password'), findsOneWidget);

    // Mismatched confirmation.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'fomra@2024');
    await tester.enterText(fields.at(1), 'newpass123');
    await tester.enterText(fields.at(2), 'different99');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('management can change password through the UI', (tester) async {
    await phoneSurface(tester);
    // Sign in as management (Supabase calls are guarded, so this works offline).
    await AuthService.instance.loginWithPortal(
        'management@fomrahousing.in', 'fomra@2024', LoginPortal.management);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'fomra@2024');
    await tester.enterText(fields.at(1), 'brandnew99');
    await tester.enterText(fields.at(2), 'brandnew99');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('Password updated successfully.'), findsOneWidget);

    // The new password is now the active one for the management portal.
    expect(await AuthService.instance.passwordForPortal(LoginPortal.management),
        'brandnew99');
  });

  test('login rejects the old password after a change', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.loginWithPortal(
        'management@fomrahousing.in', 'fomra@2024', LoginPortal.management);
    await AuthService.instance
        .changePassword(currentPassword: 'fomra@2024', newPassword: 'fresh123');

    // Old password no longer works.
    expect(
      () => AuthService.instance.loginWithPortal(
          'management@fomrahousing.in', 'fomra@2024', LoginPortal.management),
      throwsA(isA<ApiException>()),
    );
    // New password works.
    await AuthService.instance.loginWithPortal(
        'management@fomrahousing.in', 'fresh123', LoginPortal.management);
  });
}
