import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/applications/presentation/screens/add_application_screen.dart';
import '../../features/applications/presentation/screens/application_detail_screen.dart';
import '../../features/applications/presentation/screens/applications_screen.dart';
import '../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../features/authentication/presentation/screens/auth_loading_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/companies/presentation/screens/add_company_screen.dart';
import '../../features/companies/presentation/screens/companies_screen.dart';
import '../../features/companies/presentation/screens/company_detail_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/followups/presentation/screens/add_followup_screen.dart';
import '../../features/followups/presentation/screens/followups_screen.dart';
import '../../features/gmail/presentation/screens/gmail_match_screen.dart';
import '../../features/gmail/presentation/screens/gmail_message_detail_screen.dart';
import '../../features/gmail/presentation/screens/gmail_screen.dart';
import '../../features/gmail/presentation/screens/gmail_settings_screen.dart';
import '../../features/gmail/presentation/screens/gmail_thread_detail_screen.dart';
import '../../features/gmail/presentation/screens/gmail_threads_screen.dart';
import '../../features/interviews/presentation/screens/add_interview_screen.dart';
import '../../features/interviews/presentation/screens/interview_detail_screen.dart';
import '../../features/interviews/presentation/screens/interviews_screen.dart';
import '../../features/notifications/presentation/screens/notification_preferences_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../../features/upcoming/presentation/screens/upcoming_screen.dart';
import 'route_names.dart';

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh();
  ref.listen<AuthenticationState>(authControllerProvider, (previous, next) {
    refresh.notify();
  });
  ref.onDispose(refresh.dispose);
  return refresh;
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: RouteNames.root,
    // Custom scheme deep links (jobtracker://gmail/...) are handled by
    // app_links + GmailOAuthDeepLinkHandler — not by GoRouter path matching.
    overridePlatformDefaultLocation: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final loggingIn = loc == RouteNames.login || loc.startsWith('/auth');
      final atRoot = loc == RouteNames.root;

      // Ignore accidental platform URIs that leak into the matched location.
      if (loc.startsWith('jobtracker:') || state.uri.scheme == 'jobtracker') {
        return auth.isAuthenticated
            ? RouteNames.settingsEmail
            : RouteNames.login;
      }

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
    },
    routes: [
      GoRoute(
        path: RouteNames.root,
        name: 'root',
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(
        path: RouteNames.auth,
        redirect: (context, state) {
          if (state.uri.path == RouteNames.auth) {
            return RouteNames.login;
          }
          return null;
        },
        routes: [
          GoRoute(
            path: 'login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: 'home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.applications,
                name: 'applications',
                builder: (context, state) => const ApplicationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.companies,
                name: 'companies',
                builder: (context, state) => const CompaniesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.interviews,
                name: 'interviews',
                builder: (context, state) => const InterviewsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.followups,
                name: 'followups',
                builder: (context, state) => const FollowUpsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.addApplication,
        name: 'addApplication',
        builder: (context, state) => const AddEditApplicationScreen(),
      ),
      GoRoute(
        path: '/applications/:id',
        name: 'applicationDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ApplicationDetailScreen(applicationId: id);
        },
      ),
      GoRoute(
        path: '/applications/:id/edit',
        name: 'editApplication',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditApplicationScreen(applicationId: id);
        },
      ),
      GoRoute(
        path: RouteNames.addCompany,
        name: 'addCompany',
        builder: (context, state) => const AddEditCompanyScreen(),
      ),
      GoRoute(
        path: '/companies/:id',
        name: 'companyDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CompanyDetailScreen(companyId: id);
        },
      ),
      GoRoute(
        path: '/companies/:id/edit',
        name: 'editCompany',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditCompanyScreen(companyId: id);
        },
      ),
      GoRoute(
        path: RouteNames.addInterview,
        name: 'addInterview',
        builder: (context, state) {
          final appId = state.uri.queryParameters['applicationId'];
          return AddEditInterviewScreen(applicationId: appId);
        },
      ),
      GoRoute(
        path: '/interviews/:id',
        name: 'interviewDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InterviewDetailScreen(interviewId: id);
        },
      ),
      GoRoute(
        path: '/interviews/:id/edit',
        name: 'editInterview',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditInterviewScreen(interviewId: id);
        },
      ),
      GoRoute(
        path: RouteNames.addFollowup,
        name: 'addFollowup',
        builder: (context, state) {
          final appId = state.uri.queryParameters['applicationId'];
          return AddEditFollowUpScreen(applicationId: appId);
        },
      ),
      GoRoute(
        path: '/followups/:id/edit',
        name: 'editFollowup',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditFollowUpScreen(followupId: id);
        },
      ),
      GoRoute(
        path: RouteNames.upcoming,
        name: 'upcoming',
        builder: (context, state) => const UpcomingScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // ---- Phase 4: notifications ----
      GoRoute(
        path: RouteNames.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.notificationPreferences,
        name: 'notificationPreferences',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),

      // ---- Phase 5: Gmail ----
      // `applicationId` scopes the inbox to one application, which is how the
      // application detail screen links its "Emails" section.
      GoRoute(
        path: RouteNames.gmail,
        name: 'gmail',
        builder: (context, state) {
          final applicationId = state.uri.queryParameters['applicationId'];
          return applicationId == null
              ? const GmailScreen()
              : GmailThreadsScreen(applicationId: applicationId);
        },
      ),
      GoRoute(
        path: RouteNames.settingsEmail,
        name: 'gmailSettings',
        builder: (context, state) => const GmailSettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.gmailMessageDetail,
        name: 'gmailMessageDetail',
        builder: (context, state) =>
            GmailMessageDetailScreen(messageId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RouteNames.gmailThreadDetail,
        name: 'gmailThreadDetail',
        builder: (context, state) =>
            GmailThreadDetailScreen(threadId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RouteNames.gmailAddApplication,
        name: 'gmailMatch',
        builder: (context, state) =>
            GmailMatchScreen(threadId: state.pathParameters['id']!),
      ),
    ],
  );
});
