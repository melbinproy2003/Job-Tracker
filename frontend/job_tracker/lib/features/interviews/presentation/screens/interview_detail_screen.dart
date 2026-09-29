import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/enums/interview_enums.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../providers/interviews_providers.dart';

class InterviewDetailScreen extends ConsumerWidget {
  const InterviewDetailScreen({super.key, required this.interviewId});

  final String interviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(interviewDetailProvider(interviewId));

    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Unable to load interview.',
          onRetry: () => ref.invalidate(interviewDetailProvider(interviewId)),
        ),
      ),
      data: (interview) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Interview'),
            actions: [
              IconButton(
                tooltip: 'Edit',
                onPressed: () =>
                    context.push(RouteNames.editInterviewPath(interviewId)),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (interview.companyName != null)
                Text(
                  interview.companyName!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (interview.jobTitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  interview.jobTitle!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                interview.displayTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Chip(label: Text(interview.status.label)),
              const SizedBox(height: 16),
              Text(DateFormat.yMMMMd().format(interview.scheduledAt)),
              Text(DateFormat.jm().format(interview.scheduledAt)),
              if (interview.durationMinutes != null)
                Text('${interview.durationMinutes} minutes'),
              const SizedBox(height: 20),
              if (interview.interviewerName != null &&
                  interview.interviewerName!.isNotEmpty) ...[
                Text(
                  'Interviewer',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(interview.interviewerName!),
                if (interview.interviewerEmail != null)
                  Text(interview.interviewerEmail!),
                const SizedBox(height: 16),
              ],
              if (interview.meetingUrl != null &&
                  interview.meetingUrl!.isNotEmpty) ...[
                Text(
                  'Meeting',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _openUrl(context, interview.meetingUrl!),
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Join Meeting'),
                ),
                const SizedBox(height: 16),
              ],
              if (interview.location != null &&
                  interview.location!.isNotEmpty) ...[
                Text(
                  'Location',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(interview.location!),
                const SizedBox(height: 16),
              ],
              if (interview.notes != null && interview.notes!.isNotEmpty) ...[
                Text(
                  'Notes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(interview.notes!),
                const SizedBox(height: 16),
              ],
              if (interview.status != InterviewStatus.completed)
                OutlinedButton(
                  onPressed: () => _markCompleted(context, ref),
                  child: const Text('Mark Completed'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open meeting link')),
      );
    }
  }

  Future<void> _markCompleted(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(interviewRepositoryProvider).update(interviewId, {
        'status': InterviewStatus.completed.apiValue,
        'force': true,
      });
      ref.invalidate(interviewDetailProvider(interviewId));
      ref.invalidate(interviewsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Update failed'),
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete interview?'),
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
      await ref.read(interviewRepositoryProvider).delete(interviewId);
      ref.invalidate(interviewsProvider);
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete interview')),
        );
      }
    }
  }
}
