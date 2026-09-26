import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../models/dashboard_model.dart';

class DashboardRemoteDataSource {
  DashboardRemoteDataSource(this._dio);
  final Dio _dio;

  Future<DashboardSummary> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.dashboard,
      );
      return DashboardModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }
}
