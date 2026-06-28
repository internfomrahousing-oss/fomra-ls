import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../theme/app_theme.dart';

class FomraBottomNav extends StatelessWidget {
  final String currentRoute;
  const FomraBottomNav({super.key, required this.currentRoute});

  static const _items = [
    _NavItem('/home',                Icons.home_outlined,            Icons.home_rounded,        'Home'),
    _NavItem('/land-lead',           Icons.space_dashboard_outlined, Icons.space_dashboard,     'Workspace'),
    _NavItem('/market-intelligence', Icons.insights_outlined,        Icons.insights,            'Market'),
    _NavItem('/dashboard',           Icons.bar_chart_outlined,       Icons.bar_chart_rounded,   'Reports'),
  ];

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: Row(
            children: _items.map((item) {
              final isActive = currentRoute == item.route ||
                  (item.route == '/land-lead' &&
                      currentRoute == '/task-management');
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTap(context, item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.primaryGradient : null,
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive
                              ? Colors.white
                              : AppColors.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : AppColors.textTertiary,
                            letterSpacing: 0.1,
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
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.route, this.icon, this.activeIcon, this.label);
}
