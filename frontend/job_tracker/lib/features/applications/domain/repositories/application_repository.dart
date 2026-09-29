import '../../../../core/enums/application_status.dart';
import '../../data/datasources/application_api_datasource.dart';
import '../entities/application.dart';
import '../entities/application_status_history.dart';

abstract class ApplicationRepository {
  Future<PaginatedApplications> getApplications(ApplicationListQuery query);
  Future<Application> getApplication(String id);
  Future<Application> createApplication(Map<String, dynamic> body);
  Future<Application> updateApplication(String id, Map<String, dynamic> body);
  Future<void> deleteApplication(String id);
  Future<Application> changeStatus(
    String id,
    ApplicationStatus status, {
    String? note,
  });
  Future<List<ApplicationStatusHistory>> getHistory(String id);
}
