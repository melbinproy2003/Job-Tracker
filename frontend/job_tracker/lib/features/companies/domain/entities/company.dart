class Company {
  const Company({
    required this.id,
    required this.name,
    this.website,
    this.location,
    this.industry,
    this.notes,
    this.applicationCount = 0,
    this.applications = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? website;
  final String? location;
  final String? industry;
  final String? notes;
  final int applicationCount;
  final List<CompanyApplicationSummary> applications;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class CompanyApplicationSummary {
  const CompanyApplicationSummary({
    required this.id,
    required this.jobTitle,
    this.status,
  });

  final String id;
  final String jobTitle;
  final String? status;
}
