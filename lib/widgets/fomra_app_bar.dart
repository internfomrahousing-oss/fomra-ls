import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../theme/app_theme.dart';

class FomraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? moduleName;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const FomraAppBar({super.key, this.moduleName, this.actions, this.bottom});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: GestureDetector(
        onTap: () => _goHome(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12), width: 1),
              ),
              child: const Icon(Icons.house_outlined, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('FomraLS',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 0.1)),
            if (moduleName != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 1, height: 14,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Text(moduleName!,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75))),
            ],
          ],
        ),
      ),
      actions: actions,
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
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
