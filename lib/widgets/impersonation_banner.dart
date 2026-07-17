import 'package:flutter/material.dart';

import '../models/employee_profile.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/access_as_user_page.dart';
import '../services/access_as_user.dart';
import '../services/auth_service.dart';
import '../services/notification_hub.dart';
import '../services/view_scope.dart';
import '../theme/app_theme.dart';

/// Persistent bar shown on every page while management is accessing the app as
/// another user. Listens to [AuthService.impersonation] so it appears/vanishes
/// as the session starts/ends.
class ImpersonationBanner extends StatelessWidget {
  const ImpersonationBanner({super.key});

  Future<void> _returnToManagement(BuildContext context) async {
    final navigator = Navigator.of(context);
    await AccessAsUser.stop();
    // The accessed user's scoped state must not bleed into the restored
    // management session.
    NotificationHub.instance.stop();
    ViewScope.instance.reset();
    // Land back where management launched it — the Access as User page — with
    // Home as the base so Back still works. The whole app rebuilds as
    // management (the banner is gone now).
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
    navigator.push(
      MaterialPageRoute(builder: (_) => const AccessAsUserPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EmployeeProfile?>(
      valueListenable: AuthService.instance.impersonation,
      builder: (context, user, _) {
        if (user == null) return const SizedBox.shrink();
        return Material(
          color: AppColors.warning,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are accessing the application as ${user.fullName}.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _returnToManagement(context),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Return to Management'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.warning,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
