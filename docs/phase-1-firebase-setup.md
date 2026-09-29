# Phase 1 — Firebase & Google Sign-In Setup

## 1. Firebase project

1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Authentication → Sign-in method → Google**
3. Create an **Android** app with package name: `com.jobtracker.job_tracker`
4. Create an **iOS** app if needed (bundle id must match Xcode)
5. Download:
   - `google-services.json` → `frontend/job_tracker/android/app/google-services.json`
   - `GoogleService-Info.plist` → `frontend/job_tracker/ios/Runner/GoogleService-Info.plist`

## 2. FlutterFire options

From `frontend/job_tracker`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This overwrites `lib/firebase_options.dart` with real values.

## 3. Android SHA-1 (required for Google Sign-In)

```bash
cd android
./gradlew signingReport
```

Add the debug SHA-1 in Firebase Console → Project settings → Your Android app.

## 4. Web client ID (serverClientId)

In Google Cloud Console / Firebase → Authentication → Google provider,
copy the **Web client ID** (`….apps.googleusercontent.com`).

Pass it when running Flutter:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

## 5. Backend Firebase Admin

1. Firebase Console → Project settings → Service accounts → Generate new private key
2. Copy values into `backend/.env`:

```env
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

## 6. Firestore

1. Create a Firestore database
2. Deploy rules from repo root file `firestore.rules` (Console or Firebase CLI)

## 7. Never commit

- `.env`
- Service account JSON
- Real `google-services.json` / `GoogleService-Info.plist` if your team treats them as secrets (already gitignored in this repo)
