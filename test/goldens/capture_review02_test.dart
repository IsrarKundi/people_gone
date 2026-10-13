/// Review 02 screenshot-evidence harness (Design Direction §10).
///
/// ON-DEMAND ONLY: every case returns immediately unless PG_CAPTURE=1
/// is in the environment, so a plain `flutter test` stays green and
/// never touches these goldens. To capture:
///
///   PG_CAPTURE=1 flutter test --update-goldens \
///     test/goldens/capture_review02_test.dart
///
/// PNGs land in test/goldens/review02/ and are copied out to
/// ~/workspace/peoplegone/design/review02/ as review evidence — they
/// are NOT committed goldens. Screens are pumped through the real
/// routes/bindings with service fakes at the interface boundary, the
/// same construction the feature flow tests use; no production code is
/// modified to fake a state. The Result screen uses the owner's real
/// mosque photo and its real Modal-processed output.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/picker/controller/picker_controller.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

const String _originalPath =
    '/home/hatch/workspace/peoplegone/phase0-run/results/user-photo/input.jpg';
const String _resultPath =
    '/home/hatch/workspace/peoplegone/modal-deploy/smoke_output.jpg';

final bool _capture = Platform.environment['PG_CAPTURE'] == '1';
final bool _photosExist =
    File(_originalPath).existsSync() && File(_resultPath).existsSync();

/// LocalStore fake at the interface boundary (same shape as the flow
/// tests' fakes): counter, consent and history are plain fields.
class CaptureStore implements LocalStore {
  CaptureStore(this.sessionDir);
  final Directory sessionDir;
  int? consent;
  int used = 0;
  List<HistoryEntry> entries = <HistoryEntry>[];

  @override
  Future<Result<int?>> acceptedConsentVersion() async => Success<int?>(consent);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async {
    consent = version;
    return const Success<void>(null);
  }

  @override
  Future<Result<int>> freeSavesUsed() async => Success<int>(used);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.utc(2026, 11, 1));

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      Success<List<HistoryEntry>>(entries);

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> adoptIntoHistory(
    String sessionPath,
    String id,
  ) async => Success<String>(sessionPath);

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async {
    final file = File('${sessionDir.path}/session_result.jpg');
    file.writeAsBytesSync(bytes);
    return Success<String>(file.path);
  }

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);
}

/// ProcessingApi fake whose job can be held open at the "working"
/// stage: it reports the upload complete, then waits on [gate].
class CaptureApi implements ProcessingApi {
  Completer<Result<ProcessedPhoto>>? gate;

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    void Function(double fraction)? onUploadProgress,
  }) {
    onUploadProgress?.call(1.0);
    if (gate != null) return gate!.future;
    return Future<Result<ProcessedPhoto>>.value(
      const Failure<ProcessedPhoto>(
        AppFailure(
          code: 'server',
          userMessageKey: AppStrings.errorProcessingFailed,
        ),
      ),
    );
  }

  @override
  void cancelOngoing() {}
}

class CaptureBinding extends Bindings {
  CaptureBinding(this.store, this.api, this.picker);
  final LocalStore store;
  final ProcessingApi api;
  final PickerController picker;

  @override
  void dependencies() {
    Get.put<AppConfig>(AppConfig.fromEnvironment());
    Get.put<LocalStore>(store);
    Get.put<ProcessingApi>(api);
    Get.put<PickerController>(picker);
  }
}

void main() {
  late Directory tempDir;
  late CaptureStore store;
  late CaptureApi api;

  // The test binding does not auto-load the app's bundled fonts (text
  // renders as placeholder boxes and icons as empty squares without
  // this) — load Inter + MaterialIcons explicitly, as golden suites do.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final inter = FontLoader('Inter');
    for (final weight in <String>['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await inter.load();
    // MaterialIcons ships with the SDK, not the asset bundle: find the
    // .otf under the Flutter cache (walking up from the Dart binary)
    // and load its bytes directly. Degrades to a printed warning —
    // icons then render as squares in the evidence, never a hang.
    try {
      File? iconFile;
      var dir = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8 && iconFile == null; i++) {
        for (final rel in <String>[
          'artifacts/material_fonts/MaterialIcons-Regular.otf',
          'cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ]) {
          final candidate = File('${dir.path}/$rel');
          if (candidate.existsSync()) {
            iconFile = candidate;
            break;
          }
        }
        dir = dir.parent;
      }
      if (iconFile == null) {
        debugPrint('setUpAll: MaterialIcons font not found; icons will box');
      } else {
        final bytes = await iconFile.readAsBytes();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
        await icons.load();
      }
    } catch (e) {
      debugPrint('setUpAll: MaterialIcons load failed: $e');
    }
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_capture');
    store = CaptureStore(tempDir);
    api = CaptureApi();
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
    double textScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(780, 1688); // 390x844 @2x
    addTearDown(tester.view.reset);
    final picker = PickerController(
      pickImage: () async => XFile(_originalPath),
      maxBytes: 60 * 1024 * 1024,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        initialBinding: CaptureBinding(store, api, picker),
        initialRoute: Routes.home,
        getPages: AppPages.pages,
        // Mirrors main.dart: optional base scale, then the app clamp.
        builder: (context, child) {
          var media = MediaQuery.of(context);
          if (textScale != 1.0) {
            media = media.copyWith(textScaler: TextScaler.linear(textScale));
          }
          final clamped = media.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.30,
          );
          return MediaQuery(
            data: media.copyWith(textScaler: clamped),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Primes the image cache BEFORE the real app mounts any Image
  /// widget. A file load started inside the fake-async zone never
  /// resolves, and a precache attached to that pending load times out
  /// with it (both observed); in a bare shell + runAsync the same
  /// precache completes in ~200 ms. Both provider shapes the app uses
  /// are primed: plain FileImage (history tiles) and the cacheWidth
  /// ResizeImage at the harness's 390-wide surface (processing /
  /// result / compare).
  Future<void> primeImages(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      for (final provider in <ImageProvider>[
        FileImage(File(_originalPath)),
        FileImage(File(_resultPath)),
        ResizeImage.resizeIfNeeded(390, null, FileImage(File(_originalPath))),
        ResizeImage.resizeIfNeeded(390, null, FileImage(File(_resultPath))),
      ]) {
        try {
          await precacheImage(
            provider,
            context,
          ).timeout(const Duration(seconds: 20));
        } catch (e) {
          debugPrint('primeImages: $provider did not complete: $e');
        }
      }
    });
  }

  /// Two pumps: cache-hit images paint synchronously on mount.
  Future<void> settleFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> snap(WidgetTester tester, String name) {
    return expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('review02/$name'),
    );
  }

  List<HistoryEntry> sampleEntries() => <HistoryEntry>[
    HistoryEntry(
      id: 'h1',
      localPath: _resultPath,
      savedAt: DateTime(2026, 10, 13),
    ),
    HistoryEntry(
      id: 'h2',
      localPath: _originalPath,
      savedAt: DateTime(2026, 10, 12),
    ),
    HistoryEntry(
      id: 'h3',
      localPath: _resultPath,
      savedAt: DateTime(2026, 10, 11),
    ),
    HistoryEntry(
      id: 'h4',
      localPath: _originalPath,
      savedAt: DateTime(2026, 10, 10),
    ),
    HistoryEntry(
      id: 'h5',
      localPath: _resultPath,
      savedAt: DateTime(2026, 10, 9),
    ),
    HistoryEntry(
      id: 'h6',
      localPath: _originalPath,
      savedAt: DateTime(2026, 10, 8),
    ),
  ];

  testWidgets('S1 Home first-run, light', (tester) async {
    if (!_capture) return;
    await pumpApp(tester);
    await snap(tester, 's1_home_light.png');
  });

  testWidgets('S1 Home first-run, dark', (tester) async {
    if (!_capture) return;
    await pumpApp(tester, mode: ThemeMode.dark);
    await snap(tester, 's1_home_dark.png');
  });

  testWidgets('S1 Home first-run, text scale 1.30', (tester) async {
    if (!_capture) return;
    await pumpApp(tester, textScale: 1.30);
    await snap(tester, 's1_home_textscale130.png');
  });

  testWidgets('S1 Home with history, 7 of 10 saves left', (tester) async {
    if (!_capture) return;
    if (!_photosExist) {
      markTestSkipped('real evidence photos not present on this machine');
      return;
    }
    store.used = 3;
    store.entries = sampleEntries();
    await primeImages(tester);
    await pumpApp(tester);
    await settleFrames(tester);
    await snap(tester, 's1_home_history.png');
  });

  testWidgets('S2 Consent sheet over Home (first pick)', (tester) async {
    if (!_capture) return;
    if (!_photosExist) {
      markTestSkipped('real evidence photos not present on this machine');
      return;
    }
    store.consent = null; // first run: the gate must show
    await pumpApp(tester);
    await tester.tap(find.text('Pick a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Before your photo is uploaded'), findsOneWidget);
    await snap(tester, 's2_consent.png');
    // Dismiss the sheet so no route/timer outlives the test.
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('S6 Processing, working stage mid-job', (tester) async {
    if (!_capture) return;
    if (!_photosExist) {
      markTestSkipped('real evidence photos not present on this machine');
      return;
    }
    api.gate = Completer<Result<ProcessedPhoto>>();
    await primeImages(tester);
    await pumpApp(tester);
    Get.toNamed<void>(
      Routes.processing,
      arguments: const ProcessingArgs(photoPath: _originalPath),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Two elapsed ticks: the stage label + live clock are the evidence.
    await tester.pump(const Duration(seconds: 2));
    await settleFrames(tester);
    await snap(tester, 's6_processing.png');
    // Release the job as a failure so the elapsed timer is cancelled
    // before teardown (a pending periodic timer fails the test).
    api.gate!.complete(
      const Failure<ProcessedPhoto>(
        AppFailure(
          code: 'server',
          userMessageKey: AppStrings.errorProcessingFailed,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('S7 Result, real before/after pair', (tester) async {
    if (!_capture) return;
    if (!_photosExist) {
      markTestSkipped('real evidence photos not present on this machine');
      return;
    }
    await primeImages(tester);
    await pumpApp(tester);
    Get.offNamed<void>(
      Routes.result,
      arguments: const ProcessingOutcome(
        originalPath: _originalPath,
        resultPath: _resultPath,
        personsDetected: 13,
        keeperIds: <int>[0],
        removedIds: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        totalSeconds: 120.2,
        engineUsed: 'mat',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settleFrames(tester);
    // Default state: the cleaned photo, compare available.
    await snap(tester, 's7_result.png');
    // Bonus for the review: compare mode engaged (Before/After slider).
    await tester.tap(find.byIcon(Icons.compare));
    await tester.pump(const Duration(milliseconds: 100));
    await snap(tester, 's7_result_compare.png');
  });

  testWidgets('S9 History, populated grid', (tester) async {
    if (!_capture) return;
    if (!_photosExist) {
      markTestSkipped('real evidence photos not present on this machine');
      return;
    }
    store.entries = sampleEntries();
    await primeImages(tester);
    await pumpApp(tester);
    Get.toNamed<void>(Routes.history);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settleFrames(tester);
    await snap(tester, 's9_history.png');
  });

  testWidgets('S10 Settings', (tester) async {
    if (!_capture) return;
    store.used = 3;
    await pumpApp(tester);
    Get.toNamed<void>(Routes.settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, 's10_settings.png');
  });
}
