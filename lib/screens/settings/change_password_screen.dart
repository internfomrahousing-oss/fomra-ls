import 'package:flutter/material.dart';
import '../../widgets/change_password_section.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FomraSubPageAppBar(
        title: 'Reset Password',
        breadcrumbs: FomraBreadcrumbs.fromSettings('Reset Password'),
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
