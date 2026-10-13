import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/result.dart';
import 'processing_api.dart';

/// Shared parsing / error helpers for the gateway implementation
/// (§7.3). Kept in their own file so gateway files stay under
/// ~400 lines (Conventions §9).

/// Job-matching fingerprint only — NOT a security hash (FNV-1a 32-bit).
String gatewayFingerprintFor(Uint8List bytes) {
  var hash = 0x811c9dc5;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return '${bytes.length}_${hash.toRadixString(16).padLeft(8, '0')}';
}

List<DetectedPerson> gatewayParsePersons(dynamic rawList) {
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

/// Same field mapping as ProcessingApiImpl._parseDetectionResponse.
DetectionProposal gatewayProposalFromMap(
  Map<String, dynamic> map,
  String localPath,
) {
  List<int> ids(String key) {
    final raw = map[key] as List<dynamic>? ?? <dynamic>[];
    return raw.map((dynamic v) => (v as num).toInt()).toList();
  }

  final persons = gatewayParsePersons(map['persons']);
  final dims = (map['input_dimensions'] as List<dynamic>? ?? <dynamic>[])
      .map((dynamic v) => (v as num).toInt())
      .toList();
  return DetectionProposal(
    photoPath: localPath,
    personsDetected:
        (map['persons_detected'] as num?)?.toInt() ?? persons.length,
    keeperIds: ids('keeper_ids'),
    removedIds: ids('removed_ids'),
    persons: persons,
    inputDimensions: dims,
  );
}

/// Gateway error bodies look like {error: '...'} — the failure detail
/// always carries the HTTP status plus that server error text.
Failure<T> gatewayDioFailure<T>(DioException e, String userMessageKey) {
  if (e.type == DioExceptionType.cancel) {
    return Failure<T>(
      const AppFailure(
        code: 'cancelled',
        userMessageKey: AppStrings.errorGeneric,
        detail: 'Cancelled by the user.',
      ),
    );
  }
  final status = e.response?.statusCode;
  String? serverError;
  final data = e.response?.data;
  if (data is Map<String, dynamic> && data['error'] is String) {
    serverError = data['error'] as String;
  } else if (data is String && data.isNotEmpty) {
    serverError = data;
  }
  return Failure<T>(
    AppFailure(
      code: 'gateway',
      userMessageKey: userMessageKey,
      detail:
          'HTTP ${status ?? 0}${serverError != null ? ': $serverError' : ''}',
    ),
  );
}

Failure<T> gatewayBadResponse<T>(String detail) => Failure<T>(
  AppFailure(
    code: 'bad_response',
    userMessageKey: AppStrings.errorProcessingFailed,
    detail: detail,
  ),
);
