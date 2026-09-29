import 'package:dio/dio.dart';

import '../../../../core/enums/application_status.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/application.dart';
import '../models/application_model.dart';
import '../models/application_status_history_model.dart';

class ApplicationListQuery {
  const ApplicationListQuery({
    this.search,
    this.statuses,
    this.sources,
    this.employmentTypes,
    this.location,
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
    this.page = 1,
    this.pageSize = 20,
  });

  final String? search;
  final List<ApplicationStatus>? statuses;
  final List<String>? sources;
  final List<String>? employmentTypes;
  final String? location;
  final String sortBy;
  final String sortOrder;
  final int page;
  final int pageSize;

  Map<String, dynamic> toQuery() {
    final map = <String, dynamic>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search!.trim().isNotEmpty) {
      map['search'] = search!.trim();
    }
    if (location != null && location!.trim().isNotEmpty) {
      map['location'] = location!.trim();
    }
    if (statuses != null && statuses!.isNotEmpty) {
      map['status'] = statuses!.map((e) => e.apiValue).toList();
    }
    if (sources != null && sources!.isNotEmpty) map['source'] = sources;
    if (employmentTypes != null && employmentTypes!.isNotEmpty) {
      map['employment_type'] = employmentTypes;
    }
    return map;
  }
}

class ApplicationApiDataSource {
  ApplicationApiDataSource(this._dio);
  final Dio _dio;

  Future<PaginatedApplications> list(ApplicationListQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.applications,
      queryParameters: query.toQuery(),
    );
    final data = response.data!;
    final items = (data['items'] as List<dynamic>)
        .map(
          (e) =>
              ApplicationModel.fromJson(e as Map<String, dynamic>).toEntity(),
        )
        .toList();
    return PaginatedApplications(
      items: items,
      page: data['page'] as int,
      pageSize: data['page_size'] as int,
      total: data['total'] as int,
      hasNext: data['has_next'] as bool,
    );
  }

  Future<Application> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.application(id),
    );
    return ApplicationModel.fromJson(response.data!).toEntity();
  }

  Future<Application> create(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.applications,
      data: body,
    );
    return ApplicationModel.fromJson(response.data!).toEntity();
  }

  Future<Application> update(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.application(id),
      data: body,
    );
    return ApplicationModel.fromJson(response.data!).toEntity();
  }

  Future<void> delete(String id) async {
    await _dio.delete(ApiEndpoints.application(id));
  }

  Future<Application> changeStatus(
    String id, {
    required ApplicationStatus status,
    String? note,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.applicationStatus(id),
      data: {'status': status.apiValue, 'note': ?note},
    );
    return ApplicationModel.fromJson(response.data!).toEntity();
  }

  Future<List<ApplicationStatusHistoryModel>> history(String id) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.applicationHistory(id),
    );
    return (response.data ?? [])
        .map(
          (e) =>
              ApplicationStatusHistoryModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }
}
