import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../gmail/providers/gmail_providers.dart';
import '../../../notifications/domain/services/device_registration_controller.dart';
import '../../../notifications/providers/notifications_providers.dart';

/// Settings hub.
///
/// Deliberately limited to what Phases 4 and 5 add: push notification
/// preferences and the Gmail connection. Anything else belongs to a later
/// phase rather than being invented here.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final push = ref.watch(pushRegistrationProvider);
    final gmail = ref.watch(isGmailConnectedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (auth.user != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(auth.user!.displayName ?? 'Account'),
              subtitle: Text(auth.user!.email ?? ''),
            ),
          const Divider(height: 24),

          const _SectionLabel('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification preferences'),
            subtitle: Text(_pushSubtitle(push)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouteNames.notificationPreferences),
          ),

          const Divider(height: 24),

          const _SectionLabel('Email'),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Gmail integration'),
            subtitle: Text(
              gmail.valueOrNull == true
                  ? 'Connected — job emails are being detected'
                  : 'Not connected',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouteNames.settingsEmail),
          ),

          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _pushSubtitle(PushRegistrationState state) {
    if (!state.isSupported) return 'Not available on this device';
    if (state.registered) return 'Push notifications are on';
    if (state.requiresSettings) return 'Blocked in system settings';
    return 'Push notifications are off';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
