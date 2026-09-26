import 'app_env.dart';

abstract final class ApiConstants {
  /// Resolved from `.env` (`API_BASE_URL`) or `--dart-define=API_BASE_URL=...`.
  static String get baseUrl => AppEnv.apiBaseUrl;
}
