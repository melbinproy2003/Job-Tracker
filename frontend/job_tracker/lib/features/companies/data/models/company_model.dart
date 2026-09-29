import '../../domain/entities/company.dart';

class CompanyModel {
  CompanyModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String? ?? '',
      website = json['website'] as String?,
      location = json['location'] as String?,
      industry = json['industry'] as String?,
      notes = json['notes'] as String?,
      applicationCount = json['application_count'] as int? ?? 0,
      applications = ((json['applications'] as List?) ?? [])
          .map(
            (e) => CompanyApplicationSummary(
              id: e['id'] as String,
              jobTitle: e['job_title'] as String? ?? '',
              status: e['status'] as String?,
            ),
          )
          .toList(),
      createdAt = json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString())?.toLocal(),
      updatedAt = json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString())?.toLocal();

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

  Company toEntity() => Company(
    id: id,
    name: name,
    website: website,
    location: location,
    industry: industry,
    notes: notes,
    applicationCount: applicationCount,
    applications: applications,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
