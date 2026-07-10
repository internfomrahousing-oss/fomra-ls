import 'land_lead.dart';

enum LeadListFilter {
  totalLeads,
  activeLeads,
  brokerLeads,
  notes,
  calls,
  siteVisit,
  managementSiteVisit,
  meeting,
  legal,
  signed,
}

bool leadHasSiteVisitProgress(LandLead lead) =>
    lead.status == LeadStatus.prospectMeetingCompleted ||
    lead.status == LeadStatus.negotiation ||
    lead.status == LeadStatus.legal ||
    lead.status == LeadStatus.signed;

extension LeadListFilterX on LeadListFilter {
  String get title => switch (this) {
        LeadListFilter.totalLeads => 'Total leads',
        LeadListFilter.activeLeads => 'Active leads',
        LeadListFilter.brokerLeads => 'Broker leads',
        LeadListFilter.notes => 'Notes',
        LeadListFilter.calls => 'Calls',
        LeadListFilter.siteVisit => 'Site visit',
        LeadListFilter.managementSiteVisit => 'Management site visit',
        LeadListFilter.meeting => 'Meeting',
        LeadListFilter.legal => 'Legal',
        LeadListFilter.signed => 'Signed',
      };

  String get subtitle => switch (this) {
        LeadListFilter.totalLeads => 'Every lead in the workspace',
        LeadListFilter.activeLeads => 'Leads still in the pipeline',
        LeadListFilter.brokerLeads => 'Leads sourced through brokers',
        LeadListFilter.notes => 'Leads with saved notes',
        LeadListFilter.calls => 'Leads with contact details',
        LeadListFilter.siteVisit => 'Leads with site visit progress',
        LeadListFilter.managementSiteVisit =>
          'Management-assigned leads with site visit progress',
        LeadListFilter.meeting => 'Prospect meeting stage',
        LeadListFilter.legal => 'Leads in legal review',
        LeadListFilter.signed => 'Signed leads',
      };

  bool matches(LandLead lead) => switch (this) {
        LeadListFilter.totalLeads => true,
        LeadListFilter.activeLeads => lead.status.isActive,
        LeadListFilter.brokerLeads => lead.inputSource == InputSource.broker,
        LeadListFilter.notes => lead.notes.trim().isNotEmpty,
        LeadListFilter.calls => lead.contactDetails.trim().isNotEmpty,
        LeadListFilter.siteVisit => leadHasSiteVisitProgress(lead),
        LeadListFilter.managementSiteVisit =>
          lead.createdByRole == 'management' &&
              leadHasSiteVisitProgress(lead),
        LeadListFilter.meeting => lead.status.isProspect,
        LeadListFilter.legal => lead.status == LeadStatus.legal,
        LeadListFilter.signed => lead.status == LeadStatus.signed,
      };

  static LeadListFilter? forActionLabel(String label) => switch (label) {
        'Notes' => LeadListFilter.notes,
        'Calls' => LeadListFilter.calls,
        'Site visit' => LeadListFilter.siteVisit,
        'Management site visit' => LeadListFilter.managementSiteVisit,
        'Meeting' => LeadListFilter.meeting,
        'Legal' => LeadListFilter.legal,
        'Signed' => LeadListFilter.signed,
        _ => null,
      };
}

List<LandLead> filterLeads(List<LandLead> leads, LeadListFilter filter) =>
    leads.where(filter.matches).toList();
