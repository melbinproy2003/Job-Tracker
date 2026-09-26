import '../../../../core/enums/activity_type.dart';

class Activity {
  const Activity({
    required this.id,
    required this.applicationId,
    required this.type,
    required this.title,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String applicationId;
  final ActivityType type;
  final String title;
  final String? description;
  final DateTime createdAt;
}
