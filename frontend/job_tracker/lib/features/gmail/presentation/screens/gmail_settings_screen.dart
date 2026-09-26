import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/errors/api_exception.dart';
import '../../providers/gmail_providers.dart';
import '../widgets/gmail_connection_card.dart';

/// Settings → Email Integration → Gmail (Phase 5).
///
/// Owns the browser hand-off for the backend-controlled OAuth flow. The app
/// never receives a token; Google redirects straight to the FastAPI callback.
class GmailSettingsScreen extends ConsumerStatefulWidget {
  const GmailSettingsScreen({super.key});

  @override
  ConsumerState<GmailSettingsScreen> createState() =>
      _GmailSettingsScreenState();
}

class _GmailSettingsScreenState extends ConsumerState<GmailSettingsScreen> {
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      final url = await ref.read(gmailRepositoryProvider).getConnectUrl();
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _toast('Could not open the browser.');
        return;
      }
      // The browser leaves the app; on return the account list is re-read so
      // the connected state (or the failure) is reflected.
      _toast('Complete the Google consent screen, then return here.');
    } on ApiException catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast('Could not start the Gmail connection.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect(String accountId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Gmail?'),
        content: const Text(
          'Your applications, status history and notes are kept. '
          'Detected emails stay linked, but no new mail will be synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(gmailRepositoryProvider).disconnect(accountId);
      ref.invalidate(gmailAccountsProvider);
      ref.invalidate(isGmailConnectedProvider);
      ref.invalidate(gmailThreadsProvider);
      if (mounted) _toast('Gmail disconnected');
    } catch (_) {
      if (mounted) _toast('Could not disconnect Gmail.');
    }
  }

  Future<void> _sync() async {
    final ok = await ref.read(gmailSyncControllerProvider.notifier).sync();
    ref.invalidate(gmailAccountsProvider);
    if (ok) {
      ref.invalidate(gmailThreadsProvider);
      if (mounted) _toast('Sync completed');
    } else if (mounted) {
      _toast('Sync failed. Try again later.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final syncing = ref.watch(gmailSyncControllerProvider).syncing;
    final account = ref.watch(gmailAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Gmail Integration')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(gmailAccountsProvider),
        child: ListView(
          children: [
            if (_connecting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GmailConnectionCard(
                syncing: syncing,
                onConnect: _connect,
                onDisconnect: account == null
                    ? null
                    : () => _disconnect(account.id),
                onSync: _sync,
              ),
            const GmailSyncSummary(),
            if (account?.connected ?? false) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push(RouteNames.gmail),
                    icon: const Icon(Icons.inbox, size: 18),
                    label: const Text('View job-related emails'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const _PrivacyNote(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gmail access is read-only and limited to detecting job emails. '
              'This app cannot send, delete or modify your mail. Access tokens '
              'are held by the server and never reach this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
