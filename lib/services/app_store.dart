import 'package:flutter/foundation.dart';
import '../models/land_lead.dart';
import '../models/site_verification.dart';

class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._();
  AppStore._();

  final List<LandLead> leads = [];
  final List<SiteVerification> siteVerifications = [];

  SiteVerification _svFromLead(LandLead lead) => SiteVerification(
        id: 'SV-${lead.leadId}',
        leadReference: lead.leadId,
        geoCoordinates: lead.gpsCoordinates,
        geoAddress: [lead.location, lead.village, lead.taluk, lead.district]
            .where((s) => s.isNotEmpty)
            .join(', '),
        pincode: lead.pincode,
        photographs: [],
        roadAccess: lead.accessDetails,
        nearbyLandmarks: '',
        siteObservations: '',
        capturedOn: lead.addedOn,
        // siteVisit or beyond means the field visit is done — treat as completed.
        status: lead.status.index >= LeadStatus.siteVisit.index
            ? VerificationStatus.completed
            : VerificationStatus.scheduled,
      );

  void addLead(LandLead lead) {
    leads.insert(0, lead);
    siteVerifications.insert(0, _svFromLead(lead));
    notifyListeners();
  }

  void addSiteVerification(SiteVerification sv) {
    siteVerifications.insert(0, sv);
    notifyListeners();
  }

  void completePendingVerification(String pendingId, SiteVerification completed) {
    final idx = siteVerifications.indexWhere((sv) => sv.id == pendingId);
    if (idx != -1) {
      siteVerifications[idx] = completed;
    } else {
      siteVerifications.insert(0, completed);
    }
    notifyListeners();
  }

  void updateLeadStatus(String leadId, LeadStatus status) {
    final idx = leads.indexWhere((l) => l.leadId == leadId);
    if (idx == -1) return;
    leads[idx].status = status;
    notifyListeners();
  }

  void updateSiteVerificationStatus(String id, VerificationStatus status) {
    final idx = siteVerifications.indexWhere((sv) => sv.id == id);
    if (idx == -1) return;
    siteVerifications[idx].status = status;
    notifyListeners();
  }

  void removeLead(String leadId) {
    leads.removeWhere((l) => l.leadId == leadId);
    siteVerifications.removeWhere((sv) => sv.leadReference == leadId);
    notifyListeners();
  }

  void setLeads(List<LandLead> newLeads) {
    leads.clear();
    leads.addAll(newLeads);
    siteVerifications.clear();
    for (final lead in newLeads) {
      siteVerifications.add(_svFromLead(lead));
    }
    notifyListeners();
  }

  int get pendingSiteVerifications =>
      siteVerifications.where((sv) => sv.status == VerificationStatus.scheduled).length;
}
