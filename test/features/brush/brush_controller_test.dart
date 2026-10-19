import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/features/brush/controller/brush_controller.dart';
import 'package:people_gone/features/brush/model/brush_args.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

class FakeProcessingApi implements ProcessingApi {
  Result<TouchupOutcome> touchupResult = Success<TouchupOutcome>(
    TouchupOutcome(
      resultBytes: Uint8List.fromList(<int>[1, 2, 3]),
      engineUsed: 'mat',
      totalSeconds: 1,
    ),
  );
  int touchupCalls = 0;
  Uint8List? lastMask;
  String? lastPath;
  double progressToReport = 0.5;

  @override
  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required Uint8List maskPng,
    void Function(double fraction)? onUploadProgress,
  }) async {
    touchupCalls++;
    lastPath = localPath;
    lastMask = maskPng;
    onUploadProgress?.call(progressToReport);
    return touchupResult;
  }

  @override
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    List<int>? removeItemIds,
    List<int>? detachedBelongingIds,
    void Function(double fraction)? onUploadProgress,
  }) async => const Failure<ProcessedPhoto>(
    AppFailure(code: 'unused', userMessageKey: AppStrings.errorGeneric),
  );

  @override
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  }) async => const Failure<DetectionProposal>(
    AppFailure(code: 'unused', userMessageKey: AppStrings.errorGeneric),
  );

  @override
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  }) async => const Failure<SaveCreditDecision>(
    AppFailure(code: 'unused', userMessageKey: AppStrings.errorGeneric),
  );

  @override
  Future<Result<void>> refundSaveCredit({
    required String idempotencyKey,
  }) async => const Success<void>(null);

  @override
  void cancelOngoing() {}
}

class FakeLocalStore implements LocalStore {
  String sessionPath = '/session/touched.jpg';
  Uint8List? lastWritten;

  @override
  Future<Result<String>> writeSessionResult(Uint8List bytes) async {
    lastWritten = bytes;
    return Success<String>(sessionPath);
  }

  @override
  Future<Result<List<HistoryEntry>>> history() async =>
      const Success<List<HistoryEntry>>(<HistoryEntry>[]);

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
  ) async => Success<String>('/history/$id.jpg');

  @override
  Future<Result<String>> adoptOriginalIntoHistory(
    String originalPath,
    String id,
  ) async => Success<String>('/history/${id}_orig.jpg');

  @override
  Future<Result<void>> saveToGallery(String localPath) async =>
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
  Future<Result<void>> setAcceptedConsentVersion(int version) async =>
      const Success<void>(null);

  GatewayJobRecord? gatewayJobRecord;

  @override
  Future<Result<void>> saveGatewayJob(GatewayJobRecord record) async {
    gatewayJobRecord = record;
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
  Future<Result<bool>> introSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setIntroSeen() async => const Success<void>(null);
}

/// Renders a solid [w]x[h] PNG to a temp file (real bytes, so the
/// controller's codec load sees the true pixel size).
Future<File> makeImageFile(Directory dir, int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF336699),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/photo_${w}x$h.png');
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file;
}

Future<({int width, int height, int opaque})> decodeMask(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  var opaque = 0;
  final bytes = raw!.buffer.asUint8List();
  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] > 0) opaque++;
  }
  final result = (width: image.width, height: image.height, opaque: opaque);
  image.dispose();
  codec.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File photo;
  late FakeProcessingApi api;
  late FakeLocalStore store;
  late BrushController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_brush_test');
    photo = await makeImageFile(tempDir, 100, 80);
    api = FakeProcessingApi();
    store = FakeLocalStore();
    controller = BrushController(
      processingApi: api,
      localStore: store,
      initialArgs: BrushArgs(imagePath: photo.path),
    );
    controller.args = BrushArgs(imagePath: photo.path);
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('loads the image pixel size from the file', () async {
    final size = await controller.loadImageSize();
    expect(size, const Size(100, 80));
    expect(controller.imageSize.value, const Size(100, 80));
  });

  test('stroke add / undo / clear state', () async {
    await controller.loadImageSize();
    expect(controller.canApply, isFalse);
    controller.startStroke(const Offset(10, 10));
    controller.addStrokePoint(const Offset(20, 12));
    controller.endStroke();
    expect(controller.strokes, hasLength(1));
    expect(controller.strokes.single, hasLength(2));
    expect(controller.canApply, isTrue);
    controller.startStroke(const Offset(30, 30));
    controller.endStroke();
    expect(controller.strokes, hasLength(2));
    controller.undoStroke();
    expect(controller.strokes, hasLength(1));
    controller.clearStrokes();
    expect(controller.strokes, isEmpty);
    expect(controller.canApply, isFalse);
  });

  test('brush radius derives from the display slider and fitted scale', () {
    controller.setFittedScale(2);
    controller.setBrushSize(24);
    expect(controller.brushRadiusImagePx, 12);
    expect(controller.brushDiameterImagePx, 24);
    controller.setBrushSize(200);
    expect(controller.brushSizeDisplay.value, 64);
  });

  test(
    'rasterized mask: image dimensions, empty before, painted after',
    () async {
      await controller.loadImageSize();
      controller.setFittedScale(1);
      controller.setBrushSize(10);
      final empty = await controller.rasterizeMask();
      final emptyInfo = await decodeMask(empty);
      expect(emptyInfo.width, 100);
      expect(emptyInfo.height, 80);
      expect(emptyInfo.opaque, 0);

      controller.startStroke(const Offset(50, 40));
      controller.addStrokePoint(const Offset(60, 40));
      controller.endStroke();
      final painted = await controller.rasterizeMask();
      final paintedInfo = await decodeMask(painted);
      expect(paintedInfo.width, 100);
      expect(paintedInfo.height, 80);
      expect(paintedInfo.opaque, greaterThan(0));
    },
  );

  test(
    'apply: fake API bytes are written and the session path returns',
    () async {
      await controller.loadImageSize();
      controller.startStroke(const Offset(50, 40));
      controller.endStroke();
      final returned = await controller.apply();
      expect(returned, '/session/touched.jpg');
      expect(api.touchupCalls, 1);
      expect(api.lastPath, photo.path);
      expect(api.lastMask, isNotNull);
      expect(store.lastWritten, <int>[1, 2, 3]);
      expect(controller.uploadFraction.value, 0.5);
      expect(controller.isBusy.value, isFalse);
    },
  );

  test('apply failure: stays with strokes intact', () async {
    await controller.loadImageSize();
    api.touchupResult = const Failure<TouchupOutcome>(
      AppFailure(
        code: 'server',
        userMessageKey: AppStrings.errorProcessingFailed,
      ),
    );
    controller.startStroke(const Offset(50, 40));
    controller.addStrokePoint(const Offset(55, 40));
    controller.endStroke();
    final returned = await controller.apply();
    expect(returned, isNull);
    expect(controller.strokes, hasLength(1));
    expect(controller.strokes.single, hasLength(2));
    expect(controller.isBusy.value, isFalse);
  });
}
