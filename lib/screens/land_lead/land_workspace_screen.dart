import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import '../employee_management/employee_management_screen.dart';
import '../task_management/task_management_screen.dart';
import 'land_lead_screen.dart';

class LandWorkspaceScreen extends StatefulWidget {
  final int initialTab;
  const LandWorkspaceScreen({super.key, this.initialTab = 0});

  @override
  State<LandWorkspaceScreen> createState() => _LandWorkspaceScreenState();
}

class _LandWorkspaceScreenState extends State<LandWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final List<_TabDef> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
    final tabIndex = widget.initialTab.clamp(0, _tabs.length - 1);
    _tab = TabController(length: _tabs.length, vsync: this, initialIndex: tabIndex);
    _tab.addListener(() => setState(() {}));
  }

  List<_TabDef> _buildTabs() {
    final tabs = [
      const _TabDef('Land Lead', Icons.add_location_alt_outlined),
      const _TabDef('Tasks', Icons.task_alt_outlined),
    ];
    if (AuthService.instance.isManagement) {
      tabs.add(const _TabDef('Employees', Icons.groups_outlined));
    }
    return tabs;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FomraAppBar(
        moduleName: 'Land Workspace',
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          isScrollable: _tabs.length > 3,
          tabs: _tabs
              .map((t) => Tab(
                    icon: Icon(t.icon, size: 18),
                    text: t.label,
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ))
              .toList(),
        ),
      ),
      drawer: const AppDrawer(currentRoute: '/land-lead'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/land-lead'),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const LandLeadScreen(isTab: true),
          const TaskManagementScreen(isTab: true),
          if (AuthService.instance.isManagement)
            const EmployeeManagementScreen(isTab: true),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef(this.label, this.icon);
}
