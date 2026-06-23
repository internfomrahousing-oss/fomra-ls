class Lead {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? source;
  final String status;
  final String? propertyType;
  final double? budgetMin;
  final double? budgetMax;
  final String? locationPreference;
  final String? notes;
  final String? assignedTo;
  final String? assignedToName;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const List<String> statuses = [
    'new', 'contacted', 'site_visit_scheduled', 'negotiating', 'converted', 'lost'
  ];
  static const List<String> sources = [
    'walk-in', 'referral', 'online', 'cold-call', 'site-visit'
  ];
  static const List<String> propertyTypes = [
    'Apartment', 'Villa', 'Plot', 'Commercial', 'Mixed'
  ];

  const Lead({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.source,
    required this.status,
    this.propertyType,
    this.budgetMin,
    this.budgetMax,
    this.locationPreference,
    this.notes,
    this.assignedTo,
    this.assignedToName,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        source: j['source'] as String?,
        status: j['status'] as String? ?? 'new',
        propertyType: j['property_type'] as String?,
        budgetMin: (j['budget_min'] as num?)?.toDouble(),
        budgetMax: (j['budget_max'] as num?)?.toDouble(),
        locationPreference: j['location_preference'] as String?,
        notes: j['notes'] as String?,
        assignedTo: j['assigned_to'] as String?,
        assignedToName: j['assigned_to_name'] as String?,
        createdBy: j['created_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'source': source,
        'status': status,
        'property_type': propertyType,
        'budget_min': budgetMin,
        'budget_max': budgetMax,
        'location_preference': locationPreference,
        'notes': notes,
        'assigned_to': assignedTo,
      };
}
