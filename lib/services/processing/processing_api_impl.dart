import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'processing_api.dart';

/// Dio implementation of [ProcessingApi] — the only file that knows the
/// processing base URL and endpoints (Conventions §2/§8).
///
/// Talks to OUR server per API Contract v1 (`POST /process`, multipart):
/// the dev worker on Modal today, the Supabase gateway in Phase 2 — the
/// base URL comes from [AppConfig] either way, never from feature code.
///
/// Contract client guidance honoured here: long timeouts (a cold start
/// can take up to 300 s; CPU processing of one photo ~2 min) and ONE
/// automatic retry on timeout/5xx-gateway failures before surfacing an
/// error. The photo is sent at full resolution; the result is full
/// resolution. Nothing about the photo is ever logged.
class ProcessingApiImpl implements ProcessingApi {
  ProcessingApiImpl({required AppConfig config, Dio? dio})
    : _config = config,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.apiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(minutes: 10),
              receiveTimeout: const Duration(minutes: 10),
            ),
          );

  final AppConfig _config;
  final Dio _dio;
  CancelToken? _currentToken;

  /// Exposed for tests.
  Dio get dio => _dio;

  @override
  void cancelOngoing() {
    _currentToken?.cancel('user_cancelled');
  }

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async {
    if (_config.apiBaseUrl.isEmpty) {
      return const Failure<DetectionProposal>(
        AppFailure(
          code: 'misconfigured',
          userMessageKey: AppStrings.errorNotImplemented,
          detail: 'API base URL is empty.',
        ),
      );
    }
    final file = File(localPath);
    if (!await file.exists()) {
      return const Failure<DetectionProposal>(
        AppFailure(
          code: 'missing_file',
          userMessageKey: AppStrings.errorGeneric,
          detail: 'Picked photo no longer exists on disk.',
        ),
      );
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final token = CancelToken();
      _currentToken = token;
      try {
        final form = FormData.fromMap(<String, dynamic>{
          'file': await MultipartFile.fromFile(
            localPath,
            filename: localPath.split('/').last,
          ),
        });
        final response = await _dio.post<dynamic>(
          '/detect',
          data: form,
          cancelToken: token,
          onSendProgress: (sent, total) {
            if (onUploadProgress == null || total <= 0) return;
            final fraction = sent / total;
            onUploadProgress(fraction.clamp(0.0, 1.0));
          },
        );
        return _parseDetectionResponse(response.data, localPath);
      } on DioException catch (e) {
        final failure = _mapError<DetectionProposal>(e);
        if (attempt == 0 && _isRetryable(e)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        return failure;
      } finally {
        if (identical(_currentToken, token)) _currentToken = null;
      }
    }
    return const Failure<DetectionProposal>(
      AppFailure(code: 'unknown', userMessageKey: AppStrings.errorGeneric),
    );
  }

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async {
    if (_config.apiBaseUrl.isEmpty) {
      return const Failure<ProcessedPhoto>(
        AppFailure(
          code: 'misconfigured',
          userMessageKey: AppStrings.errorNotImplemented,
          detail: 'API base URL is empty.',
        ),
      );
    }
    final file = File(localPath);
    if (!await file.exists()) {
      return const Failure<ProcessedPhoto>(
        AppFailure(
          code: 'missing_file',
          userMessageKey: AppStrings.errorGeneric,
          detail: 'Picked photo no longer exists on disk.',
        ),
      );
    }

    // Contract v1: retry once on cold-start/transient failures.
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = CancelToken();
      _currentToken = token;
      try {
        final form = FormData.fromMap(<String, dynamic>{
          'file': await MultipartFile.fromFile(
            localPath,
            filename: localPath.split('/').last,
          ),
          'engine': 'mat',
          if (keepIds != null && keepIds.isNotEmpty) 'keep': keepIds.join(','),
          if (removeItemIds != null && removeItemIds.isNotEmpty)
            'remove_items': removeItemIds.join(','),
          if (detachedBelongingIds != null && detachedBelongingIds.isNotEmpty)
            'detached_items': detachedBelongingIds.join(','),
        });
        final response = await _dio.post<dynamic>(
          '/process',
          data: form,
          cancelToken: token,
          onSendProgress: (sent, total) {
            if (onUploadProgress == null || total <= 0) return;
            final fraction = sent / total;
            onUploadProgress(fraction.clamp(0.0, 1.0));
          },
        );
        return _parseResponse(response.data);
      } on DioException catch (e) {
        final failure = _mapError<ProcessedPhoto>(e);
        if (attempt == 0 && _isRetryable(e)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        return failure;
      } finally {
        if (identical(_currentToken, token)) _currentToken = null;
      }
    }
    // Unreachable — the loop always returns — but the compiler needs it.
    return const Failure<ProcessedPhoto>(
      AppFailure(code: 'unknown', userMessageKey: AppStrings.errorGeneric),
    );
  }


  @override
  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required Uint8List maskPng,
    void Function(double fraction)? onUploadProgress,
  }) async {
    if (_config.apiBaseUrl.isEmpty) {
      return const Failure<TouchupOutcome>(
        AppFailure(
          code: 'misconfigured',
          userMessageKey: AppStrings.errorNotImplemented,
          detail: 'API base URL is empty.',
        ),
      );
    }
    final file = File(localPath);
    if (!await file.exists()) {
      return const Failure<TouchupOutcome>(
        AppFailure(
          code: 'missing_file',
          userMessageKey: AppStrings.errorGeneric,
          detail: 'Photo to touch up no longer exists on disk.',
        ),
      );
    }

    // Same retry-once contract guidance as /process (cold starts).
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = CancelToken();
      _currentToken = token;
      try {
        final form = FormData.fromMap(<String, dynamic>{
          'file': await MultipartFile.fromFile(
            localPath,
            filename: localPath.split('/').last,
          ),
          'mask_png': MultipartFile.fromBytes(
            maskPng,
            filename: 'mask.png',
          ),
          'engine': 'mat',
        });
        final response = await _dio.post<dynamic>(
          '/touchup',
          data: form,
          cancelToken: token,
          onSendProgress: (sent, total) {
            if (onUploadProgress == null || total <= 0) return;
            final fraction = sent / total;
            onUploadProgress(fraction.clamp(0.0, 1.0));
          },
        );
        return _parseTouchupResponse(response.data);
      } on DioException catch (e) {
        final failure = _mapError<TouchupOutcome>(e);
        if (attempt == 0 && _isRetryable(e)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        return failure;
      } finally {
        if (identical(_currentToken, token)) _currentToken = null;
      }
    }
    return const Failure<TouchupOutcome>(
      AppFailure(code: 'unknown', userMessageKey: AppStrings.errorGeneric),
    );
  }

  Result<TouchupOutcome> _parseTouchupResponse(dynamic data) {
    try {
      final map = data as Map<String, dynamic>;
      if (map['ok'] != true) {
        return const Failure<TouchupOutcome>(
          AppFailure(
            code: 'server',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: 'Worker returned ok != true.',
          ),
        );
      }
      final bytes = base64Decode(map['image_base64'] as String);
      final meta = map['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return Success<TouchupOutcome>(
        TouchupOutcome(
          resultBytes: bytes,
          engineUsed: meta['engine_used'] as String? ?? '',
          totalSeconds: (meta['total_seconds'] as num?)?.toDouble() ?? 0,
        ),
      );
    } catch (e) {
      return Failure<TouchupOutcome>(
        AppFailure(
          code: 'bad_response',
          userMessageKey: AppStrings.errorProcessingFailed,
          detail: 'Unparseable worker touchup response: $e',
        ),
      );
    }
  }

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async {
    // The direct dev worker has no ledger. Failing loudly (never a
    // fake "allowed") keeps a misconfigured build from skipping the
    // save-time credit gate (§7.3); production uses the gateway.
    return const Failure<SaveCreditDecision>(
      AppFailure(
        code: 'requires_gateway',
        userMessageKey: AppStrings.errorNotImplemented,
        detail: 'Save-credit gate exists only on the gateway path (§7.3).',
      ),
    );
  }

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async {
    return const Failure<void>(
      AppFailure(
        code: 'requires_gateway',
        userMessageKey: AppStrings.errorNotImplemented,
        detail: 'Save-credit refunds exist only on the gateway path (§7.2).',
      ),
    );
  }

  bool _isRetryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        return status == 502 || status == 503 || status == 504;
      default:
        return false;
    }
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

  /// Same mapping as gateway_parsing.gatewayParseBelongings (v3):
  /// unknown tiers parse as ambiguous with the person link dropped;
  /// malformed entries are skipped.
  List<DetectedBelonging> _parseBelongings(dynamic rawList) {
    if (rawList is! List) return const <DetectedBelonging>[];
    final parsed = <DetectedBelonging>[];
    for (final dynamic item in rawList) {
      if (item is! Map<String, dynamic>) continue;
      final rawBox = item['box'] as List<dynamic>? ?? <dynamic>[];
      // A belonging without a full box cannot be drawn, hit-tested,
      // or decided on — it is malformed, skip it.
      if (rawBox.length != 4) continue;
      final attached = item['tier'] == 'attached';
      parsed.add(
        DetectedBelonging(
          id: (item['id'] as num?)?.toInt() ?? 0,
          detectedClass: item['detected_class'] as String? ?? '',
          box: rawBox.map((dynamic b) => (b as num).toInt()).toList(),
          score: (item['score'] as num?)?.toDouble() ?? 1.0,
          tier: attached ? BelongingTier.attached : BelongingTier.ambiguous,
          personId: attached ? (item['person_id'] as num?)?.toInt() : null,
        ),
      );
    }
    return parsed;
  }

  /// Same mapping as gateway_parsing.gatewayParseDistractions (v3,
  /// Phase B): malformed entries are skipped.
  List<DetectedDistraction> _parseDistractions(dynamic rawList) {
    if (rawList is! List) return const <DetectedDistraction>[];
    final parsed = <DetectedDistraction>[];
    for (final dynamic item in rawList) {
      if (item is! Map<String, dynamic>) continue;
      final rawBox = item['box'] as List<dynamic>? ?? <dynamic>[];
      if (rawBox.length != 4) continue;
      parsed.add(
        DetectedDistraction(
          id: (item['id'] as num?)?.toInt() ?? 0,
          category: item['category'] as String? ?? '',
          box: rawBox.map((dynamic b) => (b as num).toInt()).toList(),
          score: (item['score'] as num?)?.toDouble() ?? 1.0,
        ),
      );
    }
    return parsed;
  }

  Result<DetectionProposal> _parseDetectionResponse(
    dynamic data,
    String localPath,
  ) {
    try {
      final map = data as Map<String, dynamic>;
      if (map['ok'] != true) {
        return const Failure<DetectionProposal>(
          AppFailure(
            code: 'server',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: 'Worker returned ok != true.',
          ),
        );
      }
      List<int> ids(String key) {
        final raw = map[key] as List<dynamic>? ?? <dynamic>[];
        return raw.map((dynamic v) => (v as num).toInt()).toList();
      }

      final dims = (map['input_dimensions'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic v) => (v as num).toInt())
          .toList();

      return Success<DetectionProposal>(
        DetectionProposal(
          photoPath: localPath,
          personsDetected: (map['persons_detected'] as num?)?.toInt() ?? 0,
          keeperIds: ids('keeper_ids'),
          removedIds: ids('removed_ids'),
          persons: _parsePersons(map['persons']),
          inputDimensions: dims,
          belongings: _parseBelongings(map['belongings']),
          distractions: _parseDistractions(map['distractions']),
        ),
      );
    } catch (e) {
      return Failure<DetectionProposal>(
        AppFailure(
          code: 'bad_response',
          userMessageKey: AppStrings.errorProcessingFailed,
          detail: 'Unparseable worker detect response: $e',
        ),
      );
    }
  }

  Result<ProcessedPhoto> _parseResponse(dynamic data) {
    try {
      final map = data as Map<String, dynamic>;
      if (map['ok'] != true) {
        return const Failure<ProcessedPhoto>(
          AppFailure(
            code: 'server',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: 'Worker returned ok != true.',
          ),
        );
      }
      final encoded = map['image_base64'] as String;
      final bytes = base64Decode(encoded);
      final meta = map['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
      List<int> ids(String key) {
        final raw = meta[key] as List<dynamic>? ?? <dynamic>[];
        return raw.map((dynamic v) => (v as num).toInt()).toList();
      }

      return Success<ProcessedPhoto>(
        ProcessedPhoto(
          resultBytes: bytes,
          personsDetected: (meta['persons_detected'] as num?)?.toInt() ?? 0,
          keeperIds: ids('keeper_ids'),
          removedIds: ids('removed_ids'),
          cropsInpainted: (meta['crops_inpainted'] as num?)?.toInt() ?? 0,
          totalSeconds: (meta['total_seconds'] as num?)?.toDouble() ?? 0,
          engineUsed: meta['engine_used'] as String? ?? '',
          persons: _parsePersons(meta['persons']),
          itemsRemoved: (meta['items_removed'] as num?)?.toInt() ?? 0,
          distractionsRemoved:
              (meta['distractions_removed'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (e) {
      return Failure<ProcessedPhoto>(
        AppFailure(
          code: 'bad_response',
          userMessageKey: AppStrings.errorProcessingFailed,
          detail: 'Unparseable worker response: $e',
        ),
      );
    }
  }

  Failure<T> _mapError<T>(DioException e) {
    switch (e.type) {
      case DioExceptionType.cancel:
        return Failure<T>(
          const AppFailure(
            code: 'cancelled',
            userMessageKey: AppStrings.errorGeneric,
            detail: 'Cancelled by the user.',
          ),
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return Failure<T>(
          const AppFailure(code: 'timeout', userMessageKey: AppStrings.errorTimeout),
        );
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 404) {
          return Failure<T>(
            const AppFailure(
              code: 'not_found',
              userMessageKey: AppStrings.errorGeneric,
              detail: 'Endpoint not found (HTTP 404).',
            ),
          );
        }
        if (status == 413) {
          return Failure<T>(
            const AppFailure(
              code: 'too_large',
              userMessageKey: AppStrings.errorPhotoTooLarge,
            ),
          );
        }
        return Failure<T>(
          AppFailure(
            code: 'server',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: 'HTTP $status',
          ),
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.sendTimeout:
        return Failure<T>(
          const AppFailure(
            code: 'network',
            userMessageKey: AppStrings.errorUploadFailed,
          ),
        );
      default:
        return Failure<T>(
          AppFailure(
            code: 'unknown',
            userMessageKey: AppStrings.errorGeneric,
            detail: e.type.name,
          ),
        );
    }
  }
}
