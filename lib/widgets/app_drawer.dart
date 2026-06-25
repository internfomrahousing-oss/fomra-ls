import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;

  const _MenuItem(this.title, this.icon, this.route);
}

const _menuItems = [
  _MenuItem('LandWorkspace', Icons.location_on_outlined, '/land-lead'),
  _MenuItem('Dashboard & Reports', Icons.dashboard_outlined, '/dashboard'),
];

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _DrawerHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isActive = currentRoute == item.route;
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1A2E4A), width: 1)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accent,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin User', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Text('info@fomrahousing.in', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
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
