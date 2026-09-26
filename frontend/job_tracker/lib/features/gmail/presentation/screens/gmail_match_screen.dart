import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/enums/application_status.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../../applications/presentation/controllers/applications_controller.dart';
import '../../../notifications/providers/notifications_providers.dart';
import '../../domain/repositories/gmail_repository.dart';
import '../../providers/gmail_providers.dart';
import '../widgets/application_match_card.dart';
import '../widgets/gmail_thread_card.dart';

/// Resolve a suggested match: link, apply a status, add an interview, or
/// ignore. Every mutation is explicit.
class GmailMatchScreen extends ConsumerStatefulWidget {
  const GmailMatchScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<GmailMatchScreen> createState() => _GmailMatchScreenState();
}

class _GmailMatchScreenState extends ConsumerState<GmailMatchScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(gmailMatchControllerProvider.notifier).reset();
  }

  Future<void> _confirm({
    required String applicationId,
    ApplicationStatus? status,
    required bool createInterview,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final thread = await ref.read(
      gmailThreadDetailProvider(widget.threadId).future,
    );
    final interview = thread.interviewSuggestion;

    final ok = await ref
        .read(gmailMatchControllerProvider.notifier)
        .confirm(
          widget.threadId,
          GmailMatchConfirm(
            applicationId: applicationId,
            status: status?.apiValue,
            interview: createInterview && interview?.scheduledAt != null
                ? InterviewDraft(
                    type: interview!.type,
                    title: interview.title,
                    scheduledAt: interview.scheduledAt!,
                    durationMinutes: interview.durationMinutes ?? 60,
                    meetingUrl: interview.meetingUrl,
                    interviewerName: interview.interviewerName,
                  )
                : null,
          ),
        );

    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not link this email.')),
      );
      return;
    }

    _invalidateGmail(applicationId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          status == null && !createInterview
              ? 'Email linked to application'
              : 'Email linked and updated',
        ),
      ),
    );
    router.go(RouteNames.applicationDetailPath(applicationId));
  }

  Future<void> _ignore() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(gmailMatchControllerProvider.notifier)
        .ignore(widget.threadId);
    if (!mounted) return;
    if (ok) {
      _invalidateGmail(null);
      messenger.showSnackBar(const SnackBar(content: Text('Match ignored')));
      context.go(RouteNames.gmail);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not ignore this match.')),
      );
    }
  }

  void _invalidateGmail(String? applicationId) {
    ref.invalidate(gmailThreadDetailProvider(widget.threadId));
    ref.invalidate(gmailThreadsProvider(applicationId));
    ref.invalidate(notificationListProvider);
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(gmailThreadDetailProvider(widget.threadId));
    final matchState = ref.watch(gmailMatchControllerProvider);
    // The matcher works off the user's applications, so the choice list comes
    // from the same (already cached) application list the rest of the app uses.
    final applications = ref.watch(applicationsControllerProvider).items;

    return Scaffold(
      appBar: AppBar(title: const Text('Match email')),
      body: threadAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'Could not load this thread.',
          onRetry: () =>
              ref.invalidate(gmailThreadDetailProvider(widget.threadId)),
        ),
        data: (thread) {
          return ListView(
            children: [
              GmailThreadCard(thread: thread),
              ApplicationMatchCard(
                thread: thread,
                candidates: applications,
                busy: matchState.isBusy(thread.id),
                onConfirm: _confirm,
                onIgnore: _ignore,
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
