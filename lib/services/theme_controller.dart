import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide light/dark theme state, persisted across launches.
class ThemeController {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const _key = 'theme_mode';

  /// Listenable theme mode — drive [MaterialApp.themeMode] off this.
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  bool get isDark => mode.value == ThemeMode.dark;

  /// Restore the saved theme. Call once before the app builds.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value =
        prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDark(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dark ? 'dark' : 'light');
  }

  Future<void> toggle() => setDark(!isDark);
}
