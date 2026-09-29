/// Keys the backend attaches to an FCM push payload.
///
/// This is the single source of truth for the client half of the push
/// contract. It must stay in step with:
///  * `push_data` in `backend/app/services/notifications/notification_service.py`,
///    which adds `type` and `notification_id` plus the `related_*` ids;
///  * every `data={...}` literal passed to `create_and_push`, notably the
///    Gmail ones in `backend/app/services/gmail/gmail_sync_service.py`.
///
/// Kept in its own library so both the handler and the router can use it
/// without importing each other.
abstract final class NotificationPayloadKeys {
  static const type = 'type';
  static const notificationId = 'notification_id';

  /// Set from the `related_*` arguments of `create_and_push`.
  static const applicationId = 'application_id';
  static const interviewId = 'interview_id';
  static const followupId = 'followup_id';

  /// Set by the Gmail sync service. Note the short key: this is the
  /// `thread_id` it writes, not a `gmail_`-prefixed one.
  static const gmailThreadId = 'thread_id';
  static const gmailMessageId = 'gmail_message_id';
  static const suggestedStatus = 'suggested_status';

  /// Written into a locally drawn notification's `title`/`body` when the
  /// message is data-only and the app has to draw the tray notification.
  static const title = 'title';
  static const body = 'body';
}
