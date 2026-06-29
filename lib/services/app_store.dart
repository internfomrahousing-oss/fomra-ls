import 'package:flutter/foundation.dart';
import '../models/employee_profile.dart';
import '../models/land_lead.dart';

class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._();
  AppStore._();

  final List<LandLead> leads = [];
  final List<EmployeeProfile> employees = [];

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
