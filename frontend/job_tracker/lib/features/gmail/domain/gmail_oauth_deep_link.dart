// Pure parser for the Gmail OAuth mobile return deep link.
//
// Expected URLs (backend-owned credentials never appear here):
// - `jobtracker://gmail/connected` (optional `email` display hint only)
// - `jobtracker://gmail/error` (optional safe `error` code)

enum GmailOAuthDeepLinkKind { connected, error }

class GmailOAuthDeepLink {
  const GmailOAuthDeepLink._({
    required this.kind,
    this.emailHint,
    this.errorCode,
  });

  final GmailOAuthDeepLinkKind kind;

  /// Optional display hint from the redirect query. Never used as auth.
  final String? emailHint;

  /// Backend-safe error code only (`oauth_cancelled`, `oauth_failed`, …).
  final String? errorCode;

  bool get isSuccess => kind == GmailOAuthDeepLinkKind.connected;

  /// User-facing copy — never raw Google / library messages.
  String get userMessage {
    if (isSuccess) return 'Gmail connected successfully';
    switch (errorCode) {
      case 'oauth_cancelled':
      case 'oauth_denied':
        return 'Gmail connection cancelled';
      case 'invalid_state':
        return 'Gmail connection expired. Please try again.';
      case 'token_exchange_failed':
        return 'Google could not complete the Gmail authorization.';
      case 'gmail_not_configured':
        return 'Gmail connection is not available right now.';
      default:
        return 'Gmail connection failed';
    }
  }

  /// Returns null when [uri] is not a recognized Gmail OAuth return link.
  static GmailOAuthDeepLink? tryParse(Uri uri) {
    if (uri.scheme.toLowerCase() != 'jobtracker') return null;
    if (uri.host.toLowerCase() != 'gmail') return null;

    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase())
        .toList();
    if (segments.length != 1) return null;

    final leaf = segments.single;
    if (leaf == 'connected') {
      final email = uri.queryParameters['email']?.trim();
      return GmailOAuthDeepLink._(
        kind: GmailOAuthDeepLinkKind.connected,
        emailHint: (email == null || email.isEmpty) ? null : email,
      );
    }
    if (leaf == 'error') {
      final raw = uri.queryParameters['error']?.trim();
      return GmailOAuthDeepLink._(
        kind: GmailOAuthDeepLinkKind.error,
        errorCode: _sanitizeErrorCode(raw),
      );
    }
    return null;
  }

  static String _sanitizeErrorCode(String? raw) {
    if (raw == null || raw.isEmpty) return 'oauth_failed';
    final normalized = raw.toLowerCase().replaceAll(' ', '_');
    const allowed = {
      'oauth_failed',
      'oauth_cancelled',
      'oauth_denied',
      'invalid_state',
      'token_exchange_failed',
      'gmail_not_configured',
    };
    if (allowed.contains(normalized)) return normalized;
    // Reject arbitrary / technical Google error strings.
    return 'oauth_failed';
  }

  /// Rejects links that smuggle credential-looking query keys.
  static bool containsForbiddenCredentialParams(Uri uri) {
    const forbidden = {
      'access_token',
      'refresh_token',
      'client_secret',
      'id_token',
      'code',
      'token',
      'code_verifier',
      'code_challenge',
    };
    for (final key in uri.queryParameters.keys) {
      if (forbidden.contains(key.toLowerCase())) return true;
    }
    return false;
  }
}
