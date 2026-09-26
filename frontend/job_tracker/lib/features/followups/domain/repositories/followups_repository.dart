import '../entities/follow_up.dart';
import '../../data/datasources/followups_remote_datasource.dart';

abstract class FollowUpRepository {
  Future<List<FollowUp>> getAll([FollowUpListQuery query]);
  Future<FollowUp> getById(String id);
  Future<FollowUp> create(Map<String, dynamic> body);
  Future<FollowUp> update(String id, Map<String, dynamic> body);
  Future<FollowUp> complete(String id);
  Future<void> delete(String id);
}
