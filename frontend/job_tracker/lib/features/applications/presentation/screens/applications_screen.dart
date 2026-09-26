import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/enums/application_status.dart';
import '../../../../shared/empty_states/empty_view.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../controllers/applications_controller.dart';
import '../widgets/application_card.dart';

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(applicationsControllerProvider);
    final controller = ref.read(applicationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        actions: [
          IconButton(
            tooltip: 'Sort',
            onPressed: () => _showSort(context, ref),
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            tooltip: 'Filter',
            onPressed: () => _showFilters(context, ref),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.addApplication),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: controller.setSearch,
              decoration: InputDecoration(
                hintText: 'Search company, role, location',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(child: _body(context, state, controller)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ApplicationsListState state,
    ApplicationsController controller,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const LoadingView();
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return ErrorView(
        message: state.errorMessage!,
        onRetry: controller.refresh,
      );
    }
    if (state.items.isEmpty) {
      final hasQuery =
          state.filters.search.trim().isNotEmpty ||
          state.filters.statuses.isNotEmpty;
      if (hasQuery) {
        return const EmptyView(
          message:
              'No applications found.\nTry changing your search or filters.',
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyView(
                message:
                    'No job applications yet.\n\nStart tracking your job search by adding your first application.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push(RouteNames.addApplication),
                child: const Text('Add Application'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
            controller.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          itemCount: state.items.length + (state.hasNext ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final app = state.items[index];
            return ApplicationCard(
              application: app,
              onTap: () =>
                  context.push(RouteNames.applicationDetailPath(app.id)),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showSort(BuildContext context, WidgetRef ref) async {
    final current = ref.read(applicationsControllerProvider).filters;
    final choice = await showModalBottomSheet<Map<String, String>>(
      context: context,
      builder: (context) {
        final options = <(String, String, String)>[
          ('Newest Applied', 'applied_at', 'desc'),
          ('Oldest Applied', 'applied_at', 'asc'),
          ('Recently Updated', 'updated_at', 'desc'),
          ('Oldest Updated', 'updated_at', 'asc'),
          ('Company A-Z', 'company_name', 'asc'),
          ('Company Z-A', 'company_name', 'desc'),
          ('Job Title A-Z', 'job_title', 'asc'),
          ('Job Title Z-A', 'job_title', 'desc'),
        ];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Sort by')),
              for (final o in options)
                ListTile(
                  title: Text(o.$1),
                  trailing: current.sortBy == o.$2 && current.sortOrder == o.$3
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, {
                    'sortBy': o.$2,
                    'sortOrder': o.$3,
                  }),
                ),
            ],
          ),
        );
      },
    );
    if (choice != null) {
      ref
          .read(applicationsControllerProvider.notifier)
          .setSort(choice['sortBy']!, choice['sortOrder']!);
    }
  }

  Future<void> _showFilters(BuildContext context, WidgetRef ref) async {
    final current = ref.read(applicationsControllerProvider).filters;
    final selected = Set<ApplicationStatus>.from(current.statuses);
    final sources = Set<String>.from(current.sources);
    final types = Set<String>.from(current.employmentTypes);

    final result = await showModalBottomSheet<ApplicationsFilterState>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text('Status'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in ApplicationStatus.values)
                            FilterChip(
                              label: Text(s.label),
                              selected: selected.contains(s),
                              onSelected: (v) {
                                setModalState(() {
                                  if (v) {
                                    selected.add(s);
                                  } else {
                                    selected.remove(s);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Source'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in const [
                            'LinkedIn',
                            'Indeed',
                            'Naukri',
                            'Company Website',
                            'Glassdoor',
                            'Referral',
                            'Foundit',
                            'Other',
                          ])
                            FilterChip(
                              label: Text(s),
                              selected: sources.contains(s),
                              onSelected: (v) {
                                setModalState(() {
                                  if (v) {
                                    sources.add(s);
                                  } else {
                                    sources.remove(s);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Employment type'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in const [
                            'Full-time',
                            'Part-time',
                            'Contract',
                            'Internship',
                            'Freelance',
                            'Other',
                          ])
                            FilterChip(
                              label: Text(s),
                              selected: types.contains(s),
                              onSelected: (v) {
                                setModalState(() {
                                  if (v) {
                                    types.add(s);
                                  } else {
                                    types.remove(s);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                current.copyWith(
                                  statuses: {},
                                  sources: {},
                                  employmentTypes: {},
                                ),
                              );
                            },
                            child: const Text('Clear'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                current.copyWith(
                                  statuses: selected,
                                  sources: sources,
                                  employmentTypes: types,
                                ),
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      ref.read(applicationsControllerProvider.notifier).applyFilters(result);
    }
  }
}
