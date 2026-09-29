import 'package:dio/dio.dart';

/// API error with structured code from backend (`error.code`).
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.retryAfterSeconds,
  });

  final String code;
  final String message;
  final int? statusCode;

  /// Present when the server sent `error.details.retry_after_seconds`, which
  /// the Gmail sync cooldown uses to tell the user when to try again.
  final int? retryAfterSeconds;

  bool get isInterviewConflict => code == 'INTERVIEW_CONFLICT';
  bool get isFollowupDuplicate => code == 'FOLLOWUP_DUPLICATE';

  /// A rate-limited request — almost always the Gmail sync cooldown. The
  /// caller should wait [retryAfterSeconds] rather than retry immediately.
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;

  static ApiException? fromDio(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is! Map) return null;
    final err = data['error'];
    if (err is! Map) return null;
    final code = err['code']?.toString();
    final message = err['message']?.toString();
    if (code == null || message == null) return null;
    return ApiException(
      code: code,
      message: message,
      statusCode: error.response?.statusCode,
      retryAfterSeconds: _retryAfter(err['details']),
    );
  }

  static int? _retryAfter(Object? details) {
    if (details is! Map) return null;
    final value = details['retry_after_seconds'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static Never throwFromDio(Object error) {
    final api = fromDio(error);
    if (api != null) throw api;
    throw error;
  }
}
