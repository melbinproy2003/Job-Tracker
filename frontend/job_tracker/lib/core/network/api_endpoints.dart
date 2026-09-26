/// REST endpoint paths relative to API base URL.
abstract final class ApiEndpoints {
  static const authMe = '/api/v1/auth/me';
  static const applications = '/api/v1/applications';
  static String application(String id) => '/api/v1/applications/$id';
  static String applicationStatus(String id) =>
      '/api/v1/applications/$id/status';
  static String applicationHistory(String id) =>
      '/api/v1/applications/$id/history';
  static String applicationInterviews(String id) =>
      '/api/v1/applications/$id/interviews';
  static String applicationActivities(String id) =>
      '/api/v1/applications/$id/activities';
  static const companies = '/api/v1/companies';
  static String company(String id) => '/api/v1/companies/$id';
  static const interviews = '/api/v1/interviews';
  static String interview(String id) => '/api/v1/interviews/$id';
  static const followups = '/api/v1/followups';
  static String followup(String id) => '/api/v1/followups/$id';
  static String followupComplete(String id) => '/api/v1/followups/$id/complete';
  static const dashboard = '/api/v1/dashboard';

  static const notificationDevices = '/api/v1/notifications/devices';
  static String notificationDevice(String id) =>
      '/api/v1/notifications/devices/$id';
  static const notifications = '/api/v1/notifications';
  static const notificationsUnreadCount = '/api/v1/notifications/unread-count';
  static String notificationRead(String id) => '/api/v1/notifications/$id/read';
  static const notificationsReadAll = '/api/v1/notifications/read-all';
  static String notification(String id) => '/api/v1/notifications/$id';
  static const notificationPreferences = '/api/v1/notifications/preferences';

  static const gmailAccounts = '/api/v1/gmail/accounts';
  static const gmailConnect = '/api/v1/gmail/connect';
  static const gmailSync = '/api/v1/gmail/sync';
  static const gmailThreads = '/api/v1/gmail/threads';
  static String gmailThread(String id) => '/api/v1/gmail/threads/$id';
  static String gmailMessage(String id) => '/api/v1/gmail/messages/$id';
  static String gmailMatchConfirm(String threadId) =>
      '/api/v1/gmail/matches/$threadId/confirm';
  static String gmailMatchIgnore(String threadId) =>
      '/api/v1/gmail/matches/$threadId/ignore';
  static String gmailAccount(String id) => '/api/v1/gmail/accounts/$id';
}
