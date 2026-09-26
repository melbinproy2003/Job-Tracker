import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._remote);
  final DashboardRemoteDataSource _remote;

  @override
  Future<DashboardSummary> getDashboard() => _remote.fetch();
}
