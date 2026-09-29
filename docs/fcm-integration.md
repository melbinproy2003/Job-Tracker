# FCM Integration

Device-level detail for Firebase Cloud Messaging. For the notification
pipeline itself see [`notification-architecture.md`](notification-architecture.md).

## Platform support

FCM is used on **Android** and **iOS** only. `FcmService` guards every entry
point with `isSupported`, and the app's `main()` skips `Firebase.initializeApp`
elsewhere, so the web and desktop targets cannot crash on a messaging call.

`isSupportedPlatform` is the static platform predicate (used by `main()` to
decide whether to initialise Firebase at all). `FcmService.isSupported` is the
instance form, and the device-registration controller depends on **that** so
the abstraction it is handed is what gets consulted — this is what makes the
registration flow testable off-device.

## Permission model

Android 13+ requires an explicit runtime grant. iOS shows a system prompt once
and will not ask again after a refusal.

The problem this solves: a naive app re-prompts on every launch, which the
Play Store penalises, and it cannot distinguish "user said no" from "user said
no *and the OS will now never ask again*". The second case needs different UI
(a button to system Settings), not another prompt.

So the app tracks whether it has ever prompted, in
`SecureNotificationPermissionStore` (encrypted shared preferences on Android,
Keychain on iOS), and maps the raw OS status through
`FcmService.fromAuthorizationStatus`:

| OS status | Never prompted before | Prompted before |
| --- | --- | --- |
| `authorized`, `provisional` | `granted` | `granted` |
| `notDetermined` | `undetermined` | `undetermined` |
| `denied` | `denied` | **`permanentlyDenied`** |
| unsupported platform | `denied` | `denied` |

`DeviceRegistrationController.start()` then:

- `granted` → fetch the token and register, **without** prompting again;
- `undetermined` → prompt exactly once, and persist that a prompt happened
  *before* awaiting the result (so a process death mid-prompt cannot cause a
  second prompt);
- `denied` → do nothing, silently;
- `permanentlyDenied` → do nothing, and the UI offers **Open notification
  settings** via `system_notification_settings.dart`.

Guarantees covered by tests in `test/phase4_notifications_test.dart`:
prompts exactly once on first run, never prompts again on a later launch,
survives a failing registration, and is a no-op on unsupported platforms.

## Registration

```
FCM token
  → POST /api/v1/notifications/devices   {fcm_token, platform, device_name, app_version}
  → devices/{id} upserted by (user_id, fcm_token)
```

Registering the same token twice **updates** the existing device row instead of
creating a second one, so a reinstall-free re-registration does not double-send.
This matters because Flutter re-registers on every cold start and whenever the
user signs in.

Token **rotation** is handled by subscribing to `onTokenRefresh` and
re-registering; without it, a rotated token silently stops delivering.
The test `re-registers when FCM rotates the token` pins this.

The backend deactivates a device when FCM answers `unregistered` or
`invalid-registration-token`, so revoked tokens stop costing quota.

The FCM token is never treated as client-side source of truth — the backend
owns the mapping from user to device.

## Android configuration

`frontend/job_tracker/android/`

- `POST_NOTIFICATIONS` permission in `AndroidManifest.xml`.
- Default channel metadata:
  ```xml
  <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="job_tracker_notifications" />
  ```
  The channel itself is created at runtime by
  `core/notifications/notification_service.dart`.
- Monochrome vector icon `res/drawable/ic_notification.xml` plus a
  `notification_icon` colour — Android tints these and the launcher icon must
  never be reused for a status-bar icon.
- `flutter_local_notifications` 22.x requires, in `app/build.gradle.kts`:
  `minSdk = 24`, `multiDexEnabled = true`, Java 17, and
  `coreLibraryDesugaringEnabled` with `com.android.tools:desugar_jdk_libs:2.1.4`
  (the plugin uses `java.time`).

`flutter build apk --debug` is the check that all of the above is actually
valid; a wrong desugaring version only fails at build time.

## iOS configuration

`frontend/job_tracker/ios/`

- `UIBackgroundModes` contains `remote-notification` in `Info.plist`, which is
  required for silent/background delivery.

Manual steps that **cannot** be automated from the repo:

1. Xcode → target → Signing & Capabilities → **+ Capability** → **Push
   Notifications**.
2. Create an APNs key (.p8) in the Apple developer portal.
3. Upload the .p8 to Firebase → Project settings → Cloud Messaging → iOS.
4. Ensure the App ID has the Push Notifications service enabled.

The Flutter app draws its own local notifications on iOS, so no notification
service extension is required.

## Local notifications

`core/notifications/notification_service.dart` uses
`flutter_local_notifications` 22.x (named-parameter APIs) for:

- the Android channel;
- drawing a tray notification for **data-only** pushes, which the OS does not
  display on its own;
- carrying the deep link, so a tap on a locally drawn notification resolves
  through the same `NotificationRouter` as an FCM tap.

`notification_background_handler.dart` is a top-level function annotated
`@pragma('vm:entry-point')` — required so the Dart AOT runtime can find it when
the app is launched into a background isolate.

Notifications with an FCM `notification` block are skipped by the background
handler on purpose: the OS already drew them, and drawing a second one would
duplicate.

## Manual verification checklist

FCM cannot be exercised in a unit test or on a simulator. Before considering
Phase 4 done on a real device:

1. Send from Firebase console → check the tray icon, tap, confirm deep link.
2. Send with the app foregrounded → confirm the in-app banner appears and does
   **not** navigate until tapped.
3. Deny permission twice → confirm the app offers Settings, not a re-prompt.
4. Revoke the token (reinstall) → confirm no duplicate sends.
5. Check `devices` in Firestore: one row per token, `is_active` true.
