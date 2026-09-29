import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/gmail_remote_datasource.dart';
import '../data/repositories/gmail_repository_impl.dart';
import '../domain/entities/gmail_thread.dart';
import '../domain/repositories/gmail_repository.dart';

final gmailRemoteDataSourceProvider = Provider<GmailRemoteDataSource>((ref) {
  return GmailRemoteDataSource(ref.watch(dioProvider));
});

final gmailRepositoryProvider = Provider<GmailRepository>((ref) {
  return GmailRepositoryImpl(ref.watch(gmailRemoteDataSourceProvider));
});

/// Connected Gmail accounts. Empty until the user completes OAuth.
final gmailAccountsProvider = FutureProvider.autoDispose<List<GmailAccount>>((
  ref,
) {
  return ref.watch(gmailRepositoryProvider).getAccounts();
});

/// The first connected account, or null when Gmail is not linked.
final gmailAccountProvider = FutureProvider.autoDispose<GmailAccount?>((
  ref,
) async {
  final accounts = await ref.watch(gmailAccountsProvider.future);
  for (final account in accounts) {
    if (account.connected) return account;
  }
  return accounts.isEmpty ? null : accounts.first;
});

final isGmailConnectedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final account = await ref.watch(gmailAccountProvider.future);
  return account?.connected ?? false;
});

/// Job-related threads, newest first.
final gmailThreadsProvider = FutureProvider.autoDispose
    .family<List<GmailThread>, String?>((ref, applicationId) {
      return ref
          .watch(gmailRepositoryProvider)
          .getThreads(applicationId: applicationId);
    });

final gmailThreadDetailProvider = FutureProvider.autoDispose
    .family<GmailThread, String>((ref, threadId) {
      return ref.watch(gmailRepositoryProvider).getThread(threadId);
    });

final gmailMessageDetailProvider = FutureProvider.autoDispose
    .family<GmailMessage, String>((ref, messageId) {
      return ref.watch(gmailRepositoryProvider).getMessage(messageId);
    });

final gmailApplicationTimelineProvider = FutureProvider.autoDispose
    .family<List<GmailTimelineEvent>, String>((ref, applicationId) {
      return ref
          .watch(gmailRepositoryProvider)
          .getApplicationTimeline(applicationId);
    });

/// Drives manual Gmail sync.
///
/// Concurrency is guarded client-side as well as server-side: a sync can take
/// many seconds, and a double-tap must not start two overlapping runs.
class GmailSyncController extends StateNotifier<GmailSyncState> {
  GmailSyncController(this._repository) : super(const GmailSyncState());

  final GmailRepository _repository;

  Future<bool> sync({bool fullSync = false}) async {
    if (state.syncing) return false;
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final result = await _repository.sync(fullSync: fullSync);
      state = GmailSyncState(
        syncing: false,
        lastResult: result,
        lastSyncedAt: result.lastSyncAt,
      );
      return true;
    } catch (error) {
      debugPrint('Gmail sync failed: ${error.runtimeType}');
      // A failed sync never mutates stored data, so there is nothing to undo;
      // the user is simply told to retry.
      state = state.copyWith(syncing: false, error: error);
      return false;
    }
  }
}

class GmailSyncState {
  const GmailSyncState({
    this.syncing = false,
    this.lastResult,
    this.lastSyncedAt,
    this.error,
  });

  final bool syncing;
  final GmailSyncResult? lastResult;
  final DateTime? lastSyncedAt;
  final Object? error;

  bool get hasError => error != null;

  GmailSyncState copyWith({
    bool? syncing,
    GmailSyncResult? lastResult,
    DateTime? lastSyncedAt,
    Object? error,
    bool clearError = false,
  }) {
    return GmailSyncState(
      syncing: syncing ?? this.syncing,
      lastResult: lastResult ?? this.lastResult,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final gmailSyncControllerProvider =
    StateNotifierProvider<GmailSyncController, GmailSyncState>((ref) {
      return GmailSyncController(ref.watch(gmailRepositoryProvider));
    });

/// Resolves suggested matches. Every mutation here is an explicit user action.
class GmailMatchController extends StateNotifier<GmailMatchState> {
  GmailMatchController(this._repository) : super(const GmailMatchState());

  final GmailRepository _repository;

  /// Links the thread to an application. Status and interview creation only
  /// happen when [confirm] carries them.
  ///
  /// Returns the server result on success (including conflict flags), or null
  /// on failure / busy.
  Future<GmailMatchResult?> confirm(
    String threadId,
    GmailMatchConfirm confirm,
  ) async {
    if (state.busyThreadId != null) return null;
    state = GmailMatchState(busyThreadId: threadId);
    try {
      final result = await _repository.confirmMatch(threadId, confirm);
      state = GmailMatchState(lastResult: result, succeededThreadId: threadId);
      return result;
    } catch (error) {
      debugPrint('Match confirmation failed: ${error.runtimeType}');
      state = GmailMatchState(
        failedThreadId: threadId,
        error: error,
        busyThreadId: null,
      );
      return null;
    }
  }

  Future<bool> ignore(String threadId) async {
    if (state.busyThreadId != null) return false;
    state = GmailMatchState(busyThreadId: threadId);
    try {
      final result = await _repository.ignoreMatch(threadId);
      state = GmailMatchState(lastResult: result, succeededThreadId: threadId);
      return true;
    } catch (error) {
      debugPrint('Match ignore failed: ${error.runtimeType}');
      state = GmailMatchState(
        failedThreadId: threadId,
        error: error,
        busyThreadId: null,
      );
      return false;
    }
  }

  Future<bool> unlink(String threadId) async {
    if (state.busyThreadId != null) return false;
    state = GmailMatchState(busyThreadId: threadId);
    try {
      final result = await _repository.unlinkMatch(threadId);
      state = GmailMatchState(lastResult: result, succeededThreadId: threadId);
      return true;
    } catch (error) {
      debugPrint('Match unlink failed: ${error.runtimeType}');
      state = GmailMatchState(
        failedThreadId: threadId,
        error: error,
        busyThreadId: null,
      );
      return false;
    }
  }

  void reset() => state = const GmailMatchState();
}

class GmailMatchState {
  const GmailMatchState({
    this.busyThreadId,
    this.succeededThreadId,
    this.failedThreadId,
    this.lastResult,
    this.error,
  });

  final String? busyThreadId;
  final String? succeededThreadId;
  final String? failedThreadId;
  final GmailMatchResult? lastResult;
  final Object? error;

  bool isBusy(String threadId) => busyThreadId == threadId;
}

final gmailMatchControllerProvider =
    StateNotifierProvider<GmailMatchController, GmailMatchState>((ref) {
      return GmailMatchController(ref.watch(gmailRepositoryProvider));
    });
