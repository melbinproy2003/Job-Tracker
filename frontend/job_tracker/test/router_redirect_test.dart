import 'package:flutter_test/flutter_test.dart';

import 'package:job_tracker/app/router/route_names.dart';
import 'package:job_tracker/features/authentication/domain/entities/authenticated_user.dart';
import 'package:job_tracker/features/authentication/presentation/controllers/auth_controller.dart';

/// Pure redirect decision helper mirroring GoRouter redirect rules.
String? resolveAuthRedirect({
  required AuthenticationState auth,
  required String location,
}) {
  final loggingIn =
      location == RouteNames.login || location.startsWith('/auth');
  final atRoot = location == RouteNames.root;

  if (auth.isLoading || auth.status == AuthenticationStatus.initial) {
    return atRoot ? null : RouteNames.root;
  }

  if (!auth.isAuthenticated) {
    return loggingIn ? null : RouteNames.login;
  }

  if (loggingIn || atRoot) {
    return RouteNames.home;
  }
  return null;
}

void main() {
  const user = AuthenticatedUser(id: 'u1', email: 'a@b.com', displayName: 'A');

  test('unauthenticated user accessing home goes to login', () {
    final result = resolveAuthRedirect(
      auth: const AuthenticationState.unauthenticated(),
      location: RouteNames.home,
    );
    expect(result, RouteNames.login);
  });

  test('authenticated user accessing login goes to home', () {
    final result = resolveAuthRedirect(
      auth: const AuthenticationState.authenticated(user),
      location: RouteNames.login,
    );
    expect(result, RouteNames.home);
  });

  test('loading keeps root', () {
    final result = resolveAuthRedirect(
      auth: const AuthenticationState.loading(),
      location: RouteNames.root,
    );
    expect(result, isNull);
  });
}
