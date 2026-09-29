import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/core/enums/application_status.dart';
import 'package:job_tracker/features/applications/presentation/controllers/applications_controller.dart';
import 'package:job_tracker/features/applications/presentation/widgets/application_status_presentation.dart';

void main() {
  test('status labels are human friendly', () {
    expect(ApplicationStatus.technicalRound.label, 'Technical Round');
    expect(ApplicationStatus.hrCall.label, 'HR Call');
    expect(ApplicationStatus.noResponse.label, 'No Response');
    expect(ApplicationStatus.fromApi('APPLIED'), ApplicationStatus.applied);
  });

  test('status presentation provides label and color', () {
    final p = ApplicationStatusPresentation.of(ApplicationStatus.offer);
    expect(p.label, 'Offer');
    expect(p.icon, isNotNull);
  });

  test('filter state copyWith preserves search', () {
    const state = ApplicationsFilterState(search: 'python');
    final next = state.copyWith(statuses: {ApplicationStatus.applied});
    expect(next.search, 'python');
    expect(next.statuses, contains(ApplicationStatus.applied));
  });
}
