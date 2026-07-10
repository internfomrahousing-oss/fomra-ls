import 'package:flutter/material.dart';

import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import 'employee_management_screen.dart';

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
