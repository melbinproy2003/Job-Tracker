import 'package:dio/dio.dart';

/// Attaches Firebase ID token to outgoing requests.
///
/// Tokens are obtained from the Firebase SDK (not stored in plaintext by us).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenProvider});

  final Future<String?> Function() tokenProvider;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await tokenProvider();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Proceed without token; backend will return 401 if required.
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Do not log Authorization headers or token material.
    handler.next(err);
  }
}
