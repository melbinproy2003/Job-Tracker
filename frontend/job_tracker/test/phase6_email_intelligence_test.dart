import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/features/gmail/domain/entities/gmail_thread.dart';
import 'package:job_tracker/features/gmail/domain/repositories/gmail_repository.dart';

void main() {
  group('InterviewSuggestion Phase 6 contract', () {
    test('parses scheduled_at and interview_type aliases', () {
      final suggestion = InterviewSuggestion.fromJson({
        'title': 'Backend tech screen',
        'scheduled_at': '2026-09-29T10:00:00+00:00',
        'duration_minutes': 60,
        'meeting_url': 'https://meet.example.com/x',
        'location': 'Virtual',
        'interviewer_name': 'Alex',
        'interviewer_email': 'alex@acme.com',
        'interview_type': 'TECHNICAL_INTERVIEW',
        'type': 'TECHNICAL_INTERVIEW',
        'confidence': 0.91,
      });

      expect(suggestion.isActionable, isTrue);
      expect(suggestion.scheduledAt, isNotNull);
      expect(suggestion.resolvedType, 'TECHNICAL_INTERVIEW');
      expect(suggestion.location, 'Virtual');
      expect(suggestion.interviewerEmail, 'alex@acme.com');
      expect(suggestion.confidence, closeTo(0.91, 0.001));
    });

    test('ignores hint-only payloads without scheduled_at', () {
      final suggestion = InterviewSuggestion.fromJson({
        'title': 'Round 1',
        'date_hint': 'Sep 29',
        'time_hint': '10:00',
      });
      expect(suggestion.isActionable, isFalse);
      expect(suggestion.scheduledAt, isNull);
    });
  });

  group('MatchCandidate', () {
    test('exposes explainable reasons and band', () {
      final candidate = MatchCandidate.fromJson({
        'application_id': 'a1',
        'company_name': 'Acme',
        'job_title': 'Engineer',
        'confidence': 82,
        'confidence_band': 'HIGH',
        'reasons': ['Company name appears in email', 'Job title matches'],
      });
      expect(candidate.band, MatchConfidence.high);
      expect(candidate.reasons, hasLength(2));
    });
  });

  group('GmailMatchConfirm force_interview', () {
    test('defaults force off; InterviewDraft serializes scheduled_at', () {
      final draft = InterviewDraft(
        interviewType: 'TECHNICAL_INTERVIEW',
        type: 'TECHNICAL_INTERVIEW',
        title: 'Tech',
        scheduledAt: DateTime.utc(2026, 9, 29, 10),
        durationMinutes: 45,
        location: 'Zoom',
      );
      final confirm = GmailMatchConfirm(applicationId: 'a1', interview: draft);
      expect(confirm.forceInterview, isFalse);
      final json = draft.toJson();
      expect(json['scheduled_at'], contains('2026-09-29'));
      expect(json.containsKey('date_hint'), isFalse);
      expect(json['interview_type'], 'TECHNICAL_INTERVIEW');
      expect(json['type'], 'TECHNICAL_INTERVIEW');
    });
  });

  group('ApplicationDraftFromEmail', () {
    test('parses discovery draft', () {
      final draft = ApplicationDraftFromEmail.fromJson({
        'company_name': 'Examplecorp',
        'company_domain': 'examplecorp.com',
        'job_title': 'Backend Engineer',
        'recruiter_email': 'jobs@examplecorp.com',
        'source': 'Gmail',
      });
      expect(draft.source, 'Gmail');
      expect(draft.companyDomain, 'examplecorp.com');
    });
  });

  group('GmailMatchResult conflict flags', () {
    test('surfaces interview conflict without applying force', () {
      const result = GmailMatchResult(
        threadId: 't1',
        matchStatus: GmailMatchStatus.matched,
        interviewConflict: true,
        conflictMessage:
            'You already have an interview scheduled during this time.',
      );
      expect(result.interviewConflict, isTrue);
      expect(result.interviewCreated, isFalse);
    });
  });
}
