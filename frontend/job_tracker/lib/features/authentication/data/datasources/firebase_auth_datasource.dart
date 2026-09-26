import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_env.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/authenticated_user.dart';

/// Firebase + Google Sign-In data source. Never logs tokens or credentials.
class FirebaseAuthDataSource {
  FirebaseAuthDataSource({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             scopes: const ['email', 'profile'],
             // Web client ID from `.env` → GOOGLE_SERVER_CLIENT_ID
             serverClientId: AppEnv.googleServerClientId,
           );

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<AuthenticatedUser?> authStateChanges() {
    return _auth.authStateChanges().map(_mapUser);
  }

  AuthenticatedUser? get currentUser => _mapUser(_auth.currentUser);

  Future<AuthenticatedUser> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthCancelledFailure();
      }

      final googleAuth = await account.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null && idToken == null) {
        throw const AuthFailure(
          'Google authentication failed.',
          code: 'INVALID_CREDENTIAL',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthFailure(
          'Firebase authentication failed.',
          code: 'FIREBASE_ERROR',
        );
      }
      return _mapUser(user)!;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException code=${e.code}');
      throw AuthFailure(_friendlyFirebaseMessage(e.code), code: e.code);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      debugPrint('Google sign-in failed: ${e.runtimeType}');
      throw const AuthFailure(
        'Unable to sign in with Google. Please try again.',
        code: 'UNKNOWN',
      );
    }
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  AuthenticatedUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthenticatedUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
    );
  }

  String _friendlyFirebaseMessage(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'invalid-credential':
      case 'user-disabled':
        return 'Unable to sign in with this Google account.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return 'Google sign-in failed. Please try again.';
    }
  }
}
