import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'processing_api.dart';

/// Polls a gateway job to completion, then downloads its result
/// (§7.3). Helper for [GatewayProcessingApi] in its own file to keep
/// files under ~400 lines (Conventions §9).
class GatewayJobPoller {
  GatewayJobPoller({
    required Dio dio,
    required Duration interval,
    required Duration timeout,
    required bool Function() isCancelled,
  }) : _dio = dio,
       _interval = interval,
       _timeout = timeout,
       _isCancelled = isCancelled;

  final Dio _dio;
  final Duration _interval;
  final Duration _timeout;
  final bool Function() _isCancelled;

  /// Polls [jobId] until done / failed / expired / timeout / cancel,
  /// then fetches get-result and downloads the result bytes.
  Future<Result<ProcessedPhoto>> pollAndDownload({
    required String jobId,
    required Map<String, String> headers,
    required CancelToken cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    Map<String, dynamic>? meta;
    while (true) {
      if (_isCancelled()) return _cancelled();
      if (stopwatch.elapsed > _timeout) {
        return const Failure<ProcessedPhoto>(
          AppFailure(code: 'timeout', userMessageKey: AppStrings.errorTimeout),
        );
      }
      Response<dynamic> statusResponse;
      try {
        statusResponse = await _getWithRetry(
          '/job-status',
          query: <String, dynamic>{'job_id': jobId},
          headers: headers,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        return _mapPollError<ProcessedPhoto>(e);
      }
      final data = statusResponse.data;
      if (data is! Map<String, dynamic>) {
        return const Failure<ProcessedPhoto>(
          AppFailure(
            code: 'bad_response',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: 'job-status returned a non-object body.',
          ),
        );
      }
      final status = data['status'] as String? ?? '';
      final serverError = data['error'] as String?;
      switch (status) {
        case 'done':
          diag('gateway', 'poll: job done');
          final rawMeta = data['meta'];
          meta = rawMeta is Map<String, dynamic> ? rawMeta : null;
        case 'failed':
          diag('gateway', 'poll: job failed: ${serverError ?? 'no detail'}');
          return Failure<ProcessedPhoto>(
            AppFailure(
              code: 'job_failed',
              userMessageKey: AppStrings.errorProcessingFailed,
              detail: serverError ?? 'Job failed.',
            ),
          );
        case 'expired':
          diag('gateway', 'poll: job expired: ${serverError ?? 'no detail'}');
          return Failure<ProcessedPhoto>(
            AppFailure(
              code: 'job_expired',
              userMessageKey: AppStrings.errorProcessingFailed,
              detail: serverError ?? 'Job expired.',
            ),
          );
        case 'processing':
        case 'created':
        case 'awaiting_confirm':
          await Future<void>.delayed(_interval);
          continue;
        default:
          return Failure<ProcessedPhoto>(
            AppFailure(
              code: 'bad_response',
              userMessageKey: AppStrings.errorProcessingFailed,
              detail: 'Unknown job status: $status',
            ),
          );
      }
      break;
    }
    if (_isCancelled()) return _cancelled();

    // get-result -> signed download URL.
    String downloadUrl;
    try {
      final resultResponse = await _getWithRetry(
        '/get-result',
        query: <String, dynamic>{'job_id': jobId},
        headers: headers,
        cancelToken: cancelToken,
      );
      final data = resultResponse.data;
      if (data is! Map<String, dynamic> || data['download_url'] is! String) {
        return const Failure<ProcessedPhoto>(
          AppFailure(
            code: 'bad_response',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: 'get-result returned no download_url.',
          ),
        );
      }
      downloadUrl = data['download_url'] as String;
    } on DioException catch (e) {
      return _mapPollError<ProcessedPhoto>(e);
    }

    // Download the result bytes from the signed URL (no gateway headers
    // — the signed URL is the credential).
    try {
      final bytesResponse = await _dio.get<List<int>>(
        downloadUrl,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      final bytes = bytesResponse.data;
      if (bytes == null) {
        return const Failure<ProcessedPhoto>(
          AppFailure(
            code: 'bad_response',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: 'Result download returned no bytes.',
          ),
        );
      }
      diag('gateway', 'result downloaded: ${bytes.length} bytes');
      return Success<ProcessedPhoto>(
        _buildPhoto(meta, Uint8List.fromList(bytes)),
      );
    } on DioException catch (e) {
      return _mapPollError<ProcessedPhoto>(e);
    }
  }

  ProcessedPhoto _buildPhoto(Map<String, dynamic>? meta, Uint8List bytes) {
    final m = meta ?? <String, dynamic>{};
    List<int> ids(String key) {
      final raw = m[key] as List<dynamic>? ?? <dynamic>[];
      return raw.map((dynamic v) => (v as num).toInt()).toList();
    }

    return ProcessedPhoto(
      resultBytes: bytes,
      personsDetected: (m['persons_detected'] as num?)?.toInt() ?? 0,
      keeperIds: ids('keeper_ids'),
      removedIds: ids('removed_ids'),
      cropsInpainted: (m['crops_inpainted'] as num?)?.toInt() ?? 0,
      totalSeconds: (m['total_seconds'] as num?)?.toDouble() ?? 0,
      engineUsed: m['engine_used'] as String? ?? '',
      persons: _parsePersons(m['persons']),
      itemsRemoved: (m['items_removed'] as num?)?.toInt() ?? 0,
    );
  }

  List<DetectedPerson> _parsePersons(dynamic rawList) {
    if (rawList is! List) return const <DetectedPerson>[];
    return rawList.map((dynamic item) {
      final m = item as Map<String, dynamic>;
      final rawBox = m['box'] as List<dynamic>? ?? <dynamic>[];
      return DetectedPerson(
        id: (m['id'] as num?)?.toInt() ?? 0,
        box: rawBox.map((dynamic b) => (b as num).toInt()).toList(),
        score: (m['score'] as num?)?.toDouble() ?? 1.0,
        isKeeper: m['is_keeper'] == true,
      );
    }).toList();
  }

  /// GET that retries exactly once on a 5xx response (§7.3 guidance).
  Future<Response<dynamic>> _getWithRetry(
    String path, {
    required Map<String, dynamic> query,
    required Map<String, String> headers,
    required CancelToken cancelToken,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: Options(headers: headers),
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        if (attempt == 0 &&
            e.type == DioExceptionType.badResponse &&
            status >= 500 &&
            status < 600) {
          continue;
        }
        rethrow;
      }
    }
    throw StateError('unreachable');
  }

  Failure<T> _cancelled<T>() => Failure<T>(
    const AppFailure(
      code: 'cancelled',
      userMessageKey: AppStrings.errorGeneric,
      detail: 'Cancelled by the user.',
    ),
  );

  Failure<T> _mapPollError<T>(DioException e) {
    if (e.type == DioExceptionType.cancel || _isCancelled()) {
      return _cancelled<T>();
    }
    final status = e.response?.statusCode;
    String? serverError;
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      serverError = data['error'] as String;
    }
    return Failure<T>(
      AppFailure(
        code: 'gateway',
        userMessageKey: AppStrings.errorProcessingFailed,
        detail:
            'HTTP ${status ?? 0}${serverError != null ? ': $serverError' : ''}',
      ),
    );
  }
}
