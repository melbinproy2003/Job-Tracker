import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../data/datasources/activity_remote_datasource.dart';
import '../domain/entities/activity.dart';

final activityRemoteDataSourceProvider = Provider<ActivityRemoteDataSource>((
  ref,
) {
  return ActivityRemoteDataSource(ref.watch(dioProvider));
});

final applicationActivitiesProvider = FutureProvider.autoDispose
    .family<List<Activity>, String>((ref, appId) async {
      return ref
          .watch(activityRemoteDataSourceProvider)
          .listForApplication(appId);
    });
