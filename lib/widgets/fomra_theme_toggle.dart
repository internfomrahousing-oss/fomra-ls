import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme/fomra_theme_context.dart';

/// Theme button for the hero app bar: moon in dark mode, sun in light mode.
class FomraThemeToggle extends StatelessWidget {
  const FomraThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined,
              color: Colors.white.withValues(alpha: isDark ? 0.95 : 0.55),
            ),
            onPressed: () => ThemeController.instance.setDark(!isDark),
          ),
        );
      },
    );
  }
}
