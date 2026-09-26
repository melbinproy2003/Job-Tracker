import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/application_status.dart';
import '../../data/datasources/application_api_datasource.dart';
import '../../domain/entities/application.dart';
import '../../domain/repositories/application_repository.dart';
import '../../providers/applications_providers.dart';

class ApplicationsFilterState extends Equatable {
  const ApplicationsFilterState({
    this.search = '',
    this.statuses = const {},
    this.sources = const {},
    this.employmentTypes = const {},
    this.location = '',
    this.sortBy = 'applied_at',
    this.sortOrder = 'desc',
  });

  final String search;
  final Set<ApplicationStatus> statuses;
  final Set<String> sources;
  final Set<String> employmentTypes;
  final String location;
  final String sortBy;
  final String sortOrder;

  ApplicationsFilterState copyWith({
    String? search,
    Set<ApplicationStatus>? statuses,
    Set<String>? sources,
    Set<String>? employmentTypes,
    String? location,
    String? sortBy,
    String? sortOrder,
  }) {
    return ApplicationsFilterState(
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      sources: sources ?? this.sources,
      employmentTypes: employmentTypes ?? this.employmentTypes,
      location: location ?? this.location,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
    search,
    statuses,
    sources,
    employmentTypes,
    location,
    sortBy,
    sortOrder,
  ];
}

class ApplicationsListState extends Equatable {
  const ApplicationsListState({
    this.items = const [],
    this.page = 1,
    this.total = 0,
    this.hasNext = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.filters = const ApplicationsFilterState(),
  });

  final List<Application> items;
  final int page;
  final int total;
  final bool hasNext;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final ApplicationsFilterState filters;

  ApplicationsListState copyWith({
    List<Application>? items,
    int? page,
    int? total,
    bool? hasNext,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    ApplicationsFilterState? filters,
    bool clearError = false,
  }) {
    return ApplicationsListState(
      items: items ?? this.items,
      page: page ?? this.page,
      total: total ?? this.total,
      hasNext: hasNext ?? this.hasNext,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      filters: filters ?? this.filters,
    );
  }

  @override
  List<Object?> get props => [
    items,
    page,
    total,
    hasNext,
    isLoading,
    isLoadingMore,
    errorMessage,
    filters,
  ];
}

class ApplicationsController extends StateNotifier<ApplicationsListState> {
  ApplicationsController(this._repository)
    : super(const ApplicationsListState(isLoading: true)) {
    refresh();
  }

  final ApplicationRepository _repository;
  Timer? _debounce;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 1);
    try {
      final result = await _repository.getApplications(_query(page: 1));
      state = state.copyWith(
        items: result.items,
        page: result.page,
        total: result.total,
        hasNext: result.hasNext,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load applications.',
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasNext || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _repository.getApplications(_query(page: nextPage));
      state = state.copyWith(
        items: [...state.items, ...result.items],
        page: result.page,
        total: result.total,
        hasNext: result.hasNext,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearch(String value) {
    _debounce?.cancel();
    state = state.copyWith(filters: state.filters.copyWith(search: value));
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  void applyFilters(ApplicationsFilterState filters) {
    state = state.copyWith(filters: filters);
    refresh();
  }

  void setSort(String sortBy, String sortOrder) {
    state = state.copyWith(
      filters: state.filters.copyWith(sortBy: sortBy, sortOrder: sortOrder),
    );
    refresh();
  }

  ApplicationListQuery _query({required int page}) {
    final f = state.filters;
    return ApplicationListQuery(
      search: f.search,
      statuses: f.statuses.isEmpty ? null : f.statuses.toList(),
      sources: f.sources.isEmpty ? null : f.sources.toList(),
      employmentTypes: f.employmentTypes.isEmpty
          ? null
          : f.employmentTypes.toList(),
      location: f.location,
      sortBy: f.sortBy,
      sortOrder: f.sortOrder,
      page: page,
      pageSize: 20,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final applicationsControllerProvider =
    StateNotifierProvider.autoDispose<
      ApplicationsController,
      ApplicationsListState
    >(
      (ref) => ApplicationsController(ref.watch(applicationRepositoryProvider)),
    );
