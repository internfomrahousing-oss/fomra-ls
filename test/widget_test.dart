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

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });
}
