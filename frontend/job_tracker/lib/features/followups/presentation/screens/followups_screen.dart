import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../domain/entities/follow_up.dart';
import '../../providers/followups_providers.dart';
import '../widgets/followup_card.dart';

class FollowUpsScreen extends ConsumerWidget {
  const FollowUpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(followupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Follow-ups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.addFollowup),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Unable to load follow-ups.',
          onRetry: () => ref.invalidate(followupsProvider),
        ),
        data: (groups) {
          final empty =
              groups.today.isEmpty &&
              groups.tomorrow.isEmpty &&
              groups.overdue.isEmpty &&
              groups.later.isEmpty &&
              groups.completed.isEmpty;
          if (empty) {
            return const EmptyView(
              title: 'No follow-ups yet',
              message: 'Create a reminder to follow up on an application.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(followupsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                _section(context, ref, 'Overdue', groups.overdue),
                _section(context, ref, 'Today', groups.today),
                _section(context, ref, 'Tomorrow', groups.tomorrow),
                _section(context, ref, 'Upcoming', groups.later),
                _section(context, ref, 'Completed', groups.completed),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<FollowUp> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Divider(),
        for (final f in items)
          FollowUpCard(
            followUp: f,
            onComplete: () => _complete(context, ref, f),
            onUndo: () => _undo(context, ref, f),
            onEdit: () => context.push(RouteNames.editFollowupPath(f.id)),
            onDelete: () => _delete(context, ref, f),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    FollowUp f,
  ) async {
    try {
      await ref.read(followUpRepositoryProvider).complete(f.id);
      ref.invalidate(followupsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(applicationFollowupsProvider(f.applicationId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Failed')),
        );
      }
    }
  }

  Future<void> _undo(BuildContext context, WidgetRef ref, FollowUp f) async {
    try {
      await ref.read(followUpRepositoryProvider).update(f.id, {
        'completed': false,
      });
      ref.invalidate(followupsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(applicationFollowupsProvider(f.applicationId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Failed')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FollowUp f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete follow-up?'),
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
    if (ok != true) return;
    try {
      await ref.read(followUpRepositoryProvider).delete(f.id);
      ref.invalidate(followupsProvider);
      ref.invalidate(dashboardProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete')));
      }
    }
  }
}
