import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/features/gmail/domain/gmail_oauth_deep_link.dart';

void main() {
  group('GmailOAuthDeepLink.tryParse', () {
    test('accepts connected success URL', () {
      final link = GmailOAuthDeepLink.tryParse(
        Uri.parse('jobtracker://gmail/connected'),
      );
      expect(link, isNotNull);
      expect(link!.isSuccess, isTrue);
      expect(link.userMessage, 'Gmail connected successfully');
    });

    test('accepts optional email display hint only', () {
      final link = GmailOAuthDeepLink.tryParse(
        Uri.parse('jobtracker://gmail/connected?email=user%40example.com'),
      );
      expect(link?.emailHint, 'user@example.com');
      expect(link?.isSuccess, isTrue);
    });

    test('maps safe error codes; rejects raw Google errors', () {
      final cancelled = GmailOAuthDeepLink.tryParse(
        Uri.parse('jobtracker://gmail/error?error=oauth_cancelled'),
      );
      expect(cancelled?.userMessage, 'Gmail connection cancelled');

      final raw = GmailOAuthDeepLink.tryParse(
        Uri.parse(
          'jobtracker://gmail/error?error=%28invalid_grant%29+Missing+code+verifier',
        ),
      );
      expect(raw?.errorCode, 'oauth_failed');
      expect(raw?.userMessage, 'Gmail connection failed');
      expect(raw?.userMessage.toLowerCase().contains('verifier'), isFalse);
    });

    test('rejects wrong scheme or host', () {
      expect(
        GmailOAuthDeepLink.tryParse(Uri.parse('https://gmail/connected')),
        isNull,
      );
      expect(
        GmailOAuthDeepLink.tryParse(Uri.parse('jobtracker://other/connected')),
        isNull,
      );
    });
  });

  group('credential param rejection', () {
    test('flags access_token / refresh_token / code / code_verifier', () {
      expect(
        GmailOAuthDeepLink.containsForbiddenCredentialParams(
          Uri.parse('jobtracker://gmail/connected?access_token=x'),
        ),
        isTrue,
      );
      expect(
        GmailOAuthDeepLink.containsForbiddenCredentialParams(
          Uri.parse('jobtracker://gmail/connected?code_verifier=x'),
        ),
        isTrue,
      );
      expect(
        GmailOAuthDeepLink.containsForbiddenCredentialParams(
          Uri.parse('jobtracker://gmail/connected?email=a@b.com'),
        ),
        isFalse,
      );
    });
  });
}
