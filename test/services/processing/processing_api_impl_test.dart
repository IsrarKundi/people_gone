import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/processing/processing_api_impl.dart';

/// Fake transport: records every request and answers via [handler].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options, int call) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return handler(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Map<String, dynamic> json, int status) {
  return ResponseBody.fromString(
    jsonEncode(json),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );
}

/// The contract v1 success shape (modal-deploy/API_CONTRACT.md), with a
/// 3-byte stand-in for the result JPEG.
Map<String, dynamic> contractFixture() => <String, dynamic>{
  'ok': true,
  'image_base64': base64Encode(<int>[1, 2, 3]),
  'meta': <String, dynamic>{
    'persons_detected': 13,
    'keeper_ids': <int>[0],
    'removed_ids': <int>[1, 2, 3],
    'crops_inpainted': 12,
    'total_seconds': 4.21,
    'engine_requested': 'mat',
    'engine_used': 'mat',
    'fallbacks_used': <dynamic>[],
  },
};

void main() {
  late Directory tempDir;
  late File photo;
  late AppConfig config;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_api_test');
    photo = File('${tempDir.path}/photo.jpg');
    await photo.writeAsBytes(List<int>.generate(128, (i) => i % 251));
    config = const AppConfig(
      apiBaseUrl: 'https://worker.test',
      providerDisplayName: 'PeopleGone processing',
      consentVersion: 1,
      supportEmail: 'support@example.com',
      privacyPolicyUrl: 'https://example.invalid/privacy',
      useGateway: false,
      supabaseUrl: '',
      supabaseAnonKey: '',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ProcessingApiImpl apiWith(FakeAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
    dio.httpClientAdapter = adapter;
    return ProcessingApiImpl(config: config, dio: dio);
  }

  test('parses the contract v1 success response', () async {
    final adapter = FakeAdapter((options, call) async {
      return jsonBody(contractFixture(), 200);
    });
    final result = await apiWith(adapter).processPhoto(localPath: photo.path);
    expect(result, isA<Success<ProcessedPhoto>>());
    final value = (result as Success<ProcessedPhoto>).value;
    expect(value.resultBytes, <int>[1, 2, 3]);
    expect(value.personsDetected, 13);
    expect(value.keeperIds, <int>[0]);
    expect(value.removedIds, <int>[1, 2, 3]);
    expect(value.cropsInpainted, 12);
    expect(value.totalSeconds, 4.21);
    expect(value.engineUsed, 'mat');
  });

  test('sends multipart file + engine=mat, and keep when given', () async {
    final adapter = FakeAdapter((options, call) async {
      return jsonBody(contractFixture(), 200);
    });
    await apiWith(
      adapter,
    ).processPhoto(localPath: photo.path, keepIds: <int>[0, 3]);
    final options = adapter.requests.single;
    expect(options.path, '/process');
    final form = options.data as FormData;
    final fields = <String, String>{
      for (final f in form.fields) f.key: f.value,
    };
    expect(fields['engine'], 'mat');
    expect(fields['keep'], '0,3');
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'photo.jpg');
  });

  test('omits keep when no keeper override is given', () async {
    final adapter = FakeAdapter((options, call) async {
      return jsonBody(contractFixture(), 200);
    });
    await apiWith(adapter).processPhoto(localPath: photo.path);
    final form = adapter.requests.single.data as FormData;
    expect(form.fields.map((f) => f.key), isNot(contains('keep')));
  });

  test('reports real upload progress fractions', () async {
    final adapter = FakeAdapter((options, call) async {
      return jsonBody(contractFixture(), 200);
    });
    final fractions = <double>[];
    await apiWith(
      adapter,
    ).processPhoto(localPath: photo.path, onUploadProgress: fractions.add);
    expect(fractions, isNotEmpty);
    expect(fractions.last, closeTo(1.0, 0.05));
    expect(fractions, orderedEquals(fractions.toList()..sort()));
  });

  test('maps a 500 to a server failure with plain-language key', () async {
    final adapter = FakeAdapter((options, call) async {
      return jsonBody(<String, dynamic>{'detail': 'boom'}, 500);
    });
    final result = await apiWith(adapter).processPhoto(localPath: photo.path);
    expect(result, isA<Failure<ProcessedPhoto>>());
    final failure = (result as Failure<ProcessedPhoto>).failure;
    expect(failure.code, 'server');
    expect(failure.userMessageKey, 'error_processing_failed');
    // A 500 is not retried (only cold-start/transient classes are).
    expect(adapter.requests, hasLength(1));
  });

  test('retries once on a receive timeout, then succeeds', () async {
    final adapter = FakeAdapter((options, call) async {
      if (call == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return jsonBody(contractFixture(), 200);
    });
    final result = await apiWith(adapter).processPhoto(localPath: photo.path);
    expect(result, isA<Success<ProcessedPhoto>>());
    expect(adapter.requests, hasLength(2));
  });

  test('retries a 503 once, then surfaces the failure', () async {
    final adapter = FakeAdapter((options, call) async {
      return jsonBody(<String, dynamic>{'detail': 'busy'}, 503);
    });
    final result = await apiWith(adapter).processPhoto(localPath: photo.path);
    expect(result, isA<Failure<ProcessedPhoto>>());
    expect((result as Failure<ProcessedPhoto>).failure.code, 'server');
    expect(adapter.requests, hasLength(2));
  });

  test('missing file fails without any network call', () async {
    final adapter = FakeAdapter((options, call) async {
      return jsonBody(contractFixture(), 200);
    });
    final result = await apiWith(
      adapter,
    ).processPhoto(localPath: '${tempDir.path}/gone.jpg');
    expect(result, isA<Failure<ProcessedPhoto>>());
    expect((result as Failure<ProcessedPhoto>).failure.code, 'missing_file');
    expect(adapter.requests, isEmpty);
  });

  test('detectPersons parses contract detect response with persons array', () async {
    final adapter = FakeAdapter((options, call) async {
      expect(options.path, '/detect');
      return jsonBody(<String, dynamic>{
        'ok': true,
        'input_dimensions': <int>[1920, 1080],
        'persons_detected': 2,
        'keeper_ids': <int>[0],
        'removed_ids': <int>[1],
        'persons': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 0,
            'box': <int>[100, 100, 400, 800],
            'score': 0.95,
            'is_keeper': true,
          },
          <String, dynamic>{
            'id': 1,
            'box': <int>[500, 200, 700, 600],
            'score': 0.85,
            'is_keeper': false,
          },
        ],
      }, 200);
    });
    final result = await apiWith(adapter).detectPersons(localPath: photo.path);
    expect(result, isA<Success<DetectionProposal>>());
    final proposal = (result as Success<DetectionProposal>).value;
    expect(proposal.personsDetected, 2);
    expect(proposal.keeperIds, <int>[0]);
    expect(proposal.removedIds, <int>[1]);
    expect(proposal.persons, hasLength(2));
    expect(proposal.persons.first.isKeeper, isTrue);
    expect(proposal.persons.last.isKeeper, isFalse);
  });
}
