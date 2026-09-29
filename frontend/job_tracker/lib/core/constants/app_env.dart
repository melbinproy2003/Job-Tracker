import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'env_file_loader.dart';

/// Runtime config from `.env` (loaded via flutter_dotenv).
///
/// Priority: `--dart-define=KEY=value` → local `.env` → `.env.example` → defaults.
abstract final class AppEnv {
  static const _defineApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _defineGoogleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _defineFirebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static Map<String, String> _localEnv = const {};

  static Future<void> load() async {
    final contents = readLocalEnvFile('.env');
    if (contents == null) {
      debugPrint('No local .env found; using .env.example defaults.');
      _localEnv = const {};
    } else {
      _localEnv = const Parser().parse(contents.split('\n'));
    }
    // Committed asset, so it is always present in a fresh checkout.
    await dotenv.load(fileName: '.env.example', isOptional: true);
  }

  static String _read(String key, {String fallback = ''}) {
    final local = _localEnv[key]?.trim();
    if (local != null && local.isNotEmpty) return local;
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static String get apiBaseUrl {
    if (_defineApiBaseUrl.isNotEmpty) return _defineApiBaseUrl;
    return _read('API_BASE_URL', fallback: 'http://10.0.2.2:8000');
  }

  static String? get googleServerClientId {
    if (_defineGoogleServerClientId.isNotEmpty) {
      return _defineGoogleServerClientId;
    }
    final value = _read('GOOGLE_SERVER_CLIENT_ID');
    return value.isEmpty ? null : value;
  }

  static String get firebaseProjectId {
    if (_defineFirebaseProjectId.isNotEmpty) return _defineFirebaseProjectId;
    return _read('FIREBASE_PROJECT_ID');
  }
}
