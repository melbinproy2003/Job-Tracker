import '../entities/interview.dart';
import '../../data/datasources/interviews_remote_datasource.dart';

abstract class InterviewRepository {
  Future<List<Interview>> getAll([InterviewListQuery query]);
  Future<List<Interview>> getForApplication(String applicationId);
  Future<Interview> getById(String id);
  Future<Interview> create(String applicationId, Map<String, dynamic> body);
  Future<Interview> update(String id, Map<String, dynamic> body);
  Future<void> delete(String id);
}
