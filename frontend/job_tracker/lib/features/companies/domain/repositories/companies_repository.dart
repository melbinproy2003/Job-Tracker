import '../entities/company.dart';

abstract class CompanyRepository {
  Future<List<Company>> getAll();
  Future<Company> getById(String id);
  Future<Company> create(Map<String, dynamic> body);
  Future<Company> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
}
