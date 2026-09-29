import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/google_sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../providers/auth_providers.dart';

enum AuthenticationStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthenticationState extends Equatable {
  const AuthenticationState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthenticationState.initial()
    : this(status: AuthenticationStatus.initial);

  const AuthenticationState.loading()
    : this(status: AuthenticationStatus.loading);

  const AuthenticationState.authenticated(AuthenticatedUser user)
    : this(status: AuthenticationStatus.authenticated, user: user);

  const AuthenticationState.unauthenticated()
    : this(status: AuthenticationStatus.unauthenticated);

  const AuthenticationState.error(String message)
    : this(status: AuthenticationStatus.error, errorMessage: message);

  final AuthenticationStatus status;
  final AuthenticatedUser? user;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthenticationStatus.authenticated && user != null;

  bool get isLoading =>
      status == AuthenticationStatus.loading ||
      status == AuthenticationStatus.initial;

  AuthenticationState copyWith({
    AuthenticationStatus? status,
    AuthenticatedUser? user,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthenticationState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}

class AuthController extends StateNotifier<AuthenticationState> {
  AuthController({
    required AuthRepository authRepository,
    required GoogleSignInUseCase googleSignIn,
    required SignOutUseCase signOut,
    required GetCurrentUserUseCase getCurrentUser,
  }) : _authRepository = authRepository,
       _googleSignIn = googleSignIn,
       _signOut = signOut,
       _getCurrentUser = getCurrentUser,
       super(const AuthenticationState.initial()) {
    _subscription = _authRepository.authStateChanges().listen(_onAuthChanged);
  }

  final AuthRepository _authRepository;
  final GoogleSignInUseCase _googleSignIn;
  final SignOutUseCase _signOut;
  final GetCurrentUserUseCase _getCurrentUser;
  StreamSubscription<AuthenticatedUser?>? _subscription;

  Future<void> bootstrap() async {
    state = const AuthenticationState.loading();
    try {
      final user = await _getCurrentUser();
      if (user != null) {
        state = AuthenticationState.authenticated(user);
        unawaited(_softSyncBackend());
      } else {
        state = const AuthenticationState.unauthenticated();
      }
    } catch (_) {
      state = const AuthenticationState.unauthenticated();
    }
  }

  void _onAuthChanged(AuthenticatedUser? user) {
    if (user == null) {
      if (state.status != AuthenticationStatus.loading) {
        state = const AuthenticationState.unauthenticated();
      }
      return;
    }
    state = AuthenticationState.authenticated(user);
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(
      status: AuthenticationStatus.loading,
      clearError: true,
    );
    try {
      final user = await _googleSignIn();
      state = AuthenticationState.authenticated(user);
    } on AuthCancelledFailure {
      state = const AuthenticationState.unauthenticated();
    } on AuthFailure catch (e) {
      state = AuthenticationState.error(e.message);
    } catch (_) {
      state = const AuthenticationState.error(
        'Unable to sign in with Google. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    state = const AuthenticationState.loading();
    try {
      await _signOut();
      state = const AuthenticationState.unauthenticated();
    } catch (_) {
      state = const AuthenticationState.error('Unable to sign out.');
    }
  }

  Future<void> _softSyncBackend() async {
    try {
      final synced = await _authRepository.syncProfileWithBackend();
      if (state.isAuthenticated) {
        state = AuthenticationState.authenticated(synced);
      }
    } catch (_) {
      // Keep Firebase session even if API is unreachable.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthenticationState>((ref) {
      return AuthController(
        authRepository: ref.watch(authRepositoryProvider),
        googleSignIn: ref.watch(googleSignInUseCaseProvider),
        signOut: ref.watch(signOutUseCaseProvider),
        getCurrentUser: ref.watch(getCurrentUserUseCaseProvider),
      );
    });
