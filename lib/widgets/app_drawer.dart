import 'package:flutter/material.dart';

import '../theme/fomra_layout.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final Color accent;

  const _MenuItem(this.title, this.icon, this.route, this.accent);
}

const _baseMenuItems = [
  _MenuItem('Land Workspace', Icons.space_dashboard_outlined, '/land-lead',
      Color(0xFF5B7FFF)),
  _MenuItem('Market Intelligence', Icons.insights_outlined,
      '/market-intelligence', Color(0xFF22D3EE)),
];

const _managementMenuItem = _MenuItem('Employee Management',
    Icons.groups_outlined, '/employee-management', Color(0xFFA78BFA));

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      _baseMenuItems[0],
      if (AuthService.instance.isManagement) _managementMenuItem,
      _baseMenuItems[1],
    ];

    return Drawer(
      child: Column(
        children: [
          _DrawerHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isActive = currentRoute == item.route ||
                    (item.route == '/land-lead' &&
                        currentRoute == '/task-management');
                return _DrawerTile(item: item, isActive: isActive);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final titleSize = FomraLayout.responsiveClamp(
      context,
      min: 20,
      max: 22,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [
                    Color(0xFF152A52),
                    Color(0xFF1E293B),
                    Color(0xFF2A2258),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isDark ? null : AppColors.primaryDark,
          border: isDark
              ? Border(bottom: BorderSide(color: context.fomraBorder))
              : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          colors: [
                            AppColors.primaryLight.withValues(alpha: 0.35),
                            AppColors.secondary.withValues(alpha: 0.28),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isDark ? null : AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                  border: isDark
                      ? Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.4))
                      : null,
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: AppColors.primaryLight.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(Icons.domain,
                    color: isDark ? AppColors.primaryLight : Colors.white,
                    size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                'FomraLS',
                style: TextStyle(
                  color: isDark ? context.fomraTextPrimary : Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'Fomra Housing',
                style: TextStyle(
                  color: isDark ? context.fomraTextSecondary : const Color(0xFFB0BEC5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final _MenuItem item;
  final bool isActive;

  const _DrawerTile({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final accent = item.accent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: isDark ? 0.14 : 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.25))
            : null,
      ),
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isActive ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            item.icon,
            color: accent,
            size: 18,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isActive
                ? (isDark ? Colors.white : Colors.white)
                : (isDark ? context.fomraTextPrimary : const Color(0xFFCFD8DC)),
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (!isActive) {
            Navigator.pushReplacementNamed(context, item.route);
          }
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

