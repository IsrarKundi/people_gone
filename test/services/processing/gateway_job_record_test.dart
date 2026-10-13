import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/services/storage/local_store.dart';
import 'package:people_gone/services/storage/local_store_impl.dart';

/// Gateway job record persistence via the real [LocalStoreImpl]
/// (temp documents dir, same setup as local_store_impl_test.dart).
void main() {
  late Directory tempDir;
  late LocalStoreImpl store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_gw_record_test');
    final secure = <String, String>{};
    store = LocalStoreImpl(
      documentsDir: () async => tempDir,
      secureRead: (key) async => secure[key],
      secureWrite: (key, value) async => secure[key] = value,
      nowUtc: () => DateTime.utc(2026, 10, 14),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  T unwrap<T>(Result<T> result) {
    expect(result, isA<Success<T>>());
    return (result as Success<T>).value;
  }

  test('gateway job record round-trips and clears', () async {
    expect(unwrap(await store.gatewayJob()), isNull);
    final record = GatewayJobRecord(
      jobId: 'job-1',
      photoFingerprint: '128_ab12cd34',
      photoPath: '/photos/photo.jpg',
      stage: 'awaitingConfirm',
      updatedAt: DateTime.utc(2026, 10, 14, 3),
    );
    unwrap(await store.saveGatewayJob(record));
    final loaded = unwrap(await store.gatewayJob());
    expect(loaded?.jobId, 'job-1');
    expect(loaded?.photoFingerprint, '128_ab12cd34');
    expect(loaded?.photoPath, '/photos/photo.jpg');
    expect(loaded?.stage, 'awaitingConfirm');
    expect(loaded?.updatedAt, DateTime.utc(2026, 10, 14, 3));
    // JSON round-trip of the record itself.
    final again = GatewayJobRecord.fromJson(record.toJson());
    expect(again.jobId, record.jobId);
    expect(again.stage, record.stage);
    unwrap(await store.clearGatewayJob());
    expect(unwrap(await store.gatewayJob()), isNull);
  });
}
