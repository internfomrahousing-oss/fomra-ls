import 'package:flutter/material.dart';

import '../../theme/fomra_theme_context.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import 'employee_management_screen.dart';

class EmployeeManagementPortalScreen extends StatelessWidget {
  const EmployeeManagementPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fomraPageBg,
      appBar: const FomraAppBar(moduleName: 'Employee Management'),
      drawer: const AppDrawer(currentRoute: '/employee-management'),
      bottomNavigationBar:
          const FomraBottomNav(currentRoute: '/employee-management'),
      body: const EmployeeManagementScreen(isTab: true),
    );
  }
}
