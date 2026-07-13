import 'package:flutter/foundation.dart';
import '../models/employee_profile.dart';
import '../models/land_lead.dart';
import 'auth_service.dart';

class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._();
  AppStore._();

  final List<LandLead> leads = [];
  final List<EmployeeProfile> employees = [];

  /// Role-scoped leads: Management sees every site; an Executive only sees
  /// the sites (leads) assigned to / created by them. Every screen that
  /// lists sites, owners, brokers, tasks, activities, documents, reports,
  /// or map markers should read from this instead of [leads] directly so
  /// access control is enforced consistently across the whole app.
  List<LandLead> get visibleLeads {
    if (AuthService.instance.isManagement) return leads;
    final me =
        (AuthService.instance.currentUser?.fullName ?? '').trim().toLowerCase();
    if (me.isEmpty) return leads;
    return leads
        .where((l) => l.createdByName.trim().toLowerCase() == me)
        .toList();
  }

  void addLead(LandLead lead) {
    leads.insert(0, lead);
    notifyListeners();
  }

  void updateLeadStatus(String leadId, LeadStatus status) {
    final idx = leads.indexWhere((l) => l.leadId == leadId);
    if (idx == -1) return;
    leads[idx].status = status;
    notifyListeners();
  }

  void removeLead(String leadId) {
    leads.removeWhere((l) => l.leadId == leadId);
    notifyListeners();
  }

  void updateLeadParcel(String leadId, String surveyNumber, String subDivision) {
    final idx = leads.indexWhere((l) => l.leadId == leadId);
    if (idx == -1) return;
    leads[idx] = leads[idx]
        .copyWith(surveyNumber: surveyNumber, subDivision: subDivision);
    notifyListeners();
  }

  void updateLeadLocation(String leadId, LandLead updated) {
    final idx = leads.indexWhere((l) => l.leadId == leadId);
    if (idx == -1) return;
    leads[idx] = updated;
    notifyListeners();
  }

  void replaceLead(LandLead updated) {
    final idx = leads.indexWhere((l) => l.leadId == updated.leadId);
    if (idx == -1) {
      leads.insert(0, updated);
    } else {
      leads[idx] = updated;
    }
    notifyListeners();
  }

  void setLeads(List<LandLead> newLeads) {
    leads.clear();
    leads.addAll(newLeads);
    notifyListeners();
  }

  void setEmployees(List<EmployeeProfile> list) {
    employees.clear();
    employees.addAll(list);
    notifyListeners();
  }

  void addEmployee(EmployeeProfile profile) {
    employees.insert(0, profile);
    notifyListeners();
  }

  void removeEmployee(String id) {
    employees.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
