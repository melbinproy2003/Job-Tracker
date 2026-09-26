import '../../data/datasources/application_api_datasource.dart';
import '../entities/application.dart';
import '../repositories/application_repository.dart';

class GetApplications {
  GetApplications(this._repository);

  final ApplicationRepository _repository;

  Future<PaginatedApplications> call(ApplicationListQuery query) =>
      _repository.getApplications(query);
}
