import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

class GoogleSignInUseCase {
  GoogleSignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthenticatedUser> call() async {
    final user = await _repository.signInWithGoogle();
    // Upsert user on backend after Firebase auth succeeds.
    try {
      return await _repository.syncProfileWithBackend();
    } catch (_) {
      // Backend sync failure should not block local Firebase session.
      return user;
    }
  }
}
