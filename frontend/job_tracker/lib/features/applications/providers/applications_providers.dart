import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/application_api_datasource.dart';
import '../data/repositories/application_repository_impl.dart';
import '../domain/repositories/application_repository.dart';

final applicationApiDataSourceProvider = Provider<ApplicationApiDataSource>((
  ref,
) {
  return ApplicationApiDataSource(ref.watch(dioProvider));
});

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepositoryImpl(ref.watch(applicationApiDataSourceProvider));
});
