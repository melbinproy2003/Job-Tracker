import '../../../../core/enums/application_status.dart';
import '../../domain/entities/application.dart';

DateTime? _parseDt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString())?.toLocal();
}

class ApplicationModel {
  ApplicationModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      companyId = (json['company'] as Map?)?['id'] as String? ?? '',
      companyName = (json['company'] as Map?)?['name'] as String? ?? '',
      jobTitle = json['job_title'] as String? ?? '',
      jobUrl = json['job_url'] as String?,
      location = json['location'] as String?,
      source = json['source'] as String?,
      employmentType = json['employment_type'] as String?,
      status = ApplicationStatus.fromApi(
        json['status'] as String? ?? 'APPLIED',
      ),
      appliedAt = _parseDt(json['applied_at']),
      lastUpdatedAt = _parseDt(json['last_updated_at']),
      recruiterName = json['recruiter_name'] as String?,
      recruiterEmail = json['recruiter_email'] as String?,
      salaryMin = (json['salary_min'] as num?)?.toDouble(),
      salaryMax = (json['salary_max'] as num?)?.toDouble(),
      currency = json['currency'] as String?,
      notes = json['notes'] as String?,
      createdAt = _parseDt(json['created_at']),
      updatedAt = _parseDt(json['updated_at']);

  final String id;
  final String companyId;
  final String companyName;
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

  Application toEntity() => Application(
    id: id,
    company: CompanyRef(id: companyId, name: companyName),
    jobTitle: jobTitle,
    jobUrl: jobUrl,
    location: location,
    source: source,
    employmentType: employmentType,
    status: status,
    appliedAt: appliedAt,
    lastUpdatedAt: lastUpdatedAt,
    recruiterName: recruiterName,
    recruiterEmail: recruiterEmail,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    currency: currency,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
