import '../../domain/entities/company.dart';
import '../../domain/repositories/companies_repository.dart';
import '../datasources/companies_remote_datasource.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  CompanyRepositoryImpl(this._remote);
  final CompanyRemoteDataSource _remote;

  @override
  Future<List<Company>> getAll() => _remote.list();

  @override
  Future<Company> getById(String id) => _remote.getById(id);

  @override
  Future<Company> create(Map<String, dynamic> body) => _remote.create(body);

  @override
  Future<Company> update(String id, Map<String, dynamic> body) =>
      _remote.update(id, body);

  @override
  Future<void> delete(String id) => _remote.delete(id);
}
