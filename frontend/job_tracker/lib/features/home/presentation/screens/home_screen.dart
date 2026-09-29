import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';

/// Phase 2 temporary home — navigation hub (full dashboard later).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final name = auth.user?.displayName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Tracker'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome${name != null && name.isNotEmpty ? ', $name' : ''}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Job Application Tracker',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push(RouteNames.applications),
              icon: const Icon(Icons.work_outline),
              label: const Text('Applications'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(RouteNames.companies),
              icon: const Icon(Icons.business_outlined),
              label: const Text('Companies'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.push(RouteNames.addApplication),
              icon: const Icon(Icons.add),
              label: const Text('Add Application'),
            ),
          ],
        ),
      ),
    );
  }
}
