import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomra_ls/screens/settings/settings_screen.dart';
import 'package:fomra_ls/services/theme_controller.dart';
import 'package:fomra_ls/theme/app_theme.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ThemeController.instance.mode.value = ThemeMode.light;
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (_, mode, __) => MaterialApp(
          theme: appTheme(),
          darkTheme: appThemeDark(),
          themeMode: mode,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.textContaining('Manage account options'), findsOneWidget);
  });
}
