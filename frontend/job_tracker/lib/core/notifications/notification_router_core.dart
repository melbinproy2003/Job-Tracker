import '../../app/router/route_names.dart';
import 'notification_payload.dart';

/// Where a notification tap should land.
///
/// Modelled as data rather than as a URL so the routing decision stays unit
/// testable without a live `GoRouter`.
class NotificationDestination {
  const NotificationDestination(
    this.routePath, {
    this.queryParameters = const {},
  });

  final String routePath;
  final Map<String, String> queryParameters;

  @override
  bool operator ==(Object other) =>
      other is NotificationDestination &&
      other.routePath == routePath &&
      mapEquals(other.queryParameters, queryParameters);

  @override
  int get hashCode => Object.hash(routePath, queryParameters.length);

  @override
  String toString() => 'NotificationDestination($routePath, $queryParameters)';
}

bool mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Translates an FCM payload into an in-app destination.
///
/// Resolution order matters and is intentional: a Gmail match always has a
/// thread to review, which is more specific than the application it points at,
/// so it wins. Otherwise the most specific linked entity is used
/// (interview > follow-up > application), and only then do we fall back to the
/// hub screens.
///
/// A payload that references an id we cannot route to falls back to a list
/// screen rather than dead-ending on a broken detail route.
class NotificationRouter {
  const NotificationRouter();

  NotificationDestination? resolve(Map<String, dynamic> data) {
    if (data.isEmpty) return null;

    final threadId = _readString(data, NotificationPayloadKeys.gmailThreadId);
    final messageId = _readString(data, NotificationPayloadKeys.gmailMessageId);
    final interviewId = _readString(data, NotificationPayloadKeys.interviewId);
    final followupId = _readString(data, NotificationPayloadKeys.followupId);
    final applicationId = _readString(
      data,
      NotificationPayloadKeys.applicationId,
    );

    // A Gmail thread detail is only addressable for a message we hold; when
    // only the thread is known, land on the thread list.
    if (messageId != null) {
      return NotificationDestination(
        RouteNames.gmailMessageDetailPath(messageId),
      );
    }
    if (threadId != null) {
      return NotificationDestination(
        RouteNames.gmailThreadDetailPath(threadId),
      );
    }
    if (interviewId != null) {
      if (applicationId != null) {
        return NotificationDestination(
          RouteNames.interviewDetailPath(interviewId),
          queryParameters: {'applicationId': applicationId},
        );
      }
      return const NotificationDestination(RouteNames.interviews);
    }
    if (followupId != null) {
      if (applicationId != null) {
        return NotificationDestination(
          RouteNames.applicationDetailPath(applicationId),
          queryParameters: {'focusFollowupId': followupId},
        );
      }
      return const NotificationDestination(RouteNames.followups);
    }
    if (applicationId != null) {
      return NotificationDestination(
        RouteNames.applicationDetailPath(applicationId),
      );
    }
    return const NotificationDestination(RouteNames.notifications);
  }

  static String? _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
