import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/services/processing/gateway_auth.dart';
import 'package:people_gone/services/processing/gateway_processing_api.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

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
    if (requestStream != null) await requestStream.drain<void>();
    return handler(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Map<String, dynamic> json, int status) =>
    ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );

Map<String, dynamic> sessionJson() => <String, dynamic>{
  'access_token': 'access-1',
  'refresh_token': 'refresh-1',
  'expires_in': 3600,
  'user': <String, dynamic>{'id': 'user-1'},
};

List<Map<String, dynamic>> personsJson() => <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 0,
    'box': <int>[10, 10, 50, 90],
    'score': 0.95,
    'is_keeper': true,
  },
  <String, dynamic>{
    'id': 1,
    'box': <int>[60, 20, 90, 80],
    'score': 0.85,
    'is_keeper': false,
  },
];

Map<String, dynamic> doneMeta() => <String, dynamic>{
  'persons_detected': 2,
  'keeper_ids': <int>[0],
  'removed_ids': <int>[1],
  'persons': personsJson(),
  'crops_inpainted': 1,
  'total_seconds': 12.5,
  'engine_used': 'mat',
  'ghost_check_fired': false,
};

String fingerprintFor(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return '${bytes.length}_${hash.toRadixString(16).padLeft(8, '0')}';
}

class InMemoryTokenStore implements GatewayTokenStore {
  StoredGatewaySession? session;
  @override
  Future<StoredGatewaySession?> read() async => session;
  @override
  Future<void> write(StoredGatewaySession s) async => session = s;
  @override
  Future<void> clear() async => session = null;
}

class FakeLocalStore implements LocalStore {
  GatewayJobRecord? gatewayJobRecord;
  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord r) async {
    gatewayJobRecord = r;
    return const Success<void>(null);
  }

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      Success<GatewayJobRecord?>(gatewayJobRecord);
  @override
  Future<Result<void>> clearGatewayJob() async {
    gatewayJobRecord = null;
    return const Success<void>(null);
  }

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      const Success<List<HistoryEntry>>(<HistoryEntry>[]);
  @override
  Future<Result<void>> addHistory(HistoryEntry e) async =>
      const Success<void>(null);
  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);
  @override
  Future<Result<String>> adoptIntoHistory(String p, String id) async =>
      Success<String>(p);
  @override
  Future<Result<String>> adoptOriginalIntoHistory(String p, String id) async =>
      Success<String>(p);
  @override
  Future<Result<String>> writeSessionResult(Uint8List b) async =>
      const Success<String>('/session/result.jpg');
  @override
  Future<Result<void>> saveToGallery(String p) async =>
      const Success<void>(null);
  @override
  Future<Result<int>> freeSavesUsed() async => const Success<int>(0);
  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));
  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);
  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);
  @override
  Future<Result<void>> setAcceptedConsentVersion(int v) async =>
      const Success<void>(null);
}

void main() {
  late Directory tempDir;
  late File photo;
  late List<int> photoBytes;
  late AppConfig config;
  late InMemoryTokenStore tokenStore;
  late FakeLocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_gateway_test');
    photo = File('${tempDir.path}/photo.jpg');
    photoBytes = List<int>.generate(128, (i) => i % 251);
    await photo.writeAsBytes(photoBytes);
    config = const AppConfig(
      apiBaseUrl: 'https://worker.test',
      providerDisplayName: 'PeopleGone processing',
      consentVersion: 1,
      supportEmail: 'support@example.com',
      privacyPolicyUrl: 'https://example.invalid/privacy',
      useGateway: true,
      supabaseUrl: 'https://supabase.test',
      supabaseAnonKey: 'anon-key',
    );
    tokenStore = InMemoryTokenStore();
    store = FakeLocalStore();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  void seedValidSession() {
    tokenStore.session = const StoredGatewaySession(
      accessToken: 'access-valid',
      refreshToken: 'refresh-valid',
      userId: 'user-1',
      expiryEpochSeconds: 9999999999,
    );
  }

  GatewayProcessingApi apiWith(FakeAdapter adapter) {
    final authDio = Dio();
    authDio.httpClientAdapter = adapter;
    final gatewayDio = Dio(BaseOptions(baseUrl: config.gatewayBaseUrl));
    gatewayDio.httpClientAdapter = adapter;
    return GatewayProcessingApi(
      config: config,
      localStore: store,
      auth: GatewayAuth(config: config, tokenStore: tokenStore, dio: authDio),
      dio: gatewayDio,
      pollInterval: const Duration(milliseconds: 10),
    );
  }

  test(
    '(a) detect: create -> PUT -> analyse, record awaitingConfirm',
    () async {
      final adapter = FakeAdapter((options, call) async {
        final path = options.uri.path;
        if (path.endsWith('/auth/v1/signup')) {
          return jsonBody(sessionJson(), 200);
        }
        if (path.endsWith('/create-job')) {
          expect(options.headers['Authorization'], 'Bearer access-1');
          expect(options.headers['apikey'], 'anon-key');
          final data = options.data as Map<String, dynamic>;
          expect(data['engine'], 'mat');
          expect(data['client_job_id'], fingerprintFor(photoBytes));
          return jsonBody(<String, dynamic>{
            'job_id': 'job-1',
            'status': 'created',
            'upload_url': 'https://storage.test/upload-1',
            'persons': null,
            'keeper_ids': <int>[],
            'removed_ids': <int>[],
            'input_dimensions': null,
          }, 200);
        }
        if (options.method == 'PUT') {
          return ResponseBody.fromString('', 200);
        }
        if (path.endsWith('/analyse-job')) {
          return jsonBody(<String, dynamic>{
            'ok': true,
            'persons_detected': 2,
            'keeper_ids': <int>[0],
            'removed_ids': <int>[1],
            'persons': personsJson(),
            'input_dimensions': <int>[100, 100],
          }, 200);
        }
        throw StateError('unexpected ${options.method} ${options.uri}');
      });
      final result = await apiWith(
        adapter,
      ).detectPersons(localPath: photo.path);
      expect(result, isA<Success<DetectionProposal>>());
      final proposal = (result as Success<DetectionProposal>).value;
      expect(proposal.personsDetected, 2);
      expect(proposal.keeperIds, <int>[0]);
      expect(proposal.removedIds, <int>[1]);
      expect(proposal.persons, hasLength(2));
      expect(proposal.persons.first.isKeeper, isTrue);
      expect(proposal.inputDimensions, <int>[100, 100]);
      expect(store.gatewayJobRecord?.jobId, 'job-1');
      expect(store.gatewayJobRecord?.stage, 'awaitingConfirm');
      expect(
        store.gatewayJobRecord?.photoFingerprint,
        fingerprintFor(photoBytes),
      );
    },
  );

  test(
    '(b) process reattaches to a processing job and clears record',
    () async {
      seedValidSession();
      store.gatewayJobRecord = GatewayJobRecord(
        jobId: 'job-9',
        photoFingerprint: fingerprintFor(photoBytes),
        photoPath: photo.path,
        stage: 'processing',
        updatedAt: DateTime.utc(2026, 10, 14),
      );
      var statusCalls = 0;
      final adapter = FakeAdapter((options, call) async {
        final path = options.uri.path;
        if (path.endsWith('/job-status')) {
          statusCalls++;
          if (statusCalls == 1) {
            return jsonBody(<String, dynamic>{
              'job_id': 'job-9',
              'status': 'processing',
              'error': null,
              'meta': null,
            }, 200);
          }
          return jsonBody(<String, dynamic>{
            'job_id': 'job-9',
            'status': 'done',
            'error': null,
            'meta': doneMeta(),
          }, 200);
        }
        if (path.endsWith('/get-result')) {
          return jsonBody(<String, dynamic>{
            'download_url': 'https://storage.test/result.jpg',
            'expires_at': '2026-10-14T00:00:00Z',
          }, 200);
        }
        if (options.uri.toString() == 'https://storage.test/result.jpg') {
          return ResponseBody.fromBytes(<int>[9, 8, 7], 200);
        }
        throw StateError('unexpected ${options.method} ${options.uri}');
      });
      final result = await apiWith(adapter).processPhoto(localPath: photo.path);
      expect(result, isA<Success<ProcessedPhoto>>());
      final value = (result as Success<ProcessedPhoto>).value;
      expect(value.resultBytes, <int>[9, 8, 7]);
      expect(value.personsDetected, 2);
      expect(value.keeperIds, <int>[0]);
      expect(value.removedIds, <int>[1]);
      expect(value.cropsInpainted, 1);
      expect(value.totalSeconds, 12.5);
      expect(value.engineUsed, 'mat');
      expect(store.gatewayJobRecord, isNull);
    },
  );

  test('(c) process from awaitingConfirm confirms, no second upload', () async {
    seedValidSession();
    store.gatewayJobRecord = GatewayJobRecord(
      jobId: 'job-1',
      photoFingerprint: fingerprintFor(photoBytes),
      photoPath: photo.path,
      stage: 'awaitingConfirm',
      updatedAt: DateTime.utc(2026, 10, 14),
    );
    final adapter = FakeAdapter((options, call) async {
      final path = options.uri.path;
      if (path.endsWith('/confirm-job')) {
        final data = options.data as Map<String, dynamic>;
        expect(data['job_id'], 'job-1');
        expect(data['keep_ids'], <int>[0]);
        return jsonBody(<String, dynamic>{
          'job_id': 'job-1',
          'status': 'processing',
        }, 202);
      }
      if (path.endsWith('/job-status')) {
        return jsonBody(<String, dynamic>{
          'job_id': 'job-1',
          'status': 'done',
          'error': null,
          'meta': doneMeta(),
        }, 200);
      }
      if (path.endsWith('/get-result')) {
        return jsonBody(<String, dynamic>{
          'download_url': 'https://storage.test/result.jpg',
          'expires_at': '2026-10-14T00:00:00Z',
        }, 200);
      }
      if (options.uri.toString() == 'https://storage.test/result.jpg') {
        return ResponseBody.fromBytes(<int>[1, 2], 200);
      }
      throw StateError('unexpected ${options.method} ${options.uri}');
    });
    final result = await apiWith(
      adapter,
    ).processPhoto(localPath: photo.path, keepIds: <int>[0]);
    expect(result, isA<Success<ProcessedPhoto>>());
    final paths = adapter.requests.map((r) => r.uri.path).toList();
    expect(paths.where((p) => p.endsWith('/create-job')), isEmpty);
    expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  test(
    '(d) consume-credit allowed and payment_required both succeed',
    () async {
      seedValidSession();
      var mode = 'allowed';
      final adapter = FakeAdapter((options, call) async {
        if (options.uri.path.endsWith('/consume-credit')) {
          if (mode == 'allowed') {
            return jsonBody(<String, dynamic>{
              'allowed': true,
              'payment_required': false,
              'is_pro': false,
              'saves_left': 9,
            }, 200);
          }
          return jsonBody(<String, dynamic>{
            'allowed': false,
            'payment_required': true,
            'is_pro': false,
            'saves_left': 0,
          }, 200);
        }
        throw StateError('unexpected ${options.uri}');
      });
      final api = apiWith(adapter);
      final first = await api.consumeSaveCredit(idempotencyKey: 'k1');
      expect(first, isA<Success<SaveCreditDecision>>());
      final d1 = (first as Success<SaveCreditDecision>).value;
      expect(d1.allowed, isTrue);
      expect(d1.paymentRequired, isFalse);
      expect(d1.savesLeft, 9);
      mode = 'pay';
      final second = await api.consumeSaveCredit(idempotencyKey: 'k2');
      expect(second, isA<Success<SaveCreditDecision>>());
      final d2 = (second as Success<SaveCreditDecision>).value;
      expect(d2.allowed, isFalse);
      expect(d2.paymentRequired, isTrue);
      expect(d2.savesLeft, 0);
    },
  );

  test('(e) auth: empty store signs up once, then reuses session', () async {
    var signups = 0;
    final adapter = FakeAdapter((options, call) async {
      if (options.uri.path.endsWith('/auth/v1/signup')) {
        signups++;
        return jsonBody(sessionJson(), 200);
      }
      throw StateError('unexpected ${options.uri}');
    });
    final dio = Dio();
    dio.httpClientAdapter = adapter;
    final auth = GatewayAuth(config: config, tokenStore: tokenStore, dio: dio);
    final first = await auth.ensureSession();
    expect(first, isA<Success<({String accessToken, String userId})>>());
    final v1 = (first as Success<({String accessToken, String userId})>).value;
    expect(v1.accessToken, 'access-1');
    expect(v1.userId, 'user-1');
    expect(tokenStore.session?.refreshToken, 'refresh-1');
    expect(tokenStore.session?.accessToken, 'access-1');
    final second = await auth.ensureSession();
    expect(second, isA<Success<({String accessToken, String userId})>>());
    expect(signups, 1);
  });
}
