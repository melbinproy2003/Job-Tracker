import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/core/enums/application_status.dart';
import 'package:job_tracker/core/errors/api_exception.dart';
import 'package:job_tracker/features/applications/domain/entities/application.dart';
import 'package:job_tracker/features/gmail/domain/entities/gmail_thread.dart';
import 'package:job_tracker/features/gmail/domain/repositories/gmail_repository.dart';
import 'package:job_tracker/features/gmail/presentation/widgets/application_match_card.dart';
import 'package:job_tracker/features/gmail/presentation/widgets/gmail_thread_card.dart';

GmailThread _thread({
  GmailMatchStatus matchStatus = GmailMatchStatus.suggested,
  String? suggestedStatus = 'SHORTLISTED',
  int? confidence = 85,
  InterviewSuggestion? interview,
  String? applicationId,
}) {
  return GmailThread(
    id: 't1',
    gmailThreadId: 'gt1',
    subject: 'Interview schedule — Acme',
    snippet: 'We would like to schedule a technical round.',
    isJobRelated: true,
    matchStatus: matchStatus,
    suggestedStatus: suggestedStatus,
    matchConfidence: confidence,
    interviewSuggestion: interview,
    applicationId: applicationId,
  );
}

const _acme = Application(
  id: 'app1',
  company: CompanyRef(id: 'c1', name: 'Acme'),
  jobTitle: 'Backend Engineer',
  status: ApplicationStatus.applied,
);

const _globex = Application(
  id: 'app2',
  company: CompanyRef(id: 'c2', name: 'Globex'),
  jobTitle: 'SRE',
  status: ApplicationStatus.applied,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The confirmation card is taller than the default 600px test surface, so
/// give it a phone-sized viewport instead of clipping the content.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Builds a Dio failure shaped like the backend's error envelope, so the
/// client's parsing of a rate-limited response is exercised for real.
DioException _errorResponse({
  int status = 429,
  String code = 'GMAIL_SYNC_RATE_LIMITED',
  String message = 'Gmail sync is rate limited. Try again in 42s.',
  Map<String, dynamic>? details,
}) {
  final request = RequestOptions(path: '/api/v1/gmail/sync');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: status,
      data: {
        'success': false,
        'error': {
          'code': code,
          'message': message,
          if (details case final d?) 'details': d,
        },
      },
    ),
  );
}

void main() {
  group('MatchConfidence', () {
    test('buckets scores', () {
      expect(MatchConfidence.fromScore(95), MatchConfidence.veryHigh);
      expect(MatchConfidence.fromScore(75), MatchConfidence.high);
      expect(MatchConfidence.fromScore(50), MatchConfidence.medium);
      expect(MatchConfidence.fromScore(10), MatchConfidence.low);
      expect(MatchConfidence.fromScore(null), MatchConfidence.unknown);
    });

    test('only medium and above are reliable', () {
      // A low-confidence suggestion must never be applied on a whim.
      expect(MatchConfidence.fromScore(10).isReliable, isFalse);
      expect(MatchConfidence.fromScore(50).isReliable, isTrue);
      expect(MatchConfidence.fromScore(95).isReliable, isTrue);
      expect(MatchConfidence.fromScore(null).isReliable, isFalse);
    });
  });

  group('GmailThread', () {
    test('a suggestion counts as unresolved', () {
      expect(_thread().isUnresolved, isTrue);
    });

    test('a matched thread is resolved', () {
      final thread = _thread(
        matchStatus: GmailMatchStatus.matched,
        applicationId: 'app1',
      );
      expect(thread.isUnresolved, isFalse);
    });

    test('an interview suggestion needs a time to be actionable', () {
      final withTime = InterviewSuggestion(
        scheduledAt: DateTime(2026, 2, 1, 10),
      );
      // ignore: prefer_const_constructors
      final withoutTime = InterviewSuggestion(title: 'Technical round');
      expect(withTime.isActionable, isTrue);
      expect(withoutTime.isActionable, isFalse);
    });
  });

  group('GmailMatchConfirm', () {
    test('omitting status and interview means link only', () {
      // This is the default the UI offers: linking is safe, mutating is not.
      const confirm = GmailMatchConfirm(applicationId: 'app1');
      expect(confirm.status, isNull);
      expect(confirm.interview, isNull);
    });
  });

  group('ApplicationMatchCard', () {
    testWidgets('does not pre-select for a low-confidence match', (
      tester,
    ) async {
      useTallSurface(tester);
      String? chosen;
      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(confidence: 10),
            candidates: const [_acme, _globex],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async => chosen = applicationId,
            onIgnore: () {},
          ),
        ),
      );

      final link = find.widgetWithText(FilledButton, 'Link to application');
      // Force-enabled check: a null selection must keep the action disabled
      // so an uncertain match can never be applied by reflex.
      final button = tester.widget<FilledButton>(link);
      expect(button.onPressed, isNull);
      expect(chosen, isNull);
    });

    testWidgets('pre-selects a reliable match and can link it', (tester) async {
      useTallSurface(tester);
      String? chosen;
      ApplicationStatus? applied;
      bool createdInterview = false;

      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(confidence: 95),
            candidates: const [_acme, _globex],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async {
                  chosen = applicationId;
                  applied = status;
                  createdInterview = createInterview;
                },
            onIgnore: () {},
          ),
        ),
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      await tester.pumpAndSettle();

      expect(chosen, 'app1');
      expect(
        applied,
        isNull,
        reason: 'status must stay untouched until explicitly opted in',
      );
      expect(createdInterview, isFalse);
    });

    testWidgets('applies a status only after the toggle is used', (
      tester,
    ) async {
      useTallSurface(tester);
      ApplicationStatus? applied;

      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(confidence: 95),
            candidates: const [_acme],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async => applied = status,
            onIgnore: () {},
          ),
        ),
      );

      expect(
        find.text('Update status'),
        findsOneWidget,
        reason: 'the suggestion must be visible but not pre-applied',
      );

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      await tester.pumpAndSettle();

      expect(applied, ApplicationStatus.shortlisted);
    });

    testWidgets('creates an interview only after the toggle is used', (
      tester,
    ) async {
      useTallSurface(tester);
      var interviewRequested = false;

      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(
              confidence: 95,
              interview: InterviewSuggestion(
                title: 'Technical round',
                scheduledAt: DateTime(2026, 2, 1, 10),
                durationMinutes: 60,
              ),
            ),
            candidates: const [_acme],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async => interviewRequested = createInterview,
            onIgnore: () {},
          ),
        ),
      );

      expect(find.text('Interview detected'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      await tester.pumpAndSettle();
      expect(
        interviewRequested,
        isFalse,
        reason: 'an interview must never be created without consent',
      );

      // Tick the interview toggle (the second checkbox in the card).
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      await tester.pumpAndSettle();

      expect(interviewRequested, isTrue);
    });

    testWidgets('pre-selects once the candidates load asynchronously', (
      tester,
    ) async {
      useTallSurface(tester);
      String? chosen;

      // The applications list is still loading on the first build.
      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(confidence: 95),
            candidates: const [],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async => chosen = applicationId,
            onIgnore: () {},
          ),
        ),
      );

      var button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      expect(button.onPressed, isNull);
      expect(
        find.text('Create a new application'),
        findsOneWidget,
        reason: 'an empty candidate list must offer a way forward',
      );

      // Candidates arrive; a reliable match should now be pre-selected.
      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(confidence: 95),
            candidates: const [_acme, _globex],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async => chosen = applicationId,
            onIgnore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      await tester.pumpAndSettle();
      expect(chosen, 'app1');
    });

    testWidgets(
      'keeps a low-confidence match unselected when candidates load',
      (tester) async {
        useTallSurface(tester);

        await tester.pumpWidget(
          _wrap(
            ApplicationMatchCard(
              thread: _thread(confidence: 10),
              candidates: const [],
              onConfirm:
                  ({
                    required String applicationId,
                    ApplicationStatus? status,
                    required bool createInterview,
                  }) async {},
              onIgnore: () {},
            ),
          ),
        );
        await tester.pumpWidget(
          _wrap(
            ApplicationMatchCard(
              thread: _thread(confidence: 10),
              candidates: const [_acme, _globex],
              onConfirm:
                  ({
                    required String applicationId,
                    ApplicationStatus? status,
                    required bool createInterview,
                  }) async {},
              onIgnore: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Link to application'),
        );
        expect(
          button.onPressed,
          isNull,
          reason: 'an uncertain match must require an explicit pick',
        );
      },
    );

    testWidgets('ignores an unreliable match', (tester) async {
      useTallSurface(tester);
      var ignored = false;
      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(),
            candidates: const [_acme],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async {},
            onIgnore: () => ignored = true,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Ignore'));
      expect(ignored, isTrue);
    });

    testWidgets('prompts to create an application when none match', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ApplicationMatchCard(
            thread: _thread(),
            candidates: const [],
            onConfirm:
                ({
                  required String applicationId,
                  ApplicationStatus? status,
                  required bool createInterview,
                }) async {},
            onIgnore: () {},
          ),
        ),
      );

      expect(find.text('No matching application found.'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Link to application'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Link to application'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('GmailThreadCard', () {
    testWidgets('shows an unresolved match as needing review', (tester) async {
      await tester.pumpWidget(_wrap(GmailThreadCard(thread: _thread())));

      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('Suggests Shortlisted'), findsOneWidget);
      expect(find.text('High confidence'), findsOneWidget);
    });

    testWidgets('flags a low-confidence suggestion', (tester) async {
      await tester.pumpWidget(
        _wrap(GmailThreadCard(thread: _thread(confidence: 10))),
      );
      expect(find.text('Low confidence'), findsOneWidget);
    });

    testWidgets('shows a linked thread as linked', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GmailThreadCard(
            thread: _thread(
              matchStatus: GmailMatchStatus.matched,
              applicationId: 'app1',
            ),
          ),
        ),
      );

      expect(find.text('Linked'), findsOneWidget);
      expect(find.text('Needs review'), findsNothing);
    });

    testWidgets('falls back when the subject is missing', (tester) async {
      const thread = GmailThread(id: 't2', gmailThreadId: 'g2');
      await tester.pumpWidget(_wrap(const GmailThreadCard(thread: thread)));
      expect(find.text('(no subject)'), findsOneWidget);
    });
  });

  group('Gmail sync rate limiting', () {
    test('surfaces retry_after_seconds from the error details', () {
      final api = ApiException.fromDio(
        _errorResponse(details: {'retry_after_seconds': 42}),
      );
      expect(api, isNotNull);
      expect(api!.code, 'GMAIL_SYNC_RATE_LIMITED');
      expect(api.statusCode, 429);
      expect(api.isRateLimited, isTrue);
      expect(api.retryAfterSeconds, 42);
    });

    test('is rate limited without details, so the UI degrades gracefully', () {
      final api = ApiException.fromDio(_errorResponse());
      expect(api!.isRateLimited, isTrue);
      expect(api.retryAfterSeconds, isNull);
    });

    test('a non-429 is not treated as rate limited', () {
      final api = ApiException.fromDio(
        _errorResponse(status: 500, code: 'INTERNAL_ERROR'),
      );
      expect(api!.isRateLimited, isFalse);
    });

    test('accepts a numeric string for retry_after_seconds', () {
      final api = ApiException.fromDio(
        _errorResponse(details: {'retry_after_seconds': '7'}),
      );
      expect(api!.retryAfterSeconds, 7);
    });

    test('existing conflict/duplicate flags still work', () {
      final conflict = ApiException.fromDio(
        _errorResponse(status: 409, code: 'INTERVIEW_CONFLICT'),
      );
      expect(conflict!.isInterviewConflict, isTrue);
      expect(conflict.isRateLimited, isFalse);
    });
  });
}
