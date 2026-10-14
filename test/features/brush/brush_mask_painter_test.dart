import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/features/brush/widgets/brush_mask_painter.dart';

/// Phase D (X14): the suggested reflection region is an outline
/// guide only — the painter must draw it without touching the
/// stroke model, and a run with no region behaves exactly as before.
void main() {
  void paintWith(BrushMaskPainter painter) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(400, 300));
    recorder.endRecording().dispose();
  }

  test('paints strokes plus a suggested-region outline', () {
    paintWith(
      const BrushMaskPainter(
        strokes: <List<Offset>>[
          <Offset>[Offset(10, 10), Offset(50, 50)],
        ],
        strokeDiameterImagePx: 20,
        scale: 0.5,
        color: Colors.red,
        suggestedRegion: <int>[100, 60, 300, 240],
        guideColor: Colors.blue,
      ),
    );
  });

  test('paints with no suggested region (unchanged behaviour)', () {
    paintWith(
      const BrushMaskPainter(
        strokes: <List<Offset>>[],
        strokeDiameterImagePx: 20,
        scale: 0.5,
        color: Colors.red,
      ),
    );
  });

  test('ignores a malformed suggested region', () {
    paintWith(
      const BrushMaskPainter(
        strokes: <List<Offset>>[],
        strokeDiameterImagePx: 20,
        scale: 0.5,
        color: Colors.red,
        suggestedRegion: <int>[1, 2],
        guideColor: Colors.blue,
      ),
    );
  });
}
