import '../../domain/entities/interview.dart';
import '../../domain/repositories/interviews_repository.dart';
import '../datasources/interviews_remote_datasource.dart';

class InterviewRepositoryImpl implements InterviewRepository {
  InterviewRepositoryImpl(this._remote);
  final InterviewRemoteDataSource _remote;

  @override
  Future<List<Interview>> getAll([
    InterviewListQuery query = const InterviewListQuery(),
  ]) => _remote.list(query);

  @override
  Future<List<Interview>> getForApplication(String applicationId) =>
      _remote.listForApplication(applicationId);

  @override
  Future<Interview> getById(String id) => _remote.getById(id);

  @override
  Future<Interview> create(String applicationId, Map<String, dynamic> body) =>
      _remote.create(applicationId, body);

  @override
  Future<Interview> update(String id, Map<String, dynamic> body) =>
      _remote.update(id, body);

  @override
  Future<void> delete(String id) => _remote.delete(id);
}
