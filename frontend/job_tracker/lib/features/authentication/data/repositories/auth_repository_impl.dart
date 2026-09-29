import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_datasource.dart';
import '../datasources/firebase_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required FirebaseAuthDataSource firebaseAuthDataSource,
    required AuthApiDataSource authApiDataSource,
  }) : _firebase = firebaseAuthDataSource,
       _api = authApiDataSource;

  final FirebaseAuthDataSource _firebase;
  final AuthApiDataSource _api;

  @override
  Stream<AuthenticatedUser?> authStateChanges() => _firebase.authStateChanges();

  @override
  Future<AuthenticatedUser?> getCurrentUser() async => _firebase.currentUser;

  @override
  Future<AuthenticatedUser> signInWithGoogle() => _firebase.signInWithGoogle();

  @override
  Future<void> signOut() => _firebase.signOut();

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) {
    return _firebase.getIdToken(forceRefresh: forceRefresh);
  }

  @override
  Future<AuthenticatedUser> syncProfileWithBackend() async {
    final model = await _api.getMe();
    return model.toEntity();
  }
}
