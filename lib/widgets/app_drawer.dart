import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;

  const _MenuItem(this.title, this.icon, this.route);
}

const _baseMenuItems = [
  _MenuItem('Land Workspace', Icons.space_dashboard_outlined, '/land-lead'),
  _MenuItem('Market Intelligence', Icons.insights_outlined, '/market-intelligence'),
  _MenuItem('Dashboard', Icons.dashboard_outlined, '/dashboard'),
];

const _managementMenuItem =
    _MenuItem('Employee Management', Icons.groups_outlined, '/employee-management');

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      ..._baseMenuItems.take(1),
      if (AuthService.instance.isManagement) _managementMenuItem,
      ..._baseMenuItems.skip(1),
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
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
        color: AppColors.primaryDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.domain, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'FomraLS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const Text(
              'Fomra Housing',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isActive ? AppColors.accentLight : const Color(0xFFB0BEC5),
          size: 22,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFCFD8DC),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1A2E4A), width: 1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accent,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFF90A4AE),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF90A4AE), size: 20),
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
