/// Wire model for the user's notification preferences.
class NotificationPreferencesModel {
  const NotificationPreferencesModel({
    this.interviewReminders = true,
    this.followupReminders = true,
    this.overdueFollowups = true,
    this.gmailNotifications = true,
    this.applicationSuggestions = true,
  });

  final bool interviewReminders;
  final bool followupReminders;
  final bool overdueFollowups;
  final bool gmailNotifications;
  final bool applicationSuggestions;

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      interviewReminders: json['interview_reminders'] as bool? ?? true,
      followupReminders: json['followup_reminders'] as bool? ?? true,
      overdueFollowups: json['overdue_followups'] as bool? ?? true,
      gmailNotifications: json['gmail_notifications'] as bool? ?? true,
      applicationSuggestions: json['application_suggestions'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'interview_reminders': interviewReminders,
    'followup_reminders': followupReminders,
    'overdue_followups': overdueFollowups,
    'gmail_notifications': gmailNotifications,
    'application_suggestions': applicationSuggestions,
  };

  NotificationPreferencesModel copyWith({
    bool? interviewReminders,
    bool? followupReminders,
    bool? overdueFollowups,
    bool? gmailNotifications,
    bool? applicationSuggestions,
  }) {
    return NotificationPreferencesModel(
      interviewReminders: interviewReminders ?? this.interviewReminders,
      followupReminders: followupReminders ?? this.followupReminders,
      overdueFollowups: overdueFollowups ?? this.overdueFollowups,
      gmailNotifications: gmailNotifications ?? this.gmailNotifications,
      applicationSuggestions:
          applicationSuggestions ?? this.applicationSuggestions,
    );
  }
}
