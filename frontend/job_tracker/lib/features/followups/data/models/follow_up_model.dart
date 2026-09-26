import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/follow_up.dart';

class FollowUpModel {
  FollowUpModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      applicationId = json['application_id'] as String,
      companyId = json['company_id'] as String?,
      companyName = json['company_name'] as String?,
      jobTitle = json['job_title'] as String?,
      title = json['title'] as String? ?? '',
      scheduledAt = requireApiDateTime(json['scheduled_at']),
      completed = json['completed'] as bool? ?? false,
      completedAt = parseApiDateTime(json['completed_at']),
      notes = json['notes'] as String?,
      isOverdue = json['is_overdue'] as bool? ?? false,
      createdAt = parseApiDateTime(json['created_at']),
      updatedAt = parseApiDateTime(json['updated_at']);

  final String id;
  final String applicationId;
  final String? companyId;
  final String? companyName;
  final String? jobTitle;
  final String title;
  final DateTime scheduledAt;
  final bool completed;
  final DateTime? completedAt;
  final String? notes;
  final bool isOverdue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FollowUp toEntity() => FollowUp(
    id: id,
    applicationId: applicationId,
    companyId: companyId,
    companyName: companyName,
    jobTitle: jobTitle,
    title: title,
    scheduledAt: scheduledAt,
    completed: completed,
    completedAt: completedAt,
    notes: notes,
    isOverdue: isOverdue,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
