enum EmployeeStatus { active, inactive }

class EmployeeProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String designation;
  final String department;
  final String notes;
  final EmployeeStatus status;
  final DateTime joinedOn;

  const EmployeeProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.designation = '',
    this.department = '',
    this.notes = '',
    this.status = EmployeeStatus.active,
    required this.joinedOn,
  });

  EmployeeProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? designation,
    String? department,
    String? notes,
    EmployeeStatus? status,
  }) {
    return EmployeeProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      joinedOn: joinedOn,
    );
  }
}

extension EmployeeStatusLabel on EmployeeStatus {
  String get label => switch (this) {
        EmployeeStatus.active => 'Active',
        EmployeeStatus.inactive => 'Inactive',
      };
}
