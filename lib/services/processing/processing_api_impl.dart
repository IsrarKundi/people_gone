import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'processing_api.dart';

/// Dio implementation of [ProcessingApi] — the only file that knows the
/// gateway base URL and endpoints (Conventions §2/§8).
///
/// SCAFFOLD STATE (Phase 1, Task 1.1): the gateway does not exist yet
/// (Phase 2, Task 2.1), so every call fails loudly with a
/// `not_implemented` [AppFailure]. Nothing is faked and no photo leaves
/// the device from this build.
class ProcessingApiImpl implements ProcessingApi {
  ProcessingApiImpl({required AppConfig config, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.apiBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
            ),
          );

  final Dio _dio;

  /// Exposed for tests and Phase 2 wiring.
  Dio get dio => _dio;

  static const Failure<Never> _notImplemented = Failure<Never>(
    AppFailure(
      code: 'not_implemented',
      userMessageKey: AppStrings.errorNotImplemented,
      detail: 'Gateway arrives in Phase 2 (Task 2.1).',
    ),
  );

  @override
  Future<Result<JobProposal>> analysePhoto(String localPath) async =>
      _notImplemented;

  @override
  Future<Result<JobResult>> removePeople(
    String jobId,
    List<int> removeIds,
  ) async => _notImplemented;
}
