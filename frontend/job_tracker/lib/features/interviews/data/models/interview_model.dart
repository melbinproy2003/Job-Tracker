import '../../../../core/enums/interview_enums.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/interview.dart';

class InterviewModel {
  InterviewModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      applicationId = json['application_id'] as String,
      companyId = json['company_id'] as String?,
      companyName = json['company_name'] as String?,
      jobTitle = json['job_title'] as String?,
      type = InterviewType.fromApi(json['type'] as String? ?? 'OTHER'),
      title = json['title'] as String?,
      scheduledAt = requireApiDateTime(json['scheduled_at']),
      durationMinutes = json['duration_minutes'] as int?,
      meetingUrl = json['meeting_url'] as String?,
      location = json['location'] as String?,
      interviewerName = json['interviewer_name'] as String?,
      interviewerEmail = json['interviewer_email'] as String?,
      notes = json['notes'] as String?,
      status = InterviewStatus.fromApi(
        json['status'] as String? ?? 'SCHEDULED',
      ),
      createdAt = parseApiDateTime(json['created_at']),
      updatedAt = parseApiDateTime(json['updated_at']);

  final String id;
  final String applicationId;
  final String? companyId;
  final String? companyName;
  final String? jobTitle;
  final InterviewType type;
  final String? title;
  final DateTime scheduledAt;
  final int? durationMinutes;
  final String? meetingUrl;
  final String? location;
  final String? interviewerName;
  final String? interviewerEmail;
  final String? notes;
  final InterviewStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Interview toEntity() => Interview(
    id: id,
    applicationId: applicationId,
    companyId: companyId,
    companyName: companyName,
    jobTitle: jobTitle,
    type: type,
    title: title,
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    meetingUrl: meetingUrl,
    location: location,
    interviewerName: interviewerName,
    interviewerEmail: interviewerEmail,
    notes: notes,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
