import '../../../../core/enums/application_status.dart';
import '../../domain/entities/application.dart';
import '../../domain/entities/application_status_history.dart';
import '../../domain/repositories/application_repository.dart';
import '../datasources/application_api_datasource.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  ApplicationRepositoryImpl(this._remote);
  final ApplicationApiDataSource _remote;

  @override
  Future<PaginatedApplications> getApplications(ApplicationListQuery query) =>
      _remote.list(query);

  @override
  Future<Application> getApplication(String id) => _remote.getById(id);

  @override
  Future<Application> createApplication(Map<String, dynamic> body) =>
      _remote.create(body);

  @override
  Future<Application> updateApplication(String id, Map<String, dynamic> body) =>
      _remote.update(id, body);

  @override
  Future<void> deleteApplication(String id) => _remote.delete(id);

  @override
  Future<Application> changeStatus(
    String id,
    ApplicationStatus status, {
    String? note,
  }) => _remote.changeStatus(id, status: status, note: note);

  @override
  Future<List<ApplicationStatusHistory>> getHistory(String id) async {
    final rows = await _remote.history(id);
    return rows.map((e) => e.toEntity()).toList();
  }
}
