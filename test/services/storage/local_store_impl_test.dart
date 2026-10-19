import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/services/storage/local_store.dart';
import 'package:people_gone/services/storage/local_store_impl.dart';

void main() {
  late Directory tempDir;
  late Map<String, String> secure;
  late DateTime now;
  late LocalStoreImpl store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_store_test');
    secure = <String, String>{};
    now = DateTime.utc(2026, 10, 13);
    store = LocalStoreImpl(
      documentsDir: () async => tempDir,
      secureRead: (key) async => secure[key],
      secureWrite: (key, value) async => secure[key] = value,
      nowUtc: () => now,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  T unwrap<T>(Result<T> result) {
    expect(result, isA<Success<T>>());
    return (result as Success<T>).value;
  }

  group('history', () {
    test('starts empty', () async {
      expect(unwrap(await store.history()), isEmpty);
    });

    test('addHistory then history returns newest first', () async {
      final older = HistoryEntry(
        id: 'a',
        localPath: '/x/a.jpg',
        savedAt: DateTime.utc(2026, 10, 1),
      );
      final newer = HistoryEntry(
        id: 'b',
        localPath: '/x/b.jpg',
        savedAt: DateTime.utc(2026, 10, 12),
      );
      unwrap(await store.addHistory(older));
      unwrap(await store.addHistory(newer));
      final entries = unwrap(await store.history());
      expect(entries.map((e) => e.id), <String>['b', 'a']);
    });

    test('deleteHistory removes the index record and the file', () async {
      final session = unwrap(
        await store.writeSessionResult(Uint8List.fromList(<int>[1, 2, 3])),
      );
      final historyPath = unwrap(await store.adoptIntoHistory(session, 'h1'));
      unwrap(
        await store.addHistory(
          HistoryEntry(
            id: 'h1',
            localPath: historyPath,
            savedAt: DateTime.utc(2026, 10, 13),
          ),
        ),
      );
      unwrap(await store.deleteHistory('h1'));
      expect(unwrap(await store.history()), isEmpty);
      expect(await File(historyPath).exists(), isFalse);
    });

    test('history heals paths from a rotated app-container root', () async {
      // The photo file lives under the CURRENT documents root…
      final dir = Directory('${tempDir.path}/peoplegone/history');
      await dir.create(recursive: true);
      final file = File('${dir.path}/h9.jpg');
      await file.writeAsBytes(<int>[9, 9, 9]);
      // …but the index still points at the OLD container's absolute path
      // (what an iOS reinstall does to stored paths).
      unwrap(
        await store.addHistory(
          HistoryEntry(
            id: 'h9',
            localPath: '/old-container/Documents/peoplegone/history/h9.jpg',
            savedAt: DateTime.utc(2026, 10, 14),
          ),
        ),
      );
      final entries = unwrap(await store.history());
      expect(entries.single.localPath, file.path);
      expect(await File(entries.single.localPath).exists(), isTrue);
    });
  });

  group('session results', () {
    test('writeSessionResult writes the exact bytes', () async {
      final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final path = unwrap(await store.writeSessionResult(bytes));
      expect(await File(path).readAsBytes(), bytes);
    });

    test('adoptIntoHistory copies (session file survives)', () async {
      final session = unwrap(
        await store.writeSessionResult(Uint8List.fromList(<int>[9, 9])),
      );
      final historyPath = unwrap(await store.adoptIntoHistory(session, 'h2'));
      expect(await File(historyPath).exists(), isTrue);
      expect(await File(session).exists(), isTrue);
    });
  });

  group('free saves', () {
    test('starts at 0 and increments on consumeFreeSave', () async {
      expect(unwrap(await store.freeSavesUsed()), 0);
      unwrap(await store.consumeFreeSave());
      unwrap(await store.consumeFreeSave());
      expect(unwrap(await store.freeSavesUsed()), 2);
    });

    test('a new month resets the counter', () async {
      unwrap(await store.consumeFreeSave());
      now = DateTime.utc(2026, 11, 1);
      expect(unwrap(await store.freeSavesUsed()), 0);
    });

    test('reset date is the first of the next month (UTC)', () async {
      expect(
        unwrap(await store.freeSavesResetDate()),
        DateTime.utc(2026, 11, 1),
      );
    });

    test('reset date rolls over the year boundary', () async {
      now = DateTime.utc(2026, 12, 20);
      expect(
        unwrap(await store.freeSavesResetDate()),
        DateTime.utc(2027, 1, 1),
      );
    });
  });

  group('consent', () {
    test('null until accepted, then round-trips the version', () async {
      expect(unwrap(await store.acceptedConsentVersion()), isNull);
      unwrap(await store.setAcceptedConsentVersion(1));
      expect(unwrap(await store.acceptedConsentVersion()), 1);
    });
  });

  group('intro_seen_v1', () {
    test('false initially, then true once setIntroSeen is called', () async {
      expect(unwrap(await store.introSeen()), isFalse);
      unwrap(await store.setIntroSeen());
      expect(unwrap(await store.introSeen()), isTrue);
    });
  });
}
