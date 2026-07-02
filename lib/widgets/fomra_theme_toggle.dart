import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

/// Single flash button for the hero app bar: flash on in dark mode,
/// normal (flash off) in light mode.
class FomraThemeToggle extends StatelessWidget {
  const FomraThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(
              isDark ? Icons.flash_on : Icons.flash_off,
              color: Colors.white.withValues(alpha: isDark ? 0.95 : 0.55),
            ),
            onPressed: () => ThemeController.instance.setDark(!isDark),
          ),
        );
      },
    );
  }
}
