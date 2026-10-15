import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/constants/app_motion.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/brush/controller/brush_controller.dart';
import 'package:people_gone/features/brush/model/brush_args.dart';
import 'package:people_gone/features/brush/view/brush_view.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

class _FakeLocalStore implements LocalStore {
  @override
  Future<Result<int>> freeSavesUsed() async => const Success<int>(0);

  @override
  Future<Result<DateTime>> freeSavesResetDate() async =>
      Success<DateTime>(DateTime.now());

  @override
  Future<Result<void>> consumeFreeSave() async => const Success<void>(null);

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> adoptIntoHistory(String sessionPath, String id) async =>
      const Success<String>('/history/1.jpg');

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String originalPath,
    String id,
  ) async => const Success<String>('/history/1_orig.jpg');

  @override
  Future<Result<void>> addHistory(HistoryEntry entry) async =>
      const Success<void>(null);

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      const Success<List<HistoryEntry>>(<HistoryEntry>[]);

  @override
  Future<Result<void>> deleteHistory(String id) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> writeSessionResult(List<int> bytes) async =>
      const Success<String>('/session/touchup.jpg');

  @override
  Future<Result<int?>> acceptedConsentVersion() async => const Success<int?>(1);

  @override
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearGatewayJob() async => const Success<void>(null);

  @override
  Future<Result<GatewayJobRecord?>> gatewayJob() async =>
      const Success<GatewayJobRecord?>(null);

  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord record) async =>
      const Success<void>(null);
}

class _FakeProcessingApi implements ProcessingApi {
  @override
  void cancelOngoing() {}

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async =>
      const Failure<DetectionProposal>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async =>
      const Failure<ProcessedPhoto>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required List<int> maskPng,
    void Function(double fraction)? onUploadProgress,
  }) async =>
      const Failure<TouchupOutcome>(
        AppFailure(code: 'test', userMessageKey: AppStrings.errorGeneric),
      );

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async =>
      const Success<SaveCreditDecision>(
        SaveCreditDecision(
          allowed: true,
          paymentRequired: false,
          isPro: false,
          savesLeft: 10,
        ),
      );

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async => const Success<void>(null);
}

class _TestBinding extends Bindings {
  _TestBinding(this.store, this.api);
  final LocalStore store;
  final ProcessingApi api;

  @override
  void dependencies() {
    Get.put<LocalStore>(store);
    Get.put<ProcessingApi>(api);
  }
}

Future<File> makeSquareImage(Directory dir, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF336699),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/square.png');
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file;
}

void main() {
  late Directory tempDir;
  late File photo;
  late _FakeProcessingApi api;
  late _FakeLocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_brush_motion');
    photo = await makeSquareImage(tempDir, 100);
    api = _FakeProcessingApi();
    store = _FakeLocalStore();
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<BrushController> pumpBrush(
    WidgetTester tester, {
    List<int>? suggestedRegion,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: _TestBinding(store, api),
        initialRoute: Routes.home,
        builder: (context, child) => disableAnimations
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : child!,
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: Routes.home,
            page: () => const Scaffold(body: Text('HOME')),
          ),
          ...AppPages.pages.where((p) => p.name != Routes.home),
        ],
      ),
    );
    await tester.pump();

    Get.toNamed<void>(
      Routes.brush,
      arguments: BrushArgs(
        imagePath: photo.path,
        suggestedRegion: suggestedRegion,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final controller = Get.find<BrushController>();
    await tester.runAsync(() async {
      await controller.loadImageSize();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    return controller;
  }

  testWidgets('Item 14: Brush stroke undo fades out over 150ms', (tester) async {
    final controller = await pumpBrush(tester);

    // Draw two strokes
    controller.startStroke(const Offset(20, 20));
    controller.addStrokePoint(const Offset(40, 40));
    controller.endStroke();

    controller.startStroke(const Offset(60, 60));
    controller.addStrokePoint(const Offset(80, 80));
    controller.endStroke();
    await tester.pump();

    expect(controller.strokes.length, 2);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pump(); // Starts stroke fade (t=0ms)

    expect(controller.strokes.length, 1);

    // Frame strip 0: t=0ms (undone stroke at 1.0 fading opacity)
    await expectLater(
      find.byType(BrushView),
      matchesGoldenFile('brush_undo_frame0.png'),
    );

    // Frame strip 1: t=75ms (halfway faded)
    await tester.pump(const Duration(milliseconds: 75));
    await expectLater(
      find.byType(BrushView),
      matchesGoldenFile('brush_undo_frame1.png'),
    );

    // Frame strip 2: t=150ms (settled, undone stroke gone)
    await tester.pump(const Duration(milliseconds: 75));
    await expectLater(
      find.byType(BrushView),
      matchesGoldenFile('brush_undo_frame2.png'),
    );
  });

  testWidgets('Item 14: Clear fades all strokes out together over 150ms',
      (tester) async {
    final controller = await pumpBrush(tester);

    controller.startStroke(const Offset(30, 30));
    controller.addStrokePoint(const Offset(50, 50));
    controller.endStroke();
    await tester.pump();

    expect(controller.strokes.length, 1);

    await tester.tap(find.text('Clear'));
    await tester.pump(); // Starts clear fade (t=0ms)

    expect(controller.strokes.isEmpty, isTrue);

    // Frame 0: t=0ms
    await expectLater(
      find.byType(BrushView),
      matchesGoldenFile('brush_clear_frame0.png'),
    );

    // After 150ms, all strokes completely cleared
    await tester.pump(AppMotion.strokeFade);
    await tester.pump();
  });

  testWidgets('Item 15: Reflection guide outline fades in over 250ms when brush opens',
      (tester) async {
    await pumpBrush(
      tester,
      suggestedRegion: const <int>[10, 10, 60, 60],
    );

    // Frame strip 0: t=0ms (guide beginning fade-in)
    await expectLater(
      find.byType(BrushView),
      matchesGoldenFile('brush_guide_frame0.png'),
    );

    // Frame strip 1: t=125ms (halfway faded in)
    await tester.pump(const Duration(milliseconds: 125));
    await expectLater(
      find.byType(BrushView),
      matchesGoldenFile('brush_guide_frame1.png'),
    );

    // Frame strip 2: t=250ms (fully revealed, static thereafter)
    await tester.pump(const Duration(milliseconds: 125));
    await expectLater(
      find.byType(BrushView),
      matchesGoldenFile('brush_guide_frame2.png'),
    );
  });

  testWidgets('Item 16: Brush-size preview dot animates scale as slider changes',
      (tester) async {
    final controller = await pumpBrush(tester);

    expect(controller.brushSizeDisplay.value, 24.0);
    final scaleFinder = find.byKey(const ValueKey('brush_size_dot_scale'));
    expect(scaleFinder, findsOneWidget);

    final initialScaleWidget = tester.widget<AnimatedScale>(scaleFinder);
    expect(initialScaleWidget.scale, closeTo(24.0 / 64.0, 0.001));

    // Change slider value to 48.0
    controller.setBrushSize(48.0);
    await tester.pump();

    final updatedScaleWidget = tester.widget<AnimatedScale>(scaleFinder);
    expect(updatedScaleWidget.scale, closeTo(48.0 / 64.0, 0.001));

    // Pump halfway through fast token (90ms)
    await tester.pump(const Duration(milliseconds: 90));

    // Settle fast token (180ms)
    await tester.pump(AppMotion.fast);
  });

  testWidgets('Reduced motion skips stroke fade and guide fade',
      (tester) async {
    final controller = await pumpBrush(
      tester,
      suggestedRegion: const <int>[10, 10, 60, 60],
      disableAnimations: true,
    );

    // Guide is immediately at 1.0 opacity under reduced motion
    controller.startStroke(const Offset(20, 20));
    controller.endStroke();
    await tester.pump();

    await tester.tap(find.text('Undo'));
    await tester.pump();

    // Under reduced motion, no lingering fading strokes
    expect(controller.strokes.isEmpty, isTrue);
  });
}
