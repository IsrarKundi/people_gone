import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../services/processing/processing_api.dart';
import '../../../services/storage/local_store.dart';
import '../model/brush_args.dart';

/// Brush (S5 / FR-09): the rescue tool. The user paints over anything
/// that should also be removed; Apply sends ONLY the painted region
/// for a crop-local touch-up. A touch-up never consumes a save.
class BrushController extends GetxController {
  BrushController({
    required this.processingApi,
    required this.localStore,
    this.initialArgs,
  });

  final ProcessingApi processingApi;
  final LocalStore localStore;
  final BrushArgs? initialArgs;

  late final BrushArgs args;

  /// Strokes in IMAGE pixel coordinates: one list of points per stroke.
  final strokes = <List<Offset>>[].obs;

  /// Brush radius in DISPLAY pixels, set by the size slider (8–64).
  final brushSizeDisplay = 24.0.obs;

  final isBusy = false.obs;

  /// Real upload fraction for the touch-up call (0.0–1.0); determinate
  /// progress is shown for the upload only (Design Direction R3).
  final uploadFraction = 0.0.obs;

  /// The photo's pixel size once loaded; null until then.
  final imageSize = Rxn<Size>();

  final loadError = RxnString();

  double _fittedScale = 1.0;

  /// Display → image scale of the fitted photo on screen; the view
  /// reports it whenever its fitted rect changes.
  double get fittedScale => _fittedScale;

  void setFittedScale(double scale) {
    if (scale > 0 && scale.isFinite) _fittedScale = scale;
  }

  /// Brush radius in image pixels: the display-space slider value
  /// divided by the fitted scale.
  double get brushRadiusImagePx => brushSizeDisplay.value / _fittedScale;

  double get brushDiameterImagePx => brushRadiusImagePx * 2;

  bool get canApply =>
      strokes.any((stroke) => stroke.isNotEmpty) && !isBusy.value;

  bool get hasStrokes => strokes.any((stroke) => stroke.isNotEmpty);

  @override
  void onInit() {
    super.onInit();
    args = initialArgs ?? _argsFromRoute();
    unawaited(loadImageSize());
  }

  BrushArgs _argsFromRoute() {
    final raw = Get.arguments;
    return switch (raw) {
      BrushArgs args => args,
      String path => BrushArgs(imagePath: path),
      Map<dynamic, dynamic> map => BrushArgs(
        imagePath: map['imagePath'] as String,
      ),
      _ => throw ArgumentError('Brush route requires BrushArgs'),
    };
  }

  /// Loads the photo's pixel size from its file bytes via the codec
  /// (service-free: no path_provider needed, the path comes in args).
  Future<Size?> loadImageSize() async {
    try {
      final bytes = await File(args.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      imageSize.value = size;
      return size;
    } on Object {
      loadError.value = AppStrings.errorGeneric;
      return null;
    }
  }

  void setBrushSize(double displayPx) {
    brushSizeDisplay.value = displayPx.clamp(8, 64);
  }

  void startStroke(Offset imagePoint) {
    if (isBusy.value) return;
    strokes.add(<Offset>[imagePoint]);
  }

  void addStrokePoint(Offset imagePoint) {
    if (isBusy.value) return;
    if (strokes.isEmpty) {
      startStroke(imagePoint);
      return;
    }
    strokes.last.add(imagePoint);
    strokes.refresh();
  }

  void endStroke() {
    if (strokes.isNotEmpty && strokes.last.isEmpty) {
      strokes.removeLast();
    }
  }

  void undoStroke() {
    if (strokes.isNotEmpty) strokes.removeLast();
  }

  void clearStrokes() => strokes.clear();

  /// Rasterizes the painted mask at FULL image resolution: transparent
  /// background, white round-cap strokes, width = the brush diameter
  /// in image pixels. Returns an empty list before the size loads.
  Future<Uint8List> rasterizeMask() async {
    final size = imageSize.value;
    if (size == null || size.isEmpty) return Uint8List(0);
    final width = size.width.round();
    final height = size.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final diameter = brushDiameterImagePx;
    final strokePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = diameter;
    final dotPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, brushRadiusImagePx, dotPaint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, strokePaint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List() ?? Uint8List(0);
  }

  /// Apply (FR-09): upload the photo + mask, write the returned bytes
  /// to a session file, and return to the caller with its path. On
  /// failure the user STAYS here with their strokes intact.
  Future<String?> apply() async {
    if (!canApply) return null;
    isBusy.value = true;
    uploadFraction.value = 0;
    final maskPng = await rasterizeMask();
    if (maskPng.isEmpty) {
      isBusy.value = false;
      AppSnackbar.error(AppStrings.errorGeneric);
      return null;
    }
    final result = await processingApi.touchupPhoto(
      localPath: args.imagePath,
      maskPng: maskPng,
      onUploadProgress: (fraction) => uploadFraction.value = fraction,
    );
    switch (result) {
      case Success<TouchupOutcome>(:final value):
        final written = await localStore.writeSessionResult(value.resultBytes);
        isBusy.value = false;
        switch (written) {
          case Success<String>(:final value):
            if (Get.key.currentState?.canPop() ?? false) {
              Get.back<String>(result: value);
            }
            return value;
          case Failure<String>(:final failure):
            AppSnackbar.error(failure.userMessageKey);
            return null;
        }
      case Failure<TouchupOutcome>(:final failure):
        isBusy.value = false;
        AppSnackbar.error(failure.userMessageKey);
        return null;
    }
  }

  void cancel() => Get.back<String>();
}
