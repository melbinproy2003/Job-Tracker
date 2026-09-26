/// Future-ready offline sync orchestrator.
///
/// Architecture (Phase 4):
/// UI → Riverpod → Repository → Local SQLite → SyncEngine → FastAPI → Firestore
///
/// This class is intentionally unimplemented until Phase 4.
class SyncEngine {
  Future<void> pushPendingChanges() async {
    throw UnimplementedError(
      'SyncEngine.pushPendingChanges not implemented yet',
    );
  }

  Future<void> pullRemoteChanges() async {
    throw UnimplementedError(
      'SyncEngine.pullRemoteChanges not implemented yet',
    );
  }
}
