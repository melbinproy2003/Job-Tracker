class FollowUp {
  const FollowUp({
    required this.id,
    required this.applicationId,
    required this.title,
    required this.scheduledAt,
    required this.completed,
    required this.isOverdue,
    this.companyId,
    this.companyName,
    this.jobTitle,
    this.completedAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

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
}
