import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:job_tracker/core/errors/app_failure.dart';
import 'package:job_tracker/features/authentication/domain/entities/authenticated_user.dart';
import 'package:job_tracker/features/authentication/domain/repositories/auth_repository.dart';
import 'package:job_tracker/features/authentication/domain/usecases/get_current_user.dart';
import 'package:job_tracker/features/authentication/domain/usecases/google_sign_in.dart';
import 'package:job_tracker/features/authentication/domain/usecases/sign_out.dart';
import 'package:job_tracker/features/authentication/presentation/controllers/auth_controller.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late AuthController controller;

  const user = AuthenticatedUser(
    id: 'uid-1',
    email: 'melbin@example.com',
    displayName: 'Melbin',
    photoUrl: null,
    emailVerified: true,
  );

  setUp(() {
    repository = _MockAuthRepository();
    when(
      () => repository.authStateChanges(),
    ).thenAnswer((_) => const Stream<AuthenticatedUser?>.empty());
    controller = AuthController(
      authRepository: repository,
      googleSignIn: GoogleSignInUseCase(repository),
      signOut: SignOutUseCase(repository),
      getCurrentUser: GetCurrentUserUseCase(repository),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('bootstrap unauthenticated', () async {
    when(() => repository.getCurrentUser()).thenAnswer((_) async => null);
    await controller.bootstrap();
    expect(controller.state.status, AuthenticationStatus.unauthenticated);
  });

  test('bootstrap authenticated', () async {
    when(() => repository.getCurrentUser()).thenAnswer((_) async => user);
    when(
      () => repository.syncProfileWithBackend(),
    ).thenAnswer((_) async => user);
    await controller.bootstrap();
    expect(controller.state.isAuthenticated, isTrue);
    expect(controller.state.user?.id, 'uid-1');
  });

  test('google login success', () async {
    when(() => repository.signInWithGoogle()).thenAnswer((_) async => user);
    when(
      () => repository.syncProfileWithBackend(),
    ).thenAnswer((_) async => user);
    await controller.signInWithGoogle();
    expect(controller.state.status, AuthenticationStatus.authenticated);
    expect(controller.state.user, user);
  });

  test('google login cancellation', () async {
    when(
      () => repository.signInWithGoogle(),
    ).thenThrow(const AuthCancelledFailure());
    await controller.signInWithGoogle();
    expect(controller.state.status, AuthenticationStatus.unauthenticated);
  });

  test('authentication failure', () async {
    when(
      () => repository.signInWithGoogle(),
    ).thenThrow(const AuthFailure('boom', code: 'UNKNOWN'));
    await controller.signInWithGoogle();
    expect(controller.state.status, AuthenticationStatus.error);
    expect(controller.state.errorMessage, 'boom');
  });

  test('logout', () async {
    when(() => repository.getCurrentUser()).thenAnswer((_) async => user);
    when(
      () => repository.syncProfileWithBackend(),
    ).thenAnswer((_) async => user);
    when(() => repository.signOut()).thenAnswer((_) async {});
    await controller.bootstrap();
    await controller.signOut();
    expect(controller.state.status, AuthenticationStatus.unauthenticated);
  });
}
