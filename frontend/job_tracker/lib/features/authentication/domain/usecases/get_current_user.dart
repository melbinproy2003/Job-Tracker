import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  GetCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthenticatedUser?> call() => _repository.getCurrentUser();
}
