import '../../../../core/enums/interview_enums.dart';

class Interview {
  const Interview({
    required this.id,
    required this.applicationId,
    required this.type,
    required this.scheduledAt,
    required this.status,
    this.companyId,
    this.companyName,
    this.jobTitle,
    this.title,
    this.durationMinutes,
    this.meetingUrl,
    this.location,
    this.interviewerName,
    this.interviewerEmail,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

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

  String get displayTitle =>
      title?.trim().isNotEmpty == true ? title!.trim() : type.label;

  bool get isUpcoming =>
      status == InterviewStatus.scheduled ||
      status == InterviewStatus.rescheduled;

  bool get isPast => !isUpcoming || scheduledAt.isBefore(DateTime.now());
}
