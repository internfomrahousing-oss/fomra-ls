import 'package:flutter/material.dart';

import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/portal_page_layout.dart';
import 'employee_management_screen.dart';

/// Settings › User Management — manage employees and Access as any active user
/// from the same page (role filters + Access button on each card).
class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      backgroundColor: context.fomraPageBg,
      appBar: const FomraSubPageAppBar(title: 'User Management'),
      body: const EmployeeManagementScreen(isTab: true),
    );
  }
}

class EmployeeManagementPortalScreen extends StatelessWidget {
  const EmployeeManagementPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/employee-management',
      backgroundColor: context.fomraPageBg,
      appBar: const FomraAppBar(moduleName: 'Employee Management'),
      body: const EmployeeManagementScreen(isTab: true),
    );
  }
}
