import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;

  const _MenuItem(this.title, this.icon, this.route);
}

const _baseMenuItems = [
  _MenuItem('Land Workspace', Icons.space_dashboard_outlined, '/land-lead'),
  _MenuItem('Market Intelligence', Icons.insights_outlined, '/market-intelligence'),
];

const _dashboardMenuItem =
    _MenuItem('Dashboard', Icons.dashboard_outlined, '/dashboard');

const _managementMenuItem =
    _MenuItem('Employee Management', Icons.groups_outlined, '/employee-management');

const _settingsMenuItem =
    _MenuItem('Settings', Icons.settings_outlined, '/settings');

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      _baseMenuItems[0],
      if (AuthService.instance.isManagement) _managementMenuItem,
      _baseMenuItems[1],
      if (AuthService.instance.isManagement) _dashboardMenuItem,
      _settingsMenuItem,
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
          _DrawerFooter(),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVar : AppColors.primaryDark,
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
                color: isDark
                    ? AppColors.primaryLight.withValues(alpha: 0.18)
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.35))
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
                fontSize: 22,
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
    final activeColor = isDark ? AppColors.primaryLight : AppColors.accentLight;
    final inactiveIcon = isDark ? context.fomraTextSecondary : const Color(0xFFB0BEC5);
    final inactiveText = isDark ? context.fomraTextSecondary : const Color(0xFFCFD8DC);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark
                ? AppColors.primaryLight.withValues(alpha: 0.12)
                : AppColors.accent.withValues(alpha: 0.2))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isActive ? activeColor : inactiveIcon,
          size: 22,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isActive
                ? (isDark ? context.fomraTextPrimary : Colors.white)
                : inactiveText,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (!isActive) {
            Navigator.pushReplacementNamed(context, item.route);
          }
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final name = user?.fullName ?? 'User';
    final email = user?.email ?? '';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.fomraBorder, width: 1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isDark
                ? AppColors.primaryLight.withValues(alpha: 0.22)
                : AppColors.accent,
            child: Text(
              initial,
              style: TextStyle(
                color: isDark ? AppColors.primaryLight : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isDark ? context.fomraTextPrimary : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: isDark ? context.fomraTextSecondary : const Color(0xFF90A4AE),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout,
                color: isDark ? context.fomraTextSecondary : const Color(0xFF90A4AE),
                size: 20),
            tooltip: 'Sign Out',
            onPressed: () {
              Navigator.pop(context);
              AuthService.instance.logout();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            },
          ),
        ],
      ),
    );
  }
}
