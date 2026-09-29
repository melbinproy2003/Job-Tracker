import '../../../../core/enums/application_status.dart';

class ApplicationStatusHistory {
  const ApplicationStatusHistory({
    required this.id,
    required this.applicationId,
    required this.newStatus,
    required this.changedAt,
    this.previousStatus,
    this.note,
  });

  final String id;
  final String applicationId;
  final ApplicationStatus? previousStatus;
  final ApplicationStatus newStatus;
  final DateTime changedAt;
  final String? note;
}
