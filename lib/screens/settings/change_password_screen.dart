import 'package:flutter/material.dart';
import '../../widgets/change_password_section.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      appBar: FomraSubPageAppBar(
        title: 'Reset Password',
        breadcrumbs: FomraBreadcrumbs.forSettingsChild('Reset Password'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          ChangePasswordSection(),
        ],
      ),
    );
  }
}
