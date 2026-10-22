import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'gateway_parsing.dart';
import 'processing_api.dart';

/// Touch-up + save-credit operations for [GatewayProcessingApi]
/// (§7.3, FR-09). Split into its own file to keep files under
/// ~400 lines (Conventions §9). No automatic retry on consume-credit:
/// a retry could double-charge.
class GatewayTouchupCredits {
  GatewayTouchupCredits({
    required Dio dio,
    required Future<Result<Map<String, String>>> Function() headers,
    required void Function(CancelToken token) registerToken,
    required void Function(CancelToken token) clearToken,
  }) : _dio = dio,
       _headers = headers,
       _registerToken = registerToken,
       _clearToken = clearToken;

  final Dio _dio;
  final Future<Result<Map<String, String>>> Function() _headers;
  final void Function(CancelToken token) _registerToken;
  final void Function(CancelToken token) _clearToken;

  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required Uint8List maskPng,
    void Function(double fraction)? onUploadProgress,
  }) async {
    if (!await File(localPath).exists()) {
      return const Failure<TouchupOutcome>(
        AppFailure(
          code: 'missing_file',
          userMessageKey: AppStrings.errorGeneric,
          detail: 'Photo to touch up no longer exists on disk.',
        ),
      );
    }
    final headersResult = await _headers();
    if (headersResult is Failure<Map<String, String>>) {
      return Failure<TouchupOutcome>(headersResult.failure);
    }
    final headers = (headersResult as Success<Map<String, String>>).value;
    final token = CancelToken();
    _registerToken(token);
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'file': await MultipartFile.fromFile(
          localPath,
          filename: localPath.split('/').last,
        ),
        'mask_png': MultipartFile.fromBytes(maskPng, filename: 'mask.png'),
        'engine': 'auto',
      });
      final response = await _dio.post<dynamic>(
        '/touchup',
        data: form,
        options: Options(headers: headers),
        cancelToken: token,
        onSendProgress: (sent, total) {
          if (onUploadProgress == null || total <= 0) return;
          onUploadProgress((sent / total).clamp(0.0, 1.0));
        },
      );
      final map = response.data as Map<String, dynamic>;
      if (map['ok'] != true) {
        return Failure<TouchupOutcome>(
          AppFailure(
            code: 'gateway',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: map['error'] as String? ?? 'Gateway returned ok != true.',
          ),
        );
      }
      final meta = map['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return Success<TouchupOutcome>(
        TouchupOutcome(
          resultBytes: base64Decode(map['image_base64'] as String),
          engineUsed: meta['engine_used'] as String? ?? '',
          totalSeconds: (meta['total_seconds'] as num?)?.toDouble() ?? 0,
        ),
      );
    } on DioException catch (e) {
      return gatewayDioFailure<TouchupOutcome>(
        e,
        AppStrings.errorProcessingFailed,
      );
    } catch (e) {
      return gatewayBadResponse<TouchupOutcome>(
        'Unparseable touchup response: $e',
      );
    } finally {
      _clearToken(token);
    }
  }

  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async {
    final headersResult = await _headers();
    if (headersResult is Failure<Map<String, String>>) {
      return Failure<SaveCreditDecision>(headersResult.failure);
    }
    final headers = (headersResult as Success<Map<String, String>>).value;
    try {
      final response = await _dio.post<dynamic>(
        '/consume-credit',
        data: <String, dynamic>{'idempotency_key': idempotencyKey},
        options: Options(headers: headers),
      );
      final map = response.data as Map<String, dynamic>;
      // payment_required is a SUCCESS outcome, not a Failure (§7.3).
      return Success<SaveCreditDecision>(
        SaveCreditDecision(
          allowed: map['allowed'] == true,
          paymentRequired: map['payment_required'] == true,
          isPro: map['is_pro'] == true,
          savesLeft: (map['saves_left'] as num?)?.toInt(),
        ),
      );
    } on DioException catch (e) {
      return gatewayDioFailure<SaveCreditDecision>(e, AppStrings.errorGeneric);
    } catch (e) {
      return Failure<SaveCreditDecision>(
        AppFailure(
          code: 'bad_response',
          userMessageKey: AppStrings.errorGeneric,
          detail: 'Unparseable consume-credit response: $e',
        ),
      );
    }
  }

  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async {
    final headersResult = await _headers();
    if (headersResult is Failure<Map<String, String>>) {
      return Failure<void>(headersResult.failure);
    }
    final headers = (headersResult as Success<Map<String, String>>).value;
    try {
      final response = await _dio.post<dynamic>(
        '/refund-credit',
        data: <String, dynamic>{'idempotency_key': idempotencyKey},
        options: Options(headers: headers),
      );
      final map = response.data as Map<String, dynamic>;
      if (map['ok'] == true) return const Success<void>(null);
      return Failure<void>(
        AppFailure(
          code: 'gateway',
          userMessageKey: AppStrings.errorGeneric,
          detail:
              map['error'] as String? ?? 'refund-credit returned ok != true.',
        ),
      );
    } on DioException catch (e) {
      return gatewayDioFailure<void>(e, AppStrings.errorGeneric);
    } catch (e) {
      return Failure<void>(
        AppFailure(
          code: 'bad_response',
          userMessageKey: AppStrings.errorGeneric,
          detail: 'Unparseable refund-credit response: $e',
        ),
      );
    }
  }
}
