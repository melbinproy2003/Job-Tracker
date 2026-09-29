import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../followups/data/datasources/followups_remote_datasource.dart';
import '../../followups/domain/entities/follow_up.dart';
import '../../followups/providers/followups_providers.dart';
import '../../interviews/domain/entities/interview.dart';
import '../../interviews/providers/interviews_providers.dart';

class UpcomingItem {
  UpcomingItem._({required this.scheduledAt, this.interview, this.followUp});

  factory UpcomingItem.interview(Interview interview) {
    return UpcomingItem._(
      interview: interview,
      scheduledAt: interview.scheduledAt,
    );
  }

  factory UpcomingItem.followUp(FollowUp followUp) {
    return UpcomingItem._(
      followUp: followUp,
      scheduledAt: followUp.scheduledAt,
    );
  }

  final Interview? interview;
  final FollowUp? followUp;
  final DateTime scheduledAt;

  bool get isInterview => interview != null;
  String get id => interview?.id ?? followUp!.id;
  String get title => interview?.displayTitle ?? followUp!.title;
  String? get companyName => interview?.companyName ?? followUp?.companyName;
  String? get jobTitle => interview?.jobTitle ?? followUp?.jobTitle;
}

final upcomingItemsProvider = FutureProvider.autoDispose<List<UpcomingItem>>((
  ref,
) async {
  final now = DateTime.now();
  final interviews = await ref.watch(interviewRepositoryProvider).getAll();
  final followups = await ref
      .watch(followUpRepositoryProvider)
      .getAll(const FollowUpListQuery(completed: false));

  final items = <UpcomingItem>[
    for (final i in interviews)
      if (i.isUpcoming && !i.scheduledAt.isBefore(now))
        UpcomingItem.interview(i),
    for (final f in followups)
      if (!f.completed && !f.scheduledAt.isBefore(now))
        UpcomingItem.followUp(f),
  ];

  items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return items;
});
