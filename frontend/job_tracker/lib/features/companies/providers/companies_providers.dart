import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/companies_remote_datasource.dart';
import '../data/repositories/companies_repository_impl.dart';
import '../domain/repositories/companies_repository.dart';

final companyRemoteDataSourceProvider = Provider<CompanyRemoteDataSource>((
  ref,
) {
  return CompanyRemoteDataSource(ref.watch(dioProvider));
});

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepositoryImpl(ref.watch(companyRemoteDataSourceProvider));
});

final companiesListProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(companyRepositoryProvider).getAll();
});

final companyDetailProvider = FutureProvider.autoDispose.family((
  ref,
  String id,
) async {
  return ref.watch(companyRepositoryProvider).getById(id);
});
