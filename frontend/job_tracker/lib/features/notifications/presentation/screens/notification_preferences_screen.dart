import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/system_notification_settings.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../providers/notifications_providers.dart';

/// Per-category switches for every notification Phase 4/5 can send.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  NotificationPreferences? _draft;
  bool _saving = false;

  Future<void> _toggle(
    NotificationPreferences current,
    NotificationPreferences next,
  ) async {
    setState(() => _draft = next);
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(notificationRepositoryProvider)
          .updatePreferences(next);
      if (!mounted) return;
      setState(() => _draft = saved);
      ref.invalidate(notificationPreferencesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences saved')),
      );
    } catch (_) {
      if (!mounted) return;
      // Roll back to the last server-confirmed value rather than leaving the
      // UI showing a change that was not persisted.
      setState(() => _draft = current);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save preferences')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification preferences'),
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyView(title: 'Could not load preferences', message: '$error'),
        data: (prefs) {
          final current = _draft ?? prefs;
          return ListView(
            children: [
              const _PushStatusBanner(),
              const _SectionHeader('Reminders'),
              SwitchListTile(
                title: const Text('Interview reminders'),
                subtitle: const Text('24 hours and 1 hour before an interview'),
                value: current.interviewReminders,
                onChanged: (v) =>
                    _toggle(current, current.copyWith(interviewReminders: v)),
              ),
              SwitchListTile(
                title: const Text('Follow-up reminders'),
                subtitle: const Text('At the time you scheduled a follow-up'),
                value: current.followupReminders,
                onChanged: (v) =>
                    _toggle(current, current.copyWith(followupReminders: v)),
              ),
              SwitchListTile(
                title: const Text('Overdue follow-ups'),
                subtitle: const Text(
                  'Once, the day after a follow-up is missed',
                ),
                value: current.overdueFollowups,
                onChanged: (v) =>
                    _toggle(current, current.copyWith(overdueFollowups: v)),
              ),
              const Divider(height: 32),
              const _SectionHeader('Email intelligence'),
              SwitchListTile(
                title: const Text('Gmail notifications'),
                subtitle: const Text('When a job-related email is detected'),
                value: current.gmailNotifications,
                onChanged: (v) =>
                    _toggle(current, current.copyWith(gmailNotifications: v)),
              ),
              SwitchListTile(
                title: const Text('Application suggestions'),
                subtitle: const Text(
                  'Status and interview suggestions from your email',
                ),
                value: current.applicationSuggestions,
                onChanged: (v) => _toggle(
                  current,
                  current.copyWith(applicationSuggestions: v),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// Shows whether this device can currently receive push, and — crucially — the
/// only recovery route when the OS has stopped prompting.
class _PushStatusBanner extends ConsumerWidget {
  const _PushStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushRegistrationProvider);
    final theme = Theme.of(context);

    if (!push.isSupported) {
      return _Banner(
        color: theme.colorScheme.surfaceContainerHighest,
        icon: Icons.notifications_off_outlined,
        text: 'Push notifications are not available on this device.',
      );
    }
    if (push.registered) {
      return _Banner(
        color: theme.colorScheme.secondaryContainer,
        icon: Icons.notifications_active_outlined,
        text: 'This device will receive reminders.',
      );
    }
    if (push.requiresSettings) {
      return _Banner(
        color: theme.colorScheme.errorContainer,
        icon: Icons.lock_outline,
        text:
            'Notifications are blocked for this app. '
            'Enable them in your system settings to receive reminders.',
        action: TextButton.icon(
          onPressed: () => _openSettings(context, ref),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open settings'),
        ),
      );
    }
    return _Banner(
      color: theme.colorScheme.surfaceContainerHighest,
      icon: Icons.notifications_off_outlined,
      text: 'Push notifications are off for this device.',
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    final opened = await openSystemNotificationSettings();
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open system settings.')),
      );
      return;
    }
    // The user may have flipped the switch while they were away.
    await ref.read(pushRegistrationProvider.notifier).refreshPermission();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    this.action,
  });

  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          ?action,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
