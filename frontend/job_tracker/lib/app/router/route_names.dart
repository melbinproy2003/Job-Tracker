/// Central route path/name constants.
abstract final class RouteNames {
  static const root = '/';
  static const auth = '/auth';
  static const login = '/auth/login';
  static const home = '/home';
  static const applications = '/applications';
  static const addApplication = '/applications/add';
  static const applicationDetail = '/applications/:id';
  static const editApplication = '/applications/:id/edit';
  static const companies = '/companies';
  static const addCompany = '/companies/add';
  static const companyDetail = '/companies/:id';
  static const editCompany = '/companies/:id/edit';
  static const interviews = '/interviews';
  static const addInterview = '/interviews/add';
  static const interviewDetail = '/interviews/:id';
  static const editInterview = '/interviews/:id/edit';
  static const followups = '/followups';
  static const addFollowup = '/followups/add';
  static const editFollowup = '/followups/:id/edit';
  static const followupDetail = '/followups/:id';
  static const upcoming = '/upcoming';

  // Phase 4 — notifications
  static const notifications = '/notifications';
  static const notificationPreferences = '/notifications/preferences';

  // Phase 4/5 — settings
  static const settings = '/settings';
  static const settingsEmail = '/settings/email';

  // Phase 5 — Gmail
  static const gmail = '/gmail';
  static const gmailThreadDetail = '/gmail/threads/:id';
  static const gmailMessageDetail = '/gmail/messages/:id';
  static const gmailAddApplication = '/gmail/threads/:id/link';

  static String applicationDetailPath(String id) => '/applications/$id';
  static String editApplicationPath(String id) => '/applications/$id/edit';
  static String companyDetailPath(String id) => '/companies/$id';
  static String editCompanyPath(String id) => '/companies/$id/edit';
  static String interviewDetailPath(String id) => '/interviews/$id';
  static String editInterviewPath(String id) => '/interviews/$id/edit';
  static String followupDetailPath(String id) => '/followups/$id';
  static String editFollowupPath(String id) => '/followups/$id/edit';
  static String gmailThreadDetailPath(String id) => '/gmail/threads/$id';
  static String gmailMessageDetailPath(String id) => '/gmail/messages/$id';
  static String gmailLinkPath(String threadId) =>
      '/gmail/threads/$threadId/link';
  static String addInterviewPath({String? applicationId}) =>
      applicationId == null
      ? addInterview
      : '$addInterview?applicationId=$applicationId';
  static String addFollowupPath({String? applicationId}) =>
      applicationId == null
      ? addFollowup
      : '$addFollowup?applicationId=$applicationId';
}
