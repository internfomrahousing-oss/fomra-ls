import '../models/employee_profile.dart';
import '../models/land_lead.dart';
import '../utils/contact_directory.dart';
import '../screens/home/contact_directory_screen.dart';
import '../screens/task_management/task_management_screen.dart';
import '../services/app_store.dart';
import '../services/auth_service.dart';

enum UniversalSearchKind { lead, employee, task, page, contact }

class UniversalSearchHit {
  final UniversalSearchKind kind;
  final String title;
  final String subtitle;
  final LandLead? lead;
  final EmployeeProfile? employee;
  final Task? task;
  final String? route;
  final ContactDirectoryKind? contactKind;

  const UniversalSearchHit({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.lead,
    this.employee,
    this.task,
    this.route,
    this.contactKind,
  });
}

class _NavEntry {
  final String label;
  final String? route;
  final ContactDirectoryKind? contactKind;
  final List<String> keywords;

  const _NavEntry({
    required this.label,
    this.route,
    this.contactKind,
    this.keywords = const [],
  });
}

abstract final class UniversalSearchService {
  static const _maxResults = 14;

  static bool _contains(String? value, String q) =>
      value != null && value.trim().isNotEmpty && value.toLowerCase().contains(q);

  static bool _leadMatches(LandLead lead, String q) {
    return _contains(lead.leadId, q) ||
        _contains(lead.ownerName, q) ||
        _contains(lead.contactDetails, q) ||
        _contains(lead.brokerName, q) ||
        _contains(lead.brokerContact, q) ||
        _contains(lead.location, q) ||
        _contains(lead.village, q) ||
        _contains(lead.taluk, q) ||
        _contains(lead.district, q) ||
        _contains(lead.pincode, q) ||
        _contains(lead.surveyNumber, q) ||
        _contains(lead.subDivision, q) ||
        _contains(lead.notes, q) ||
        _contains(lead.createdByName, q) ||
        _contains(lead.landType.name, q) ||
        _contains(lead.status.name, q) ||
        _contains(lead.inputSource.name, q);
  }

  static bool _employeeMatches(EmployeeProfile employee, String q) {
    return _contains(employee.fullName, q) ||
        _contains(employee.email, q) ||
        _contains(employee.phone, q) ||
        _contains(employee.designation, q) ||
        _contains(employee.department, q) ||
        _contains(employee.notes, q);
  }

  static bool _taskMatches(Task task, String q) {
    return _contains(task.id, q) ||
        _contains(task.title, q) ||
        _contains(task.description, q) ||
        _contains(task.notes, q) ||
        _contains(task.module, q) ||
        task.assignedTo.any((name) => _contains(name, q));
  }

  static List<_NavEntry> _navEntries(bool isManagement) {
    final entries = <_NavEntry>[
      const _NavEntry(label: 'Home', route: '/home', keywords: ['dashboard', 'portal']),
      const _NavEntry(
        label: 'Land Workspace',
        route: '/land-lead',
        keywords: ['leads', 'workspace', 'land', 'projects'],
      ),
      const _NavEntry(
        label: 'Owner details',
        contactKind: ContactDirectoryKind.owner,
        keywords: ['owners', 'contacts', 'directory'],
      ),
      const _NavEntry(
        label: 'Broker details',
        contactKind: ContactDirectoryKind.broker,
        keywords: ['brokers', 'agents', 'contacts'],
      ),
      const _NavEntry(
        label: 'Change password',
        route: '/change-password',
        keywords: ['security', 'account', 'settings'],
      ),
      const _NavEntry(
        label: 'Settings',
        route: '/settings',
        keywords: ['preferences', 'account', 'users'],
      ),
    ];
    if (isManagement) {
      entries.addAll(const [
        _NavEntry(
          label: 'Dashboard',
          route: '/dashboard',
          keywords: ['analytics', 'stats', 'kpi'],
        ),
        _NavEntry(
          label: 'Reports',
          route: '/reports',
          keywords: ['export', 'summary'],
        ),
        _NavEntry(
          label: 'User management',
          route: '/employee-management',
          keywords: ['employees', 'team', 'staff'],
        ),
      ]);
    }
    return entries;
  }

  static List<UniversalSearchHit> search(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return [];

    final hits = <UniversalSearchHit>[];
    final isManagement = AuthService.instance.isManagement;
    final me = (AuthService.instance.currentUser?.fullName ?? '').trim().toLowerCase();

    for (final lead in AppStore.instance.leads) {
      if (!isManagement &&
          me.isNotEmpty &&
          lead.createdByName.trim().toLowerCase() != me) {
        continue;
      }
      if (!_leadMatches(lead, q)) continue;
      final location = [
        if (lead.village.isNotEmpty) lead.village,
        if (lead.district.isNotEmpty) lead.district,
      ].join(', ');
      hits.add(UniversalSearchHit(
        kind: UniversalSearchKind.lead,
        title: lead.ownerName.trim().isNotEmpty
            ? lead.ownerName.trim()
            : 'Lead #${lead.leadId}',
        subtitle: [
          'Lead #${lead.leadId}',
          if (location.isNotEmpty) location,
          lead.status.name,
        ].join(' · '),
        lead: lead,
      ));
      if (hits.length >= _maxResults) return hits;
    }

    for (final task in sharedTasks) {
      if (!_taskMatches(task, q)) continue;
      hits.add(UniversalSearchHit(
        kind: UniversalSearchKind.task,
        title: task.title,
        subtitle: [
          task.id,
          if (task.module.isNotEmpty) 'Lead ${task.module}',
          task.status.name,
        ].join(' · '),
        task: task,
      ));
      if (hits.length >= _maxResults) return hits;
    }

    if (isManagement) {
      for (final employee in AppStore.instance.employees) {
        if (!_employeeMatches(employee, q)) continue;
        hits.add(UniversalSearchHit(
          kind: UniversalSearchKind.employee,
          title: employee.fullName,
          subtitle: [
            if (employee.designation.isNotEmpty) employee.designation,
            employee.email,
          ].join(' · '),
          employee: employee,
        ));
        if (hits.length >= _maxResults) return hits;
      }
    }

    for (final entry in _navEntries(isManagement)) {
      final labels = [entry.label, ...entry.keywords];
      if (!labels.any((label) => label.toLowerCase().contains(q))) continue;
      hits.add(UniversalSearchHit(
        kind: entry.contactKind != null
            ? UniversalSearchKind.contact
            : UniversalSearchKind.page,
        title: entry.label,
        subtitle: entry.route != null ? 'Open page' : 'Open directory',
        route: entry.route,
        contactKind: entry.contactKind,
      ));
      if (hits.length >= _maxResults) return hits;
    }

    return hits;
  }
}
