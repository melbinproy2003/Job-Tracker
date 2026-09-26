import 'package:dio/dio.dart';

import 'auth_interceptor.dart';

/// Shared Dio client for FastAPI communication.
class ApiClient {
  ApiClient({required String baseUrl, required AuthInterceptor authInterceptor})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Content-Type': 'application/json'},
        ),
      ) {
    dio.interceptors.add(authInterceptor);
  }

  final Dio dio;
}
