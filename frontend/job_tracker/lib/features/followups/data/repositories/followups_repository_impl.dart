import '../../domain/entities/follow_up.dart';
import '../../domain/repositories/followups_repository.dart';
import '../datasources/followups_remote_datasource.dart';

class FollowUpRepositoryImpl implements FollowUpRepository {
  FollowUpRepositoryImpl(this._remote);
  final FollowUpRemoteDataSource _remote;

  @override
  Future<List<FollowUp>> getAll([
    FollowUpListQuery query = const FollowUpListQuery(),
  ]) => _remote.list(query);

  @override
  Future<FollowUp> getById(String id) => _remote.getById(id);

  @override
  Future<FollowUp> create(Map<String, dynamic> body) => _remote.create(body);

  @override
  Future<FollowUp> update(String id, Map<String, dynamic> body) =>
      _remote.update(id, body);

  @override
  Future<FollowUp> complete(String id) => _remote.complete(id);

  @override
  Future<void> delete(String id) => _remote.delete(id);
}
