import 'package:flutter/material.dart';

import '../../models/lead_drop_reason.dart';
import '../../services/auth_service.dart';
import '../../services/lead_drop_reason_catalog_service.dart';
import '../../services/role_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/change_password_section.dart';
import '../../widgets/portal_page_layout.dart';
import '../audit/audit_trail_screen.dart';
import '../employee_management/employee_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isManagement = AuthService.instance.isManagement;
    final canViewAudit = isManagement && RoleAccess.canViewAudit;

    return FomraAppShell(
      currentRoute: '/settings',
      appBar: const FomraAppBar(
        moduleName: 'Management Settings',
        showUniversalSearch: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            isManagement ? 'Management Settings' : 'Settings',
            style: TextStyle(
              fontSize: FomraLayout.responsiveClamp(
                context,
                min: 20,
                max: 22,
              ),
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isManagement
                ? 'Workspace controls, approval catalogs, and administrative tools.'
                : 'Manage account options.',
            style: TextStyle(
              fontSize: 13,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                label: 'Reset Password',
                accent: AppColors.purple,
                onTap: () => showResetPasswordDialog(context),
              ),
              if (isManagement)
                _SettingsTile(
                  icon: Icons.groups_outlined,
                  label: 'User Management',
                  accent: AppColors.secondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _UserManagementPage(),
                    ),
                  ),
                ),
              if (canViewAudit)
                _SettingsTile(
                  icon: Icons.history_edu_outlined,
                  label: 'Audit Trail',
                  accent: AppColors.info,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuditTrailScreen(),
                    ),
                  ),
                ),
              if (isManagement)
                _SettingsTile(
                  icon: Icons.cancel_schedule_send_outlined,
                  label: 'Dropped Reasons',
                  accent: AppColors.error,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _DroppedReasonsPage(),
                    ),
                  ),
                ),
              if (isManagement)
                _SettingsTile(
                  icon: Icons.file_upload_outlined,
                  label: 'Bulk Lead Import',
                  accent: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _BulkLeadImportPage(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.accent.withValues(alpha: _hovered ? 0.45 : 0.25);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 420;
    final tileWidth = compact
        ? ((screenWidth - 44) / 2).clamp(118.0, 148.0)
        : 148.0;
    final tileHeight = compact ? 84.0 : 118.0;
    final tilePadding = compact ? 8.0 : 14.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: tileWidth,
          height: tileHeight,
          padding: EdgeInsets.all(tilePadding),
          decoration: BoxDecoration(
            color: context.fomraSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: _hovered ? 1.5 : 1),
            boxShadow: _hovered ? context.fomraCardShadow : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 32 : 38,
                height: compact ? 32 : 38,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.accent,
                  size: compact ? 17 : 20,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 13,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: compact ? 12 : 14,
                    color: context.fomraTextSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserManagementPage extends StatelessWidget {
  const _UserManagementPage();

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      backgroundColor: context.fomraPageBg,
      appBar: FomraSubPageAppBar(
        title: 'User Management',
        breadcrumbs: FomraBreadcrumbs.fromSettings('User Management'),
      ),
      body: const EmployeeManagementScreen(isTab: true),
    );
  }
}

class _DroppedReasonsPage extends StatefulWidget {
  const _DroppedReasonsPage();

  @override
  State<_DroppedReasonsPage> createState() => _DroppedReasonsPageState();
}

class _DroppedReasonsPageState extends State<_DroppedReasonsPage> {
  LeadDropReasonCatalogService get _catalog =>
      LeadDropReasonCatalogService.instance;

  @override
  void initState() {
    super.initState();
    _catalog.addListener(_rebuild);
  }

  @override
  void dispose() {
    _catalog.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _editReason({LeadDropReason? reason}) async {
    final controller = TextEditingController(text: reason?.label ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(reason == null ? 'Add drop reason' : 'Edit drop reason'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Reason label',
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == null || saved.trim().isEmpty) return;
    if (reason == null) {
      await _catalog.addReason(saved);
    } else {
      await _catalog.updateReason(reason.id, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = _catalog.current;
    return FomraAppShell(
      currentRoute: '/settings',
      appBar: FomraAppBar(
        moduleName: 'Dropped Reasons',
        breadcrumbs: FomraBreadcrumbs.module('Dropped Reasons'),
      ),
      backgroundColor: context.fomraPageBg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SectionHeader(
            title: 'Dropped Reasons',
            subtitle: 'Add, edit, delete, and reorder the drop catalog used everywhere.',
            icon: Icons.cancel_schedule_send_outlined,
            trailing: TextButton.icon(
              onPressed: () => _editReason(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add reason'),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            interactive: false,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reasons.length,
              onReorder: (oldIndex, newIndex) =>
                  _catalog.reorder(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final reason = reasons[index];
                return Container(
                  key: ValueKey(reason.id),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.fomraSurfaceVar.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.fomraBorder),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.drag_indicator_rounded,
                        color: context.fomraTextSecondary),
                    title: Text(
                      reason.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      reason.id,
                      style: TextStyle(color: context.fomraTextSecondary),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _editReason(reason: reason);
                        } else if (value == 'delete') {
                          await _catalog.deleteReason(reason.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkLeadImportPage extends StatelessWidget {
  const _BulkLeadImportPage();

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      appBar: FomraAppBar(
        moduleName: 'Bulk Lead Import',
        breadcrumbs: FomraBreadcrumbs.module('Bulk Lead Import'),
      ),
      backgroundColor: context.fomraPageBg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Bulk Lead Import',
                  subtitle: 'Navigation entry and UI placeholder for the future import pipeline.',
                  icon: Icons.file_upload_outlined,
                ),
                const SizedBox(height: 12),
                Text(
                  'This screen is reserved for the upcoming import workflow. The backend import pipeline will be connected later without changing this entry point.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.fomraTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Import leads (coming soon)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
