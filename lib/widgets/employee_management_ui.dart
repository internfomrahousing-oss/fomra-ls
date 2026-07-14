import 'package:flutter/material.dart';

import '../models/employee_profile.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';
import 'ui/profile_avatar.dart';

/// Enterprise search bar for the employee list.
class EmployeeManagementSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const EmployeeManagementSearchBar({super.key, required this.onChanged});

  @override
  State<EmployeeManagementSearchBar> createState() =>
      _EmployeeManagementSearchBarState();
}

class _EmployeeManagementSearchBarState
    extends State<EmployeeManagementSearchBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {});
        },
        style: TextStyle(color: context.fomraTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search employees…',
          hintStyle: TextStyle(
            color: context.fomraTextSecondary,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 24,
            color: _focused ? AppColors.primary : context.fomraTextSecondary,
          ),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: context.fomraSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.fomraBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.fomraBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary add-employee action with hover lift.
class EmployeeManagementAddButton extends StatefulWidget {
  final VoidCallback onPressed;

  const EmployeeManagementAddButton({super.key, required this.onPressed});

  @override
  State<EmployeeManagementAddButton> createState() =>
      _EmployeeManagementAddButtonState();
}

class _EmployeeManagementAddButtonState
    extends State<EmployeeManagementAddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        transform: _hovered
            ? Matrix4.translationValues(0, -1, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hovered ? AppColors.coloredShadow(AppColors.primary) : null,
        ),
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Add Employee'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill status badge for employee cards.
class EmployeeStatusBadge extends StatelessWidget {
  final EmployeeStatus status;

  const EmployeeStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status == EmployeeStatus.active;
    final color = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Premium employee card — same content, improved presentation.
class EmployeeManagementCard extends StatelessWidget {
  final EmployeeProfile employee;
  final VoidCallback onRemoveAccess;
  final VoidCallback onResetPassword;
  final VoidCallback onProvisionLogin;

  const EmployeeManagementCard({
    super.key,
    required this.employee,
    required this.onRemoveAccess,
    required this.onResetPassword,
    required this.onProvisionLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileAvatar(
              email: employee.email,
              name: employee.fullName,
              radius: 25,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
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
                          employee.fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                      ),
                      EmployeeStatusBadge(status: employee.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    employee.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (employee.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      employee.phone,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                  if (employee.designation.isNotEmpty ||
                      employee.department.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (employee.designation.isNotEmpty)
                          employee.designation,
                        if (employee.department.isNotEmpty)
                          employee.department,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.fomraTextTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Manage',
              icon: Icon(Icons.more_vert_rounded, color: context.fomraTextSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 8,
              shadowColor: Colors.black26,
              onSelected: (v) {
                if (v == 'reset') onResetPassword();
                if (v == 'provision') onProvisionLogin();
                if (v == 'remove') onRemoveAccess();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.mark_email_read_outlined, size: 20),
                    title: Text('Resend invite'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'provision',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.password_outlined, size: 20),
                    title: Text('Set login to fomra@2024'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_remove_outlined,
                        color: AppColors.error, size: 20),
                    title: Text('Remove access',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
