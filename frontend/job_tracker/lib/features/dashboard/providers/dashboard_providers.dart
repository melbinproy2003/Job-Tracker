import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/dashboard_remote_datasource.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../domain/entities/dashboard_summary.dart';
import '../domain/repositories/dashboard_repository.dart';

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((
  ref,
) {
  return DashboardRemoteDataSource(ref.watch(dioProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(dashboardRemoteDataSourceProvider));
});

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  return ref.watch(dashboardRepositoryProvider).getDashboard();
});
