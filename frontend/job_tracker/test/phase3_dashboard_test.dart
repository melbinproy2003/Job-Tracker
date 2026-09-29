import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/features/authentication/domain/entities/authenticated_user.dart';
import 'package:job_tracker/features/authentication/domain/repositories/auth_repository.dart';
import 'package:job_tracker/features/authentication/domain/usecases/get_current_user.dart';
import 'package:job_tracker/features/authentication/domain/usecases/google_sign_in.dart';
import 'package:job_tracker/features/authentication/domain/usecases/sign_out.dart';
import 'package:job_tracker/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:job_tracker/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:job_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:job_tracker/features/dashboard/presentation/widgets/status_distribution.dart';
import 'package:job_tracker/features/dashboard/providers/dashboard_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = AuthenticatedUser(
  id: 'u1',
  email: 'a@b.com',
  displayName: 'Melbin Roy',
);

const _summary = DashboardSummary(
  totalApplications: 32,
  activeApplications: 18,
  interviews: 4,
  upcomingInterviews: 2,
  completedInterviews: 1,
  pendingFollowups: 3,
  overdueFollowups: 1,
  completedFollowups: 2,
  offers: 1,
  accepted: 0,
  rejected: 8,
  followupsDue: 3,
  statusDistribution: {'APPLIED': 10, 'REJECTED': 8},
  recentApplications: [],
  upcomingEvents: [],
);

AuthController _authController() {
  final repo = _MockAuthRepository();
  when(
    () => repo.authStateChanges(),
  ).thenAnswer((_) => Stream<AuthenticatedUser?>.value(_user));
  when(() => repo.getCurrentUser()).thenAnswer((_) async => _user);
  when(() => repo.syncProfileWithBackend()).thenAnswer((_) async => _user);
  return AuthController(
    authRepository: repo,
    googleSignIn: GoogleSignInUseCase(repo),
    signOut: SignOutUseCase(repo),
    getCurrentUser: GetCurrentUserUseCase(repo),
  );
}

void main() {
  testWidgets('status distribution renders bars', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusDistribution(distribution: {'APPLIED': 10, 'OFFER': 1}),
        ),
      ),
    );
    expect(find.text('Applied'), findsOneWidget);
    expect(find.text('Offer'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('dashboard loads summary', (tester) async {
    final auth = _authController();
    await auth.bootstrap();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) async => _summary),
          authControllerProvider.overrideWith((ref) => auth),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Melbin'), findsOneWidget);
    expect(find.text('Your Job Search'), findsOneWidget);
    expect(find.text('Total Applications'), findsOneWidget);
    expect(find.text('32'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Application Status'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Application Status'), findsOneWidget);
  });

  testWidgets('dashboard error shows retry', (tester) async {
    final auth = _authController();
    await auth.bootstrap();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Future<DashboardSummary>.error(Exception('network')),
          ),
          authControllerProvider.overrideWith((ref) => auth),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load dashboard'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
