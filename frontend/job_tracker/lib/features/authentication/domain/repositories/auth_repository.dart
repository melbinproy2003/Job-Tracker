import '../entities/authenticated_user.dart';

/// Authentication repository contract. Google SSO only.
abstract class AuthRepository {
  Stream<AuthenticatedUser?> authStateChanges();

  Future<AuthenticatedUser?> getCurrentUser();

  Future<AuthenticatedUser> signInWithGoogle();

  Future<void> signOut();

  /// Returns a fresh Firebase ID token (force refresh when [forceRefresh] is true).
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Syncs profile with FastAPI (`GET /auth/me`) using the current ID token.
  Future<AuthenticatedUser> syncProfileWithBackend();
}
