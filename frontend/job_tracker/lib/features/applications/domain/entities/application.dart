import '../../../../core/enums/application_status.dart';

class CompanyRef {
  const CompanyRef({required this.id, required this.name});
  final String id;
  final String name;
}

class Application {
  const Application({
    required this.id,
    required this.company,
    required this.jobTitle,
    required this.status,
    this.jobUrl,
    this.location,
    this.source,
    this.employmentType,
    this.appliedAt,
    this.lastUpdatedAt,
    this.recruiterName,
    this.recruiterEmail,
    this.salaryMin,
    this.salaryMax,
    this.currency,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final CompanyRef company;
  final String jobTitle;
  final String? jobUrl;
  final String? location;
  final String? source;
  final String? employmentType;
  final ApplicationStatus status;
  final DateTime? appliedAt;
  final DateTime? lastUpdatedAt;
  final String? recruiterName;
  final String? recruiterEmail;
  final double? salaryMin;
  final double? salaryMax;
  final String? currency;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class PaginatedApplications {
  const PaginatedApplications({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
  });

  final List<Application> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;
}
