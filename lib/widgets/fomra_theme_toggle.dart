import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

/// Compact light/dark switch for the hero app bar.
class FomraThemeToggle extends StatelessWidget {
  const FomraThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final dimmed = Colors.white.withValues(alpha: 0.55);
        final bright = Colors.white.withValues(alpha: 0.95);

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Tooltip(
            message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.light_mode_outlined,
                  size: 15,
                  color: isDark ? dimmed : bright,
                ),
                const SizedBox(width: 2),
                Transform.scale(
                  scale: 0.82,
                  child: SwitchTheme(
                    data: SwitchThemeData(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF1E3A5F);
                        }
                        return Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white.withValues(alpha: 0.55);
                        }
                        return Colors.white.withValues(alpha: 0.28);
                      }),
                      trackOutlineColor:
                          WidgetStateProperty.all(Colors.transparent),
                    ),
                    child: Switch(
                      value: isDark,
                      onChanged: ThemeController.instance.setDark,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.dark_mode_outlined,
                  size: 15,
                  color: isDark ? bright : dimmed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
