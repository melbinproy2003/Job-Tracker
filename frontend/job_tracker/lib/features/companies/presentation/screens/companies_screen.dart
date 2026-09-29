import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../providers/companies_providers.dart';

class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companiesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Companies')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(RouteNames.addCompany);
          ref.invalidate(companiesListProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Unable to load companies.',
          onRetry: () => ref.invalidate(companiesListProvider),
        ),
        data: (companies) {
          if (companies.isEmpty) {
            return const EmptyView(message: 'No companies added yet.');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(companiesListProvider),
            child: ListView.separated(
              itemCount: companies.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = companies[index];
                final countLabel = c.applicationCount == 1
                    ? '1 Application'
                    : '${c.applicationCount} Applications';
                return ListTile(
                  title: Text(c.name),
                  subtitle: Text(countLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.companyDetailPath(c.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
