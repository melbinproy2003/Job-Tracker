import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/follow_up.dart';
import '../models/follow_up_model.dart';

class FollowUpListQuery {
  const FollowUpListQuery({
    this.completed,
    this.from,
    this.to,
    this.applicationId,
  });

  final bool? completed;
  final DateTime? from;
  final DateTime? to;
  final String? applicationId;

  Map<String, dynamic> toQuery() {
    final map = <String, dynamic>{};
    if (completed != null) map['completed'] = completed;
    if (from != null) map['from'] = toApiDateTime(from!);
    if (to != null) map['to'] = toApiDateTime(to!);
    if (applicationId != null) map['application_id'] = applicationId;
    return map;
  }
}

class FollowUpRemoteDataSource {
  FollowUpRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<FollowUp>> list([
    FollowUpListQuery query = const FollowUpListQuery(),
  ]) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.followups,
        queryParameters: query.toQuery(),
      );
      return (response.data ?? [])
          .map(
            (e) => FollowUpModel.fromJson(e as Map<String, dynamic>).toEntity(),
          )
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<FollowUp> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.followup(id),
      );
      return FollowUpModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<FollowUp> create(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.followups,
        data: body,
      );
      return FollowUpModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<FollowUp> update(String id, Map<String, dynamic> body) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.followup(id),
        data: body,
      );
      return FollowUpModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<FollowUp> complete(String id) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.followupComplete(id),
      );
      return FollowUpModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete(ApiEndpoints.followup(id));
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }
}
