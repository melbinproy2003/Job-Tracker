import '../../../../core/enums/activity_type.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/activity.dart';

class ActivityModel {
  ActivityModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      applicationId = json['application_id'] as String,
      type = ActivityType.fromApi(json['type'] as String? ?? ''),
      title = json['title'] as String? ?? '',
      description = json['description'] as String?,
      createdAt = requireApiDateTime(json['created_at']);

  final String id;
  final String applicationId;
  final ActivityType type;
  final String title;
  final String? description;
  final DateTime createdAt;

  Activity toEntity() => Activity(
    id: id,
    applicationId: applicationId,
    type: type,
    title: title,
    description: description,
    createdAt: createdAt,
  );
}
