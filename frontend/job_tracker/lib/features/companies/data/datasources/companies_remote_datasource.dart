import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/company.dart';
import '../models/company_model.dart';

class CompanyRemoteDataSource {
  CompanyRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<Company>> list() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.companies);
    return (response.data ?? [])
        .map((e) => CompanyModel.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  Future<Company> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.company(id),
    );
    return CompanyModel.fromJson(response.data!).toEntity();
  }

  Future<Company> create(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.companies,
      data: body,
    );
    return CompanyModel.fromJson(response.data!).toEntity();
  }

  Future<Company> update(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.company(id),
      data: body,
    );
    return CompanyModel.fromJson(response.data!).toEntity();
  }

  Future<void> delete(String id) async {
    await _dio.delete(ApiEndpoints.company(id));
  }
}
