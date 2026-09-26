import '../../domain/entities/gmail_thread.dart';
import '../../domain/repositories/gmail_repository.dart';
import '../datasources/gmail_remote_datasource.dart';

class GmailRepositoryImpl implements GmailRepository {
  GmailRepositoryImpl(this._remote);
  final GmailRemoteDataSource _remote;

  @override
  Future<List<GmailAccount>> getAccounts() => _remote.listAccounts();

  @override
  Future<String> getConnectUrl() => _remote.getConnectUrl();

  @override
  Future<GmailSyncResult> sync({bool fullSync = false}) =>
      _remote.sync(fullSync: fullSync);

  @override
  Future<List<GmailThread>> getThreads({String? applicationId}) =>
      _remote.listThreads(applicationId: applicationId);

  @override
  Future<GmailThread> getThread(String threadId) => _remote.getThread(threadId);

  @override
  Future<GmailMessage> getMessage(String messageId) =>
      _remote.getMessage(messageId);

  @override
  Future<GmailMatchResult> confirmMatch(
    String threadId,
    GmailMatchConfirm confirm,
  ) => _remote.confirmMatch(threadId, confirm);

  @override
  Future<GmailMatchResult> ignoreMatch(String threadId) =>
      _remote.ignoreMatch(threadId);

  @override
  Future<void> disconnect(String accountId) => _remote.disconnect(accountId);
}
