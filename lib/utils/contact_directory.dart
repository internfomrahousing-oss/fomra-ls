import '../models/land_lead.dart';

enum ContactDirectoryKind { owner, broker }

class ContactDirectoryEntry {
  final String name;
  final String contact;
  final List<LandLead> leads;

  const ContactDirectoryEntry({
    required this.name,
    required this.contact,
    required this.leads,
  });
}

List<ContactDirectoryEntry> buildContactDirectoryEntries(
  List<LandLead> leads,
  ContactDirectoryKind kind,
) {
  final map = <String, ContactDirectoryEntry>{};

  for (final lead in leads) {
    final name = kind == ContactDirectoryKind.owner
        ? lead.ownerName.trim()
        : lead.brokerName.trim();
    if (name.isEmpty) continue;

    final contact = kind == ContactDirectoryKind.owner
        ? lead.contactDetails.trim()
        : lead.brokerContact.trim();
    final phoneKey = contact.replaceAll(RegExp(r'[^\d+]'), '');
    final key = '${name.toLowerCase()}|$phoneKey';

    final existing = map[key];
    if (existing == null) {
      map[key] = ContactDirectoryEntry(
        name: name,
        contact: contact,
        leads: [lead],
      );
    } else {
      map[key] = ContactDirectoryEntry(
        name: existing.name,
        contact: existing.contact.isNotEmpty ? existing.contact : contact,
        leads: [...existing.leads, lead],
      );
    }
  }

  final entries = map.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return entries;
}
