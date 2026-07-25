import 'package:flutter/material.dart';

import '../../services/app_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_feedback.dart';

/// Management toggles for Add Lead capture rules and the approval chain.
class FeatureControlsPage extends StatefulWidget {
  const FeatureControlsPage({super.key});

  @override
  State<FeatureControlsPage> createState() => _FeatureControlsPageState();
}

class _FeatureControlsPageState extends State<FeatureControlsPage> {
  final _settings = AppSettingsService.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    // Always refresh so this page shows org-wide values, not a stale cache.
    await _settings.reload();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle({
    required Future<void> Function(bool) setter,
    required bool next,
    required String okMessage,
  }) async {
    try {
      await setter(next);
      if (!mounted) return;
      AppFeedback.success(context, okMessage);
    } catch (e) {
      if (!mounted) return;
      // Value is already applied locally — warn so they still run the SQL.
      AppFeedback.warning(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      appBar: FomraSubPageAppBar(
        title: 'Feature Controls',
        breadcrumbs: FomraBreadcrumbs.forSettingsChild('Feature Controls'),
      ),
      backgroundColor: context.fomraPageBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const SectionHeader(
                  title: 'Feature Controls',
                  subtitle:
                      'Turn capture and approval rules on or off for the whole workspace.',
                  icon: Icons.tune_rounded,
                ),
                if (!_settings.dbReachable) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    interactive: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.warning, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Supabase table `app_settings` is missing or unreachable. '
                            'Toggles still apply on this device — run '
                            'supabase/app_settings.sql so every user gets them.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: context.fomraTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _ToggleCard(
                  icon: Icons.edit_location_alt_outlined,
                  accent: AppColors.info,
                  title: 'Manual GPS Entry',
                  subtitle:
                      'When on, Add Lead shows Live / Manual and allows typing '
                      'coordinates or tapping the map. When off, only Live GPS '
                      'capture is accepted.',
                  value: _settings.manualGpsEntry,
                  onChanged: (v) => _toggle(
                    setter: _settings.setManualGpsEntry,
                    next: v,
                    okMessage: v
                        ? 'Manual GPS entry enabled — open Add Lead to use it.'
                        : 'Manual GPS entry disabled — live GPS only on Add Lead.',
                  ),
                ),
                const SizedBox(height: 12),
                _ToggleCard(
                  icon: Icons.photo_camera_outlined,
                  accent: AppColors.purple,
                  title: 'Camera-Only Site Photos',
                  subtitle:
                      'When on, site photos on Add Lead must be taken with the camera. '
                      'When off, Add Lead offers Camera or Gallery.',
                  value: _settings.cameraOnlySitePhotos,
                  onChanged: (v) => _toggle(
                    setter: _settings.setCameraOnlySitePhotos,
                    next: v,
                    okMessage: v
                        ? 'Camera-only site photos enabled.'
                        : 'Gallery uploads allowed for site photos.',
                  ),
                ),
                const SizedBox(height: 12),
                _ToggleCard(
                  icon: Icons.account_tree_outlined,
                  accent: AppColors.success,
                  title: 'Role Hierarchy',
                  subtitle:
                      'When on, approvals follow Employee → Reporting Manager → Head → Management. '
                      'When off, only Employee and Management — approvals go straight to Management, '
                      'and Change role hides RM / Head.',
                  value: _settings.roleHierarchyEnabled,
                  onChanged: (v) => _toggle(
                    setter: _settings.setRoleHierarchyEnabled,
                    next: v,
                    okMessage: v
                        ? 'Role hierarchy enabled.'
                        : 'Role hierarchy off — approvals go to Management.',
                  ),
                ),
              ],
            ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      value ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: value ? accent : context.fomraTextTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
