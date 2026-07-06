import 'dart:ui';

import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

class FomraBottomNav extends StatelessWidget {
  final String currentRoute;
  const FomraBottomNav({super.key, required this.currentRoute});

  static List<_NavItem> _itemsForUser() {
    final items = [
      const _NavItem('/home',                Icons.home_outlined,            Icons.home_rounded,        'Home'),
      const _NavItem('/land-lead',           Icons.space_dashboard_outlined, Icons.space_dashboard,     'Workspace'),
    ];
    if (AuthService.instance.isManagement) {
      items.add(const _NavItem(
        '/employee-management',
        Icons.groups_outlined,
        Icons.groups,
        'Employees',
      ));
    }
    items.add(const _NavItem(
      '/market-intelligence',
      Icons.insights_outlined,
      Icons.insights,
      'Market',
    ));
    if (AuthService.instance.isManagement) {
      items.add(const _NavItem(
        '/dashboard',
        Icons.bar_chart_outlined,
        Icons.bar_chart_rounded,
        'Dashboard',
      ));
    }
    return items;
  }

  void _onTap(BuildContext context, _NavItem item) {
    if (currentRoute == item.route) return;
    if (item.route == '/home') {
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
    } else {
      Navigator.pushNamed(context, item.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsForUser();
    final surface = context.fomraSurface;
    final border = context.fomraBorder;
    final inactive = context.fomraTextTertiary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: surface.withValues(alpha: context.isDarkMode ? 0.82 : 0.92),
                borderRadius: BorderRadius.circular(AppColors.radiusXl),
                border: Border.all(color: border.withValues(alpha: 0.75)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: context.isDarkMode
                        ? const Color(0x35000000)
                        : const Color(0x10000000),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: items.map((item) {
                  final isActive = currentRoute == item.route ||
                      (item.route == '/land-lead' &&
                          currentRoute == '/task-management');
                  return Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onTap(context, item),
                        child: AnimatedContainer(
                          duration: AppMotion.slow,
                          curve: AppMotion.curve,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            gradient: isActive ? AppColors.primaryGradient : null,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusLg),
                            boxShadow: isActive
                                ? AppColors.coloredShadow(AppColors.primary)
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: AppMotion.slow,
                                switchInCurve: AppMotion.curve,
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                                child: Icon(
                                  isActive ? item.activeIcon : item.icon,
                                  key: ValueKey('${item.route}-$isActive'),
                                  color: isActive ? Colors.white : inactive,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: AppMotion.normal,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive ? Colors.white : inactive,
                                  letterSpacing: 0.1,
                                ),
                                child: Text(item.label),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.route, this.icon, this.activeIcon, this.label);
}
