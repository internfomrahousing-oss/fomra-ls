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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: GestureDetector(
        onTap: () => _goHome(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.house_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('FomraLS',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 0.3)),
            if (moduleName != null) ...[
              const Text('  ·  ',
                  style: TextStyle(color: Colors.white38, fontSize: 16)),
              Text(moduleName!,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70)),
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
        transitionDuration: const Duration(milliseconds: 280),
      ),
      (_) => false,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
