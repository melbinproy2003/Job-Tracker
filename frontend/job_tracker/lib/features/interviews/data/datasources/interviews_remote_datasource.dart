import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/interview.dart';
import '../models/interview_model.dart';

class InterviewListQuery {
  const InterviewListQuery({
    this.status,
    this.from,
    this.to,
    this.applicationId,
  });

  final String? status;
  final DateTime? from;
  final DateTime? to;
  final String? applicationId;

  Map<String, dynamic> toQuery() {
    final map = <String, dynamic>{};
    if (status != null) map['status'] = status;
    if (from != null) map['from'] = toApiDateTime(from!);
    if (to != null) map['to'] = toApiDateTime(to!);
    if (applicationId != null) map['application_id'] = applicationId;
    return map;
  }
}

class InterviewRemoteDataSource {
  InterviewRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<Interview>> list([
    InterviewListQuery query = const InterviewListQuery(),
  ]) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.interviews,
        queryParameters: query.toQuery(),
      );
      return (response.data ?? [])
          .map(
            (e) =>
                InterviewModel.fromJson(e as Map<String, dynamic>).toEntity(),
          )
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<List<Interview>> listForApplication(String applicationId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.applicationInterviews(applicationId),
      );
      return (response.data ?? [])
          .map(
            (e) =>
                InterviewModel.fromJson(e as Map<String, dynamic>).toEntity(),
          )
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<Interview> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.interview(id),
      );
      return InterviewModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<Interview> create(
    String applicationId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.applicationInterviews(applicationId),
        data: body,
      );
      return InterviewModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<Interview> update(String id, Map<String, dynamic> body) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.interview(id),
        data: body,
      );
      return InterviewModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete(ApiEndpoints.interview(id));
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }
}
