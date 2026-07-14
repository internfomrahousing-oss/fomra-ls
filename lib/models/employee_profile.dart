enum EmployeeStatus { active, inactive }

/// Role designations in the org hierarchy (Executive is the base level).
class EmployeeDesignations {
  EmployeeDesignations._();
  static const executive = 'Executive';
  static const reportingManager = 'Reporting Manager';
  static const head = 'Head';
  static const management = 'Management';

  static const all = [executive, reportingManager, head, management];
}

class EmployeeProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String designation;
  final String department;
  final String notes;

  /// Email of the manager this person reports to (Executive → Reporting
  /// Manager → Head). Empty when unassigned.
  final String reportsTo;
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
    this.reportsTo = '',
    this.status = EmployeeStatus.active,
    required this.joinedOn,
  });

  bool get isExecutive =>
      designation.trim().isEmpty ||
      designation == EmployeeDesignations.executive;
  bool get isReportingManager =>
      designation == EmployeeDesignations.reportingManager;
  bool get isHead => designation == EmployeeDesignations.head;

  EmployeeProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? designation,
    String? department,
    String? notes,
    String? reportsTo,
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
      reportsTo: reportsTo ?? this.reportsTo,
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
