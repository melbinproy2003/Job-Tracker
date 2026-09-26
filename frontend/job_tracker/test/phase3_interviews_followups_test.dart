import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/core/enums/interview_enums.dart';
import 'package:job_tracker/features/followups/domain/entities/follow_up.dart';
import 'package:job_tracker/features/followups/providers/followups_providers.dart';
import 'package:job_tracker/features/interviews/domain/entities/interview.dart';
import 'package:job_tracker/features/interviews/providers/interviews_providers.dart';

void main() {
  group('interview grouping', () {
    test('splits upcoming and past chronologically', () {
      final now = DateTime.now();
      final items = [
        Interview(
          id: '1',
          applicationId: 'a1',
          type: InterviewType.hrInterview,
          scheduledAt: now.subtract(const Duration(days: 2)),
          status: InterviewStatus.completed,
          title: 'Past HR',
          companyName: 'Acme',
        ),
        Interview(
          id: '2',
          applicationId: 'a1',
          type: InterviewType.technicalInterview,
          scheduledAt: now.add(const Duration(days: 2)),
          status: InterviewStatus.scheduled,
          title: 'Future Tech',
          companyName: 'Acme',
        ),
        Interview(
          id: '3',
          applicationId: 'a2',
          type: InterviewType.phoneScreen,
          scheduledAt: now.add(const Duration(days: 1)),
          status: InterviewStatus.scheduled,
          title: 'Soon Phone',
          companyName: 'Beta',
        ),
      ];

      final groups = groupInterviews(items);
      expect(groups.upcoming.map((e) => e.id), ['3', '2']);
      expect(groups.past.map((e) => e.id), ['1']);
    });

    test('type labels are friendly', () {
      expect(InterviewType.technicalInterview.label, 'Technical Interview');
      expect(InterviewType.systemDesign.label, 'System Design');
      expect(InterviewType.fromApi('PHONE_SCREEN'), InterviewType.phoneScreen);
    });
  });

  group('follow-up grouping', () {
    test('groups today tomorrow overdue and completed', () {
      final now = DateTime(2026, 9, 26, 12);
      final items = [
        FollowUp(
          id: '1',
          applicationId: 'a1',
          title: 'Overdue one',
          scheduledAt: now.subtract(const Duration(days: 2)),
          completed: false,
          isOverdue: true,
          companyName: 'ABC',
          jobTitle: 'Dev',
        ),
        FollowUp(
          id: '2',
          applicationId: 'a1',
          title: 'Today one',
          scheduledAt: DateTime(2026, 9, 26, 15),
          completed: false,
          isOverdue: false,
        ),
        FollowUp(
          id: '3',
          applicationId: 'a2',
          title: 'Tomorrow one',
          scheduledAt: DateTime(2026, 9, 27, 10),
          completed: false,
          isOverdue: false,
        ),
        FollowUp(
          id: '4',
          applicationId: 'a2',
          title: 'Done',
          scheduledAt: now.subtract(const Duration(days: 1)),
          completed: true,
          isOverdue: false,
          completedAt: now.subtract(const Duration(hours: 3)),
        ),
      ];

      final groups = groupFollowUps(items, now: now);
      expect(groups.overdue.map((e) => e.id), ['1']);
      expect(groups.today.map((e) => e.id), ['2']);
      expect(groups.tomorrow.map((e) => e.id), ['3']);
      expect(groups.completed.map((e) => e.id), ['4']);
    });
  });
}
