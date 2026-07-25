import 'package:flutter/material.dart';

import '../employee_management/employee_management_portal_screen.dart';

/// Kept for older deep links / bookmarks. Access as User now lives inside
/// Settings › User Management (role filters + Access button on each card).
class AccessAsUserPage extends StatelessWidget {
  const AccessAsUserPage({super.key});

  @override
  Widget build(BuildContext context) => const UserManagementPage();
}
