import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';

class _ModuleTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

/// Hub for advanced business modules.
class BusinessModulesHubScreen extends StatelessWidget {
  const BusinessModulesHubScreen({super.key});

  static const modules = <_ModuleTile>[
    _ModuleTile(
      title: 'Broker Management',
      subtitle: 'Performance, leads, conversions, success rate',
      icon: Icons.handshake_outlined,
      color: AppColors.secondary,
      route: '/broker-management',
    ),
    _ModuleTile(
      title: 'Land Bank',
      subtitle: 'GIS-based land inventory',
      icon: Icons.map_outlined,
      color: AppColors.info,
      route: '/land-bank',
    ),
    _ModuleTile(
      title: 'Legal Tracker',
      subtitle: 'EC, verification, approvals',
      icon: Icons.gavel_outlined,
      color: AppColors.purple,
      route: '/legal-tracker',
    ),
    _ModuleTile(
      title: 'Survey Tracker',
      subtitle: 'Schedule, completion, pending',
      icon: Icons.architecture_outlined,
      color: AppColors.warning,
      route: '/survey-tracker',
    ),
    _ModuleTile(
      title: 'Owner History',
      subtitle: 'Historical negotiations',
      icon: Icons.history_outlined,
      color: AppColors.success,
      route: '/owner-history',
    ),
    _ModuleTile(
      title: 'Cost Calculator',
      subtitle: 'Cost per acre & acquisition cost',
      icon: Icons.calculate_outlined,
      color: AppColors.primary,
      route: '/cost-calculator',
    ),
    _ModuleTile(
      title: 'Field Calendar',
      subtitle: 'Site visits, meetings, surveys + reminders',
      icon: Icons.calendar_month_outlined,
      color: AppColors.accent,
      route: '/field-calendar',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/business-modules',
      appBar: const FomraAppBar(moduleName: 'Modules'),
      body: ListView(
        padding: FomraLayout.pagePadding(context),
        children: [
          Text(
            'Business Modules',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Broker, land bank, legal, survey, owners, costs, and calendar.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 2.8 : 1.55,
                children: [
                  for (final m in modules)
                    AppCard(
                      onTap: () => Navigator.pushNamed(context, m.route),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: m.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(m.icon, color: m.color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  m.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.fomraTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.fomraTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: context.fomraTextSecondary),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
