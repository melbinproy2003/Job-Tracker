import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../providers/dashboard_providers.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/recent_application_card.dart';
import '../widgets/status_distribution.dart';
import '../widgets/upcoming_event_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final dash = ref.watch(dashboardProvider);
    final nameParts = (auth.user?.displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final firstName = nameParts.isEmpty ? null : nameParts.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Tracker'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Upcoming',
            onPressed: () => context.push(RouteNames.upcoming),
            icon: const Icon(Icons.calendar_today_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(RouteNames.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: dash.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Unable to load dashboard.',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                firstName == null
                    ? '${_greeting()} 👋'
                    : '${_greeting()}, $firstName 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your Job Search',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 110,
                child: DashboardStatCard(
                  label: 'Total Applications',
                  value: data.totalApplications,
                  icon: Icons.work_outline,
                  onTap: () => context.go(RouteNames.applications),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  DashboardStatCard(
                    label: 'Active',
                    value: data.activeApplications,
                    icon: Icons.trending_up,
                    onTap: () => context.go(RouteNames.applications),
                  ),
                  DashboardStatCard(
                    label: 'Interviews',
                    value: data.upcomingInterviews,
                    icon: Icons.event_available_outlined,
                    onTap: () => context.go(RouteNames.interviews),
                  ),
                  DashboardStatCard(
                    label: 'Offers',
                    value: data.offers,
                    icon: Icons.emoji_events_outlined,
                    accent: Colors.teal,
                  ),
                  DashboardStatCard(
                    label: 'Rejected',
                    value: data.rejected,
                    icon: Icons.cancel_outlined,
                    accent: Colors.redAccent,
                  ),
                  DashboardStatCard(
                    label: 'Follow-ups Due',
                    value: data.followupsDue,
                    icon: Icons.checklist_outlined,
                    onTap: () => context.go(RouteNames.followups),
                  ),
                  DashboardStatCard(
                    label: 'Overdue',
                    value: data.overdueFollowups,
                    icon: Icons.warning_amber_outlined,
                    accent: Colors.orange,
                    onTap: () => context.go(RouteNames.followups),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _sectionTitle(context, 'Application Status'),
              const SizedBox(height: 12),
              StatusDistribution(distribution: data.statusDistribution),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _sectionTitle(context, 'Upcoming')),
                  TextButton(
                    onPressed: () => context.push(RouteNames.upcoming),
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (data.upcomingEvents.isEmpty)
                Text(
                  'No upcoming interviews or follow-ups',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...data.upcomingEvents
                    .take(5)
                    .map(
                      (e) => UpcomingEventCard(
                        event: e,
                        onTap: () => _openEvent(context, e),
                      ),
                    ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Recent Applications'),
              const SizedBox(height: 8),
              if (data.recentApplications.isEmpty)
                Text(
                  'No applications yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...data.recentApplications.map(
                  (a) => RecentApplicationCard(
                    application: a,
                    onTap: () =>
                        context.push(RouteNames.applicationDetailPath(a.id)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  void _openEvent(BuildContext context, DashboardUpcomingEvent event) {
    if (event.isInterview) {
      context.push(RouteNames.interviewDetailPath(event.id));
    } else if (event.applicationId != null) {
      context.push(RouteNames.applicationDetailPath(event.applicationId!));
    } else {
      context.go(RouteNames.followups);
    }
  }
}
