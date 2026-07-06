import 'dart:ui';

import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_layout.dart';
import '../theme/fomra_theme_context.dart';

class FomraBottomNav extends StatelessWidget {
  final String currentRoute;
  const FomraBottomNav({super.key, required this.currentRoute});

  static List<_NavItem> _itemsForUser() {
    final items = [
      const _NavItem('/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
      const _NavItem('/land-lead', Icons.space_dashboard_outlined,
          Icons.space_dashboard, 'Workspace'),
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
    final wide = FomraLayout.isDesktop(context);

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: context.isDarkMode ? 0.78 : 0.92),
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            border: Border.all(
              color: context.isDarkMode
                  ? border.withValues(alpha: 0.75)
                  : AppColors.primary.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: items.map((item) {
              final isActive = currentRoute == item.route ||
                  (item.route == '/land-lead' &&
                      currentRoute == '/task-management');
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTap(context, item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(vertical: wide ? 11 : 9),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.primaryGradient : null,
                      color: isActive
                          ? null
                          : Colors.transparent,
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
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            key: ValueKey('${item.route}-$isActive'),
                            color: isActive ? Colors.white : inactive,
                            size: wide ? 22 : 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: wide ? 11 : 10,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? Colors.white : inactive,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          wide ? 32 : 16,
          8,
          wide ? 32 : 16,
          12,
        ),
        child: wide
            ? Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: FomraLayout.maxContentWidth),
                  child: bar,
                ),
              )
            : bar,
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
