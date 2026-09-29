import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/enums/application_status.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../../activities/presentation/widgets/activity_timeline.dart';
import '../../../activities/providers/activities_providers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../followups/providers/followups_providers.dart';
import '../../../gmail/providers/gmail_providers.dart';
import '../../../interviews/providers/interviews_providers.dart';
import '../../providers/applications_providers.dart';
import '../controllers/applications_controller.dart';
import '../widgets/application_status_chip.dart';
import '../widgets/status_timeline.dart';

final applicationDetailProvider = FutureProvider.autoDispose.family((
  ref,
  String id,
) async {
  final repo = ref.watch(applicationRepositoryProvider);
  final app = await repo.getApplication(id);
  final history = await repo.getHistory(id);
  return (app: app, history: history);
});

class ApplicationDetailScreen extends ConsumerWidget {
  const ApplicationDetailScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(applicationDetailProvider(applicationId));
    final interviewsAsync = ref.watch(
      applicationInterviewsProvider(applicationId),
    );
    final followupsAsync = ref.watch(
      applicationFollowupsProvider(applicationId),
    );
    final activitiesAsync = ref.watch(
      applicationActivitiesProvider(applicationId),
    );

    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Unable to load application.',
          onRetry: () =>
              ref.invalidate(applicationDetailProvider(applicationId)),
        ),
      ),
      data: (data) {
        final app = data.app;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Application'),
            actions: [
              IconButton(
                tooltip: 'Change status',
                onPressed: () => _changeStatus(context, ref),
                icon: const Icon(Icons.flag_outlined),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () =>
                    context.push(RouteNames.editApplicationPath(applicationId)),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(
                  context,
                  ref,
                  data.app.jobTitle,
                  data.app.company.name,
                ),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(applicationDetailProvider(applicationId));
              ref.invalidate(applicationInterviewsProvider(applicationId));
              ref.invalidate(applicationFollowupsProvider(applicationId));
              ref.invalidate(applicationActivitiesProvider(applicationId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  app.company.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app.jobTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ApplicationStatusChip(status: app.status),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.event_outlined, size: 18),
                      label: const Text('Add Interview'),
                      onPressed: () async {
                        await context.push(
                          RouteNames.addInterviewPath(
                            applicationId: applicationId,
                          ),
                        );
                        ref.invalidate(
                          applicationInterviewsProvider(applicationId),
                        );
                        ref.invalidate(
                          applicationActivitiesProvider(applicationId),
                        );
                        ref.invalidate(dashboardProvider);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.checklist_outlined, size: 18),
                      label: const Text('Add Follow-up'),
                      onPressed: () async {
                        await context.push(
                          RouteNames.addFollowupPath(
                            applicationId: applicationId,
                          ),
                        );
                        ref.invalidate(
                          applicationFollowupsProvider(applicationId),
                        );
                        ref.invalidate(
                          applicationActivitiesProvider(applicationId),
                        );
                        ref.invalidate(dashboardProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Application Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _row('Location', app.location),
                _row('Source', app.source),
                _row('Employment', app.employmentType),
                _row('Job URL', app.jobUrl),
                _row(
                  'Applied',
                  app.appliedAt == null
                      ? null
                      : DateFormat.yMMMd().add_jm().format(app.appliedAt!),
                ),
                _row(
                  'Salary',
                  (app.salaryMin == null && app.salaryMax == null)
                      ? null
                      : '${app.currency ?? 'INR'} ${app.salaryMin ?? '—'} - ${app.salaryMax ?? '—'}',
                ),
                _row('Recruiter', app.recruiterName),
                _row('Recruiter email', app.recruiterEmail),
                const SizedBox(height: 24),
                Text(
                  'Status Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                StatusTimeline(history: data.history),
                const SizedBox(height: 24),
                Text(
                  'Interviews',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                interviewsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const Text('Unable to load interviews'),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(
                        'No interviews scheduled',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final i in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(i.displayTitle),
                            subtitle: Text(
                              DateFormat.MMMd().add_jm().format(i.scheduledAt),
                            ),
                            trailing: TextButton(
                              onPressed: () => context.push(
                                RouteNames.interviewDetailPath(i.id),
                              ),
                              child: const Text('View'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Follow-ups',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                followupsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const Text('Unable to load follow-ups'),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(
                        'No follow-ups',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final f in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              f.completed
                                  ? Icons.check_circle
                                  : f.isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.radio_button_unchecked,
                              color: f.completed
                                  ? Colors.green
                                  : f.isOverdue
                                  ? Colors.orange
                                  : null,
                            ),
                            title: Text(f.title),
                            subtitle: Text(
                              DateFormat.MMMd().add_jm().format(f.scheduledAt),
                            ),
                            trailing: f.completed
                                ? null
                                : TextButton(
                                    onPressed: () async {
                                      try {
                                        await ref
                                            .read(followUpRepositoryProvider)
                                            .complete(f.id);
                                        ref.invalidate(
                                          applicationFollowupsProvider(
                                            applicationId,
                                          ),
                                        );
                                        ref.invalidate(
                                          applicationActivitiesProvider(
                                            applicationId,
                                          ),
                                        );
                                        ref.invalidate(followupsProvider);
                                        ref.invalidate(dashboardProvider);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e is ApiException
                                                    ? e.message
                                                    : 'Failed',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Complete'),
                                  ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _EmailsSection(applicationId: applicationId),
                const SizedBox(height: 24),
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                activitiesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const Text('Unable to load activity'),
                  data: (items) => ActivityTimeline(activities: items),
                ),
                if (app.notes != null && app.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(app.notes!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    final status = await showModalBottomSheet<ApplicationStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Change status')),
            for (final s in ApplicationStatus.values)
              ListTile(
                title: Text(s.label),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (status == null || !context.mounted) return;
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Status → ${status.label}'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, noteController.text),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (note == null) return;
    try {
      await ref
          .read(applicationRepositoryProvider)
          .changeStatus(
            applicationId,
            status,
            note: note.trim().isEmpty ? null : note.trim(),
          );
      ref.invalidate(applicationDetailProvider(applicationId));
      ref.invalidate(applicationActivitiesProvider(applicationId));
      ref.invalidate(applicationsControllerProvider);
      ref.invalidate(dashboardProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String jobTitle,
    String companyName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Application?'),
        content: Text(
          'Are you sure you want to delete:\n\n'
          '$jobTitle\n$companyName\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(applicationRepositoryProvider)
          .deleteApplication(applicationId);
      ref.invalidate(applicationsControllerProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) context.go(RouteNames.applications);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete application')),
        );
      }
    }
  }
}

/// Phase 5/6: job-related emails and timeline for this application.
///
/// Read-only and clearly separated from the status timeline: a detected email
/// is a *suggestion*, and nothing here changes the application on its own. A
/// still-unresolved match is surfaced as a prompt to review it, never applied
/// silently.
class _EmailsSection extends ConsumerWidget {
  const _EmailsSection({required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(gmailThreadsProvider(applicationId));
    final timeline = ref.watch(gmailApplicationTimelineProvider(applicationId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Emails',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(
                Uri(
                  path: RouteNames.gmail,
                  queryParameters: {'applicationId': applicationId},
                ).toString(),
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        timeline.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (events) {
            if (events.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email timeline',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                for (final e in events.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.timeline, size: 20),
                    title: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (e.category != null)
                          e.category!.replaceAll('_', ' '),
                        if (e.occurredAt != null)
                          DateFormat.yMMMd().add_jm().format(e.occurredAt!),
                      ].join(' · '),
                    ),
                    onTap: e.threadId == null
                        ? null
                        : () => context.push(
                            RouteNames.gmailThreadDetailPath(e.threadId!),
                          ),
                  ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
        threads.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Text(
            'Unable to load emails',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'No job-related emails detected for this application',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: [
                for (final t in items.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      t.isUnresolved ? Icons.rule : Icons.mail_outline,
                      color: t.isUnresolved ? theme.colorScheme.tertiary : null,
                    ),
                    title: Text(
                      (t.subject ?? '').trim().isEmpty
                          ? 'Job-related email'
                          : t.subject!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      t.isUnresolved
                          ? 'Suggested match — not linked yet'
                          : t.lastMessageAt == null
                          ? 'Linked'
                          : DateFormat.yMMMd().add_jm().format(
                              t.lastMessageAt!,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      t.isUnresolved
                          ? RouteNames.gmailLinkPath(t.id)
                          : RouteNames.gmailThreadDetailPath(t.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
