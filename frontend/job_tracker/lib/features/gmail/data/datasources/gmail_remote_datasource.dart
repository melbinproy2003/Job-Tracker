import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/gmail_thread.dart';
import '../../domain/repositories/gmail_repository.dart';
import '../models/gmail_models.dart';

/// Talks to `/api/v1/gmail`.
///
/// This client never sees a Gmail access or refresh token: the backend performs
/// the OAuth exchange and returns only a sanitized account projection.
class GmailRemoteDataSource {
  GmailRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<GmailAccount>> listAccounts() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.gmailAccounts,
      );
      return (response.data ?? [])
          .map(
            (e) => GmailAccountModel.fromJson(
              e as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  /// Returns the Google consent URL. Opened in a browser, not fetched.
  Future<String> getConnectUrl() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.gmailConnect,
      );
      final url = response.data?['authorization_url'] as String?;
      if (url == null || url.isEmpty) {
        throw const FormatException('Missing authorization_url');
      }
      return url;
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<GmailSyncResult> sync({bool fullSync = false}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.gmailSync,
        data: {'full_sync': fullSync},
      );
      return GmailSyncResultModel.fromJson(
        response.data ?? const {},
      ).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<List<GmailThread>> listThreads({String? applicationId}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.gmailThreads,
        queryParameters: {'application_id': ?applicationId},
      );
      return (response.data ?? [])
          .map(
            (e) =>
                GmailThreadModel.fromJson(e as Map<String, dynamic>).toEntity(),
          )
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<GmailThread> getThread(String threadId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.gmailThread(threadId),
      );
      return GmailThreadModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<GmailMessage> getMessage(String messageId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.gmailMessage(messageId),
      );
      return GmailMessageModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<GmailMatchResult> confirmMatch(
    String threadId,
    GmailMatchConfirm confirm,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.gmailMatchConfirm(threadId),
        data: {
          'application_id': confirm.applicationId,
          // Both of these are omitted unless the user explicitly opted in, so
          // the backend can never change status or create an interview by
          // accident.
          if (confirm.status != null) 'confirm_status': confirm.status,
          if (confirm.interview != null) ...{
            'create_interview': true,
            'interview': confirm.interview!.toJson(),
          },
          if (confirm.forceInterview) 'force_interview': true,
        },
      );
      return GmailMatchResultModel.fromJson(
        response.data ?? const {},
      ).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<GmailMatchResult> ignoreMatch(String threadId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.gmailMatchIgnore(threadId),
      );
      return GmailMatchResultModel.fromJson(
        response.data ?? const {},
      ).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<GmailMatchResult> unlinkMatch(String threadId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.gmailMatchUnlink(threadId),
      );
      return GmailMatchResultModel.fromJson(
        response.data ?? const {},
      ).toEntity();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<List<GmailTimelineEvent>> getApplicationTimeline(
    String applicationId,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiEndpoints.gmailApplicationTimeline(applicationId),
      );
      return (response.data ?? [])
          .map((e) => GmailTimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }

  Future<void> disconnect(String accountId) async {
    try {
      await _dio.delete(ApiEndpoints.gmailAccount(accountId));
    } on DioException catch (e) {
      ApiException.throwFromDio(e);
    }
  }
}
