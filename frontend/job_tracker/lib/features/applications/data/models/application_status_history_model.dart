import '../../../../core/enums/application_status.dart';
import '../../domain/entities/application_status_history.dart';

class ApplicationStatusHistoryModel {
  ApplicationStatusHistoryModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      applicationId = json['application_id'] as String,
      previousStatus = json['previous_status'] == null
          ? null
          : ApplicationStatus.fromApi(json['previous_status'] as String),
      newStatus = ApplicationStatus.fromApi(json['new_status'] as String),
      note = json['note'] as String?,
      changedAt = DateTime.parse(json['changed_at'] as String).toLocal();

  final String id;
  final String applicationId;
  final ApplicationStatus? previousStatus;
  final ApplicationStatus newStatus;
  final String? note;
  final DateTime changedAt;

  ApplicationStatusHistory toEntity() => ApplicationStatusHistory(
    id: id,
    applicationId: applicationId,
    previousStatus: previousStatus,
    newStatus: newStatus,
    note: note,
    changedAt: changedAt,
  );
}
