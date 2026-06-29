import 'package:flutter/material.dart';
import '../../widgets/change_password_section.dart';
import '../../widgets/fomra_app_bar.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Change Password'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          ChangePasswordSection(),
        ],
      ),
    );
  }
}
