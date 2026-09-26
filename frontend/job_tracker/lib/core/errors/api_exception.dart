import 'package:dio/dio.dart';

/// API error with structured code from backend (`error.code`).
class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  bool get isInterviewConflict => code == 'INTERVIEW_CONFLICT';
  bool get isFollowupDuplicate => code == 'FOLLOWUP_DUPLICATE';

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
    );
  }

  static Never throwFromDio(Object error) {
    final api = fromDio(error);
    if (api != null) throw api;
    throw error;
  }
}
