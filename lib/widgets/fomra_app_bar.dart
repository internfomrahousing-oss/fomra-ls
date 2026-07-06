import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_layout.dart';
import '../theme/fomra_theme_context.dart';
import 'fomra_theme_toggle.dart';

class FomraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? moduleName;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const FomraAppBar({super.key, this.moduleName, this.actions, this.bottom});

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= FomraLayout.desktopBreakpoint;
    final toolbarHeight = wide ? 64.0 : kToolbarHeight;
    return AppBar(
      toolbarHeight: toolbarHeight,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: context.fomraHeroGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _goHome(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: const Icon(Icons.house_outlined,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('FomraLS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.1)),
                ],
              ),
            ),
          ),
          if (moduleName != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Text(moduleName!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9))),
            ),
          ],
        ],
      ),
      actions: [
        ...?actions,
        const FomraThemeToggle(),
      ],
      bottom: bottom,
    );
  }

  static void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
      (_) => false,
    );
  }

  @override
  Size get preferredSize {
    // Match [build] toolbar height; callers with [bottom] must use a non-const
    // FomraAppBar so MediaQuery is available — portal screens are always const
    // width but height is driven by kToolbarHeight + bottom.
    return Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
  }
}
