import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import '../storage/local_store.dart';
import 'gateway_auth.dart';
import 'gateway_job_poller.dart';
import 'gateway_parsing.dart';
import 'gateway_touchup_credits.dart';
import 'processing_api.dart';

/// Gateway implementation of [ProcessingApi] (§7.3): anonymous auth +
/// create / analyse / confirm jobs on the Supabase gateway, resumable
/// via the [LocalStore] gateway-job record, and the server credit
/// ledger at Save time. Every gateway call sends the session token as
/// Bearer + the anon key as apikey. The service_role key never appears
/// here. Nothing about photo content is ever logged.
class GatewayProcessingApi implements ProcessingApi {
  GatewayProcessingApi({
    required AppConfig config,
    required LocalStore localStore,
    GatewayAuth? auth,
    Dio? dio,
    Duration pollInterval = const Duration(seconds: 5),
    Duration pollTimeout = const Duration(minutes: 20),
  }) : _config = config,
       _localStore = localStore,
       _pollInterval = pollInterval,
       _pollTimeout = pollTimeout,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: config.gatewayBaseUrl,
               connectTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(minutes: 10),
               receiveTimeout: const Duration(minutes: 10),
             ),
           ) {
    _auth = auth ?? GatewayAuth(config: config, dio: _dio);
    _aux = GatewayTouchupCredits(
      dio: _dio,
      headers: _headers,
      registerToken: (t) => _currentToken = t,
      clearToken: (t) {
        if (identical(_currentToken, t)) _currentToken = null;
      },
    );
  }

  final AppConfig _config;
  final LocalStore _localStore;
  final Dio _dio;
  late final GatewayAuth _auth;
  late final GatewayTouchupCredits _aux;
  final Duration _pollInterval;
  final Duration _pollTimeout;
  CancelToken? _currentToken;
  bool _pollCancelled = false;

  Dio get dio => _dio;

  @override
  void cancelOngoing() {
    // Cancelling never touches credits (FR-07).
    _pollCancelled = true;
    _currentToken?.cancel('user_cancelled');
  }

  Future<Result<Map<String, String>>> _headers() async {
    final session = await _auth.ensureSession();
    return switch (session) {
      Success(:final value) => Success<Map<String, String>>(<String, String>{
        'Authorization': 'Bearer ${value.accessToken}',
        'apikey': _config.supabaseAnonKey,
      }),
      Failure(:final failure) => Failure<Map<String, String>>(failure),
    };
  }

  Future<Result<String>> _fingerprint(String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return const Failure<String>(
        AppFailure(
          code: 'missing_file',
          userMessageKey: AppStrings.errorGeneric,
          detail: 'Picked photo no longer exists on disk.',
        ),
      );
    }
    // Job-matching only, not a security hash (gateway_parsing.dart).
    return Success<String>(gatewayFingerprintFor(await file.readAsBytes()));
  }

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async {
    if (_config.supabaseUrl.isEmpty) {
      return const Failure<DetectionProposal>(
        AppFailure(
          code: 'misconfigured',
          userMessageKey: AppStrings.errorNotImplemented,
          detail: 'Supabase URL is empty.',
        ),
      );
    }
    final fp = await _fingerprint(localPath);
    if (fp is Failure<String>) return Failure<DetectionProposal>(fp.failure);
    final fingerprint = (fp as Success<String>).value;
    final hr = await _headers();
    if (hr is Failure<Map<String, String>>) {
      return Failure<DetectionProposal>(hr.failure);
    }
    final headers = (hr as Success<Map<String, String>>).value;
    _pollCancelled = false;
    final token = CancelToken();
    _currentToken = token;
    try {
      final create = await _post('/create-job', fingerprint, headers, token);
      final jobId = create['job_id'] as String;
      if (create['persons'] != null) {
        await _saveJob(jobId, fingerprint, localPath, 'awaitingConfirm');
        return Success<DetectionProposal>(
          gatewayProposalFromMap(create, localPath),
        );
      }
      final uploadUrl = create['upload_url'] as String?;
      if (uploadUrl == null) {
        return gatewayBadResponse<DetectionProposal>(
          'create-job returned no upload_url and no persons.',
        );
      }
      await _upload(localPath, uploadUrl, token, onUploadProgress);
      final analyse = await _postMap(
        '/analyse-job',
        <String, dynamic>{'job_id': jobId},
        headers,
        token,
      );
      if (analyse['ok'] == false) {
        return Failure<DetectionProposal>(
          AppFailure(
            code: 'gateway',
            userMessageKey: AppStrings.errorProcessingFailed,
            detail: analyse['error'] as String? ?? 'analyse-job failed.',
          ),
        );
      }
      diag(
        'gateway',
        'detect ok: job ${DiagnosticsLog.shortId(jobId)} persons='
        '${(analyse['persons'] as List<dynamic>?)?.length ?? 0}',
      );
      await _saveJob(jobId, fingerprint, localPath, 'awaitingConfirm');
      return Success<DetectionProposal>(
        gatewayProposalFromMap(analyse, localPath),
      );
    } on DioException catch (e) {
      return gatewayDioFailure<DetectionProposal>(
        e,
        AppStrings.errorProcessingFailed,
      );
    } catch (e) {
      return gatewayBadResponse<DetectionProposal>(
        'Unparseable detect response: $e',
      );
    } finally {
      if (identical(_currentToken, token)) _currentToken = null;
    }
  }

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async {
    if (_config.supabaseUrl.isEmpty) {
      return const Failure<ProcessedPhoto>(
        AppFailure(
          code: 'misconfigured',
          userMessageKey: AppStrings.errorNotImplemented,
          detail: 'Supabase URL is empty.',
        ),
      );
    }
    final fp = await _fingerprint(localPath);
    if (fp is Failure<String>) return Failure<ProcessedPhoto>(fp.failure);
    final fingerprint = (fp as Success<String>).value;
    final hr = await _headers();
    if (hr is Failure<Map<String, String>>) {
      return Failure<ProcessedPhoto>(hr.failure);
    }
    final headers = (hr as Success<Map<String, String>>).value;
    _pollCancelled = false;
    final token = CancelToken();
    _currentToken = token;
    try {
      GatewayJobRecord? record;
      final stored = await _localStore.gatewayJob();
      if (stored is Success<GatewayJobRecord?>) record = stored.value;
      final matches = record != null && record.photoFingerprint == fingerprint;
      diag(
        'gateway',
        'process: stored record stage=${record?.stage} matches=$matches',
      );
      final String jobId;
      if (matches && record.stage == 'processing') {
        jobId = record.jobId; // Reattach after relaunch (§6.7).
      } else if (matches && record.stage == 'awaitingConfirm') {
        jobId = record.jobId;
        diag(
          'gateway',
          'confirm -> job ${DiagnosticsLog.shortId(jobId)} keep=$keepIds '
          'items=$removeItemIds detached=$detachedBelongingIds',
        );
        await _confirm(
          jobId,
          keepIds,
          removeItemIds,
          detachedBelongingIds,
          headers,
          token,
        );
        diag('gateway', 'confirm ok: job ${DiagnosticsLog.shortId(jobId)}');
        await _saveJob(jobId, fingerprint, localPath, 'processing');
      } else {
        jobId = await _freshJob(
          localPath,
          fingerprint,
          keepIds,
          removeItemIds,
          detachedBelongingIds,
          headers,
          token,
          onUploadProgress,
        );
      }
      final poller = GatewayJobPoller(
        dio: _dio,
        interval: _pollInterval,
        timeout: _pollTimeout,
        isCancelled: () => _pollCancelled,
      );
      final result = await poller.pollAndDownload(
        jobId: jobId,
        headers: headers,
        cancelToken: token,
      );
      if (result is Success<ProcessedPhoto>) {
        await _localStore.clearGatewayJob();
      }
      return result;
    } on DioException catch (e) {
      return gatewayDioFailure<ProcessedPhoto>(
        e,
        AppStrings.errorProcessingFailed,
      );
    } catch (e) {
      return gatewayBadResponse<ProcessedPhoto>(
        'Unparseable process response: $e',
      );
    } finally {
      if (identical(_currentToken, token)) _currentToken = null;
    }
  }

  Future<String> _freshJob(
    String localPath,
    String fingerprint,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    Map<String, String> headers,
    CancelToken token,
    void Function(double fraction)? onUploadProgress,
  ) async {
    final create = await _post('/create-job', fingerprint, headers, token);
    final jobId = create['job_id'] as String;
    diag('gateway', 'job created: ${DiagnosticsLog.shortId(jobId)}');
    final uploadUrl = create['upload_url'] as String?;
    if (uploadUrl != null) {
      await _upload(localPath, uploadUrl, token, onUploadProgress);
    }
    if (keepIds == null && create['persons'] == null) {
      // Analyse first so the job has a proposal (awaiting_confirm).
      await _postMap(
        '/analyse-job',
        <String, dynamic>{'job_id': jobId},
        headers,
        token,
      );
    }
    await _confirm(
      jobId,
      keepIds,
      removeItemIds,
      detachedBelongingIds,
      headers,
      token,
    );
    await _saveJob(jobId, fingerprint, localPath, 'processing');
    return jobId;
  }

  Future<void> _confirm(
    String jobId,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    Map<String, String> headers,
    CancelToken token,
  ) => _postMap(
    '/confirm-job',
    <String, dynamic>{
      'job_id': jobId,
      'keep_ids': ?keepIds,
      'remove_item_ids': ?removeItemIds,
      'detached_belonging_ids': ?detachedBelongingIds,
      'engine': 'mat',
    },
    headers,
    token,
  );

  @override
  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required Uint8List maskPng,
    void Function(double fraction)? onUploadProgress,
  }) => _aux.touchupPhoto(
    localPath: localPath,
    maskPng: maskPng,
    onUploadProgress: onUploadProgress,
  );

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) => _aux.consumeSaveCredit(idempotencyKey: idempotencyKey);

  @override
  Future<Result<void>> refundSaveCredit({required String idempotencyKey}) =>
      _aux.refundSaveCredit(idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> _post(
    String path,
    String fingerprint,
    Map<String, String> headers,
    CancelToken token,
  ) => _postMap(
    path,
    <String, dynamic>{'client_job_id': fingerprint, 'engine': 'mat'},
    headers,
    token,
  );

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> data,
    Map<String, String> headers,
    CancelToken token,
  ) async {
    final response = await _dio.post<dynamic>(
      path,
      data: data,
      options: Options(headers: headers),
      cancelToken: token,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> _upload(
    String localPath,
    String uploadUrl,
    CancelToken token,
    void Function(double fraction)? onUploadProgress,
  ) async {
    await _dio.put<dynamic>(
      uploadUrl,
      data: File(localPath).openRead(),
      options: Options(
        headers: <String, dynamic>{'Content-Type': 'image/jpeg'},
      ),
      cancelToken: token,
      onSendProgress: (sent, total) {
        if (onUploadProgress == null || total <= 0) return;
        onUploadProgress((sent / total).clamp(0.0, 1.0));
      },
    );
  }

  Future<void> _saveJob(
    String jobId,
    String fingerprint,
    String photoPath,
    String stage,
  ) => _localStore.saveGatewayJob(
    GatewayJobRecord(
      jobId: jobId,
      photoFingerprint: fingerprint,
      photoPath: photoPath,
      stage: stage,
      updatedAt: DateTime.now().toUtc(),
    ),
  );
}
