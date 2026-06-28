import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import 'employee_management_screen.dart';

class EmployeeManagementPortalScreen extends StatelessWidget {
  const EmployeeManagementPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: FomraAppBar(moduleName: 'Employee Management'),
      drawer: AppDrawer(currentRoute: '/employee-management'),
      bottomNavigationBar: FomraBottomNav(currentRoute: '/employee-management'),
      body: EmployeeManagementScreen(isTab: true),
    );
  }
}
