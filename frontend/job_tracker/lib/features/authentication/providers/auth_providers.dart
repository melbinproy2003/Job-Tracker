import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_interceptor.dart';
import '../data/datasources/auth_api_datasource.dart';
import '../data/datasources/firebase_auth_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/get_current_user.dart';
import '../domain/usecases/google_sign_in.dart';
import '../domain/usecases/sign_out.dart';

final firebaseAuthDataSourceProvider = Provider<FirebaseAuthDataSource>((ref) {
  return FirebaseAuthDataSource();
});

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final firebase = ref.watch(firebaseAuthDataSourceProvider);
  return AuthInterceptor(
    tokenProvider: () => firebase.getIdToken(forceRefresh: false),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiConstants.baseUrl,
    authInterceptor: ref.watch(authInterceptorProvider),
  );
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider).dio;
});

final authApiDataSourceProvider = Provider<AuthApiDataSource>((ref) {
  return AuthApiDataSource(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    firebaseAuthDataSource: ref.watch(firebaseAuthDataSourceProvider),
    authApiDataSource: ref.watch(authApiDataSourceProvider),
  );
});

final googleSignInUseCaseProvider = Provider<GoogleSignInUseCase>((ref) {
  return GoogleSignInUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});
