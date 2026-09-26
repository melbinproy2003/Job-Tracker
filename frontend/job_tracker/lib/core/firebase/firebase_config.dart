import '../constants/app_env.dart';

/// Firebase project configuration helpers.
abstract final class FirebaseConfig {
  static String get projectId => AppEnv.firebaseProjectId;
}
