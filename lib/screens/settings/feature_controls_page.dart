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
    await _settings.ensureLoaded();
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
      AppFeedback.error(context, 'Could not save setting: $e');
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
                const SizedBox(height: 12),
                _ToggleCard(
                  icon: Icons.edit_location_alt_outlined,
                  accent: AppColors.info,
                  title: 'Manual GPS Entry',
                  subtitle:
                      'When on, Add Lead allows typing coordinates or tapping the map. '
                      'When off, only live GPS capture is accepted.',
                  value: _settings.manualGpsEntry,
                  onChanged: (v) => _toggle(
                    setter: _settings.setManualGpsEntry,
                    next: v,
                    okMessage: v
                        ? 'Manual GPS entry enabled.'
                        : 'Manual GPS entry disabled — live GPS only.',
                  ),
                ),
                const SizedBox(height: 12),
                _ToggleCard(
                  icon: Icons.photo_camera_outlined,
                  accent: AppColors.purple,
                  title: 'Camera-Only Site Photos',
                  subtitle:
                      'When on, site photos on Add Lead must be taken with the camera. '
                      'When off, camera or gallery is allowed.',
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
                      'When off, the org is Employee and Management only — employee approvals go straight to Management.',
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary,
                  ),
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
