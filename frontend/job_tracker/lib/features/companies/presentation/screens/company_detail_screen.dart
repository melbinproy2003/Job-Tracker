import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../providers/companies_providers.dart';

class CompanyDetailScreen extends ConsumerWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyDetailProvider(companyId));

    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Unable to load company.',
          onRetry: () => ref.invalidate(companyDetailProvider(companyId)),
        ),
      ),
      data: (company) => Scaffold(
        appBar: AppBar(
          title: Text(company.name),
          actions: [
            IconButton(
              onPressed: () async {
                await context.push(RouteNames.editCompanyPath(companyId));
                ref.invalidate(companyDetailProvider(companyId));
                ref.invalidate(companiesListProvider);
              },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => _delete(context, ref, company.applicationCount),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (company.website != null) _row('Website', company.website!),
            if (company.location != null) _row('Location', company.location!),
            if (company.industry != null) _row('Industry', company.industry!),
            if (company.notes != null) _row('Notes', company.notes!),
            const SizedBox(height: 16),
            Text(
              'Applications',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (company.applications.isEmpty)
              const Text('No applications for this company yet.')
            else
              ...company.applications.map(
                (a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.jobTitle),
                  subtitle: Text(a.status ?? ''),
                  onTap: () =>
                      context.push(RouteNames.applicationDetailPath(a.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
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

  Future<void> _delete(BuildContext context, WidgetRef ref, int count) async {
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot delete company'),
          content: Text(
            'This company has $count applications.\n\n'
            'Delete or reassign those applications first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete company?'),
        content: const Text('This action cannot be undone.'),
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
      await ref.read(companyRepositoryProvider).delete(companyId);
      ref.invalidate(companiesListProvider);
      if (context.mounted) context.go(RouteNames.companies);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete company')),
        );
      }
    }
  }
}
