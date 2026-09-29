import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/activity.dart';
import '../models/activity_model.dart';

class ActivityRemoteDataSource {
  ActivityRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<Activity>> listForApplication(String applicationId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.applicationActivities(applicationId),
      );
      return (response.data ?? [])
          .map(
            (e) => ActivityModel.fromJson(e as Map<String, dynamic>).toEntity(),
          )
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }
}
