import 'package:dio/dio.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/authenticated_user_model.dart';

/// FastAPI auth endpoints datasource.
class AuthApiDataSource {
  AuthApiDataSource(this._dio);

  final Dio _dio;

  Future<AuthenticatedUserModel> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.authMe,
      );
      final data = response.data;
      if (data == null) {
        throw const AuthFailure(
          'Empty profile response.',
          code: 'USER_NOT_FOUND',
        );
      }
      return AuthenticatedUserModel.fromJson(data);
    } on DioException catch (e) {
      final code = e.response?.data is Map
          ? (e.response!.data['error']?['code'] as String?)
          : null;
      final message = e.response?.data is Map
          ? (e.response!.data['error']?['message'] as String?)
          : null;
      throw AuthFailure(
        message ?? 'Unable to load profile from server.',
        code: code ?? 'NETWORK_ERROR',
      );
    }
  }
}
