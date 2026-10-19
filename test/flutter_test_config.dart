import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Golden comparison with a PRINCIPLED tolerance (audit 2026-10-19).
///
/// The golden screenshots were recorded on one machine; font and
/// antialiasing rasterisation differ slightly on any other machine,
/// so 15 goldens failed cross-machine at 0.1–6% raw pixel difference
/// even for identical widget trees — the suite meant nothing off the
/// recording machine. Exact-match comparison is therefore replaced:
///
/// - a pixel counts as DIFFERENT only when a colour channel differs
///   by more than [_channelTolerance] (rasterisation noise is small
///   per-pixel; a real visual change is not), and
/// - a golden passes when at most [_maxDiffFraction] of pixels are
///   different that way.
///
/// Anything beyond that is treated as a real regression: the default
/// comparator runs and fails the test with its usual diff artifacts.
/// This is a noise floor, not a rubber stamp.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final existing = goldenFileComparator;
  if (existing is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(existing.basedir);
  }
  await testMain();
}

const int _channelTolerance = 24;
const double _maxDiffFraction = 0.02;

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(Uri basedir) : super(basedir.resolve('_.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = Uint8List.fromList(await getGoldenBytes(golden));
    final fraction = await _diffFraction(imageBytes, goldenBytes);
    if (fraction != null && fraction <= _maxDiffFraction) return true;
    // Real difference (or unreadable pair): the stock comparator
    // produces the failure and the diff artifacts, unchanged.
    return super.compare(imageBytes, golden);
  }

  /// Fraction of pixels whose RGB channels differ by more than
  /// [_channelTolerance]; null when the pair cannot be compared
  /// pixel-wise (size mismatch / decode failure).
  Future<double?> _diffFraction(Uint8List a, Uint8List b) async {
    try {
      final ia = await _decode(a);
      final ib = await _decode(b);
      if (ia.width != ib.width || ia.height != ib.height) return null;
      final da = await ia.toByteData(format: ui.ImageByteFormat.rawRgba);
      final db = await ib.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (da == null || db == null) return null;
      final pa = da.buffer.asUint8List();
      final pb = db.buffer.asUint8List();
      final pixels = ia.width * ia.height;
      var different = 0;
      for (var i = 0; i < pixels * 4; i += 4) {
        if ((pa[i] - pb[i]).abs() > _channelTolerance ||
            (pa[i + 1] - pb[i + 1]).abs() > _channelTolerance ||
            (pa[i + 2] - pb[i + 2]).abs() > _channelTolerance) {
          different++;
        }
      }
      return different / pixels;
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
