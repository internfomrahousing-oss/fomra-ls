import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../theme/app_theme.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await EmployeeService.create(
        fullName: _nameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        designation: _designationCtrl.text,
        department: _departmentCtrl.text,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, profile);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile created for ${profile.fullName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Employee'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Creates a login profile. Employee signs in with their email and password ${AuthService.portalPassword}.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _field(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline,
                required: true,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _emailCtrl,
                label: 'Email (login ID)',
                icon: Icons.email_outlined,
                keyboard: TextInputType.emailAddress,
                required: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _phoneCtrl,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _designationCtrl,
                label: 'Designation',
                icon: Icons.work_outline,
                hint: 'e.g. Field Executive',
              ),
              const SizedBox(height: 14),
              _field(
                controller: _departmentCtrl,
                label: 'Department',
                icon: Icons.apartment_outlined,
                hint: 'e.g. Land Acquisition',
              ),
              const SizedBox(height: 14),
              _field(
                controller: _notesCtrl,
                label: 'Notes',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Employee Profile',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboard,
    bool required = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
