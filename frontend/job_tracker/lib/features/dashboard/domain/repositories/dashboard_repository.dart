import '../../domain/entities/dashboard_summary.dart';

abstract class DashboardRepository {
  Future<DashboardSummary> getDashboard();
}
