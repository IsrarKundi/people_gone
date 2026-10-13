import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/core/widgets/photo_surface.dart';

/// Review 02 F1/F3/A3 geometry: the photo band is the contain-fit
/// rect the photo actually paints into — chrome pins to it, not to
/// the screen.
void main() {
  group('photoBandRect', () {
    test('portrait photo in a square area pillarboxes, centred', () {
      final band = photoBandRect(const Size(400, 400), const Size(100, 200));
      expect(band, const Rect.fromLTWH(100, 0, 200, 400));
    });

    test('landscape photo in a square area letterboxes, centred', () {
      final band = photoBandRect(const Size(400, 400), const Size(200, 100));
      expect(band, const Rect.fromLTWH(0, 100, 400, 200));
    });

    test('matching aspect fills the area', () {
      final band = photoBandRect(const Size(400, 200), const Size(200, 100));
      expect(band, const Rect.fromLTWH(0, 0, 400, 200));
    });

    test('unknown image size falls back to the full area', () {
      final band = photoBandRect(const Size(400, 200), Size.zero);
      expect(band, const Rect.fromLTWH(0, 0, 400, 200));
    });
  });

  testWidgets('PhotoSurface reports the resolved band to its builder', (
    tester,
  ) async {
    // A real 200x100 PNG, generated — no fixture file needed.
    final bytes = await tester.runAsync<Uint8List>(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 200, 100),
        Paint()..color = const Color(0xFF336699),
      );
      final image = await recorder.endRecording().toImage(200, 100);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    Rect? seenBand;
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoSurface(
          imageProvider: MemoryImage(bytes!),
          builder: (context, band) {
            seenBand = band;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    // Default test surface is 800x600: a 2:1 photo fits the width and
    // letterboxes to 800x400, centred vertically.
    expect(seenBand, isNotNull);
    expect(seenBand!.left, closeTo(0, 0.5));
    expect(seenBand!.top, closeTo(100, 0.5));
    expect(seenBand!.width, closeTo(800, 0.5));
    expect(seenBand!.height, closeTo(400, 0.5));
  });
}
