import 'package:flutter/material.dart';

import '../../../services/processing/processing_api.dart';

/// Pure geometry for the S4 photo canvas: box scaling into the
/// displayed photo band and per-kind hit-testing (Review 04 F2).
/// Split out of proposal_photo_canvas.dart to keep files under the
/// ~400-line convention cap; re-exported from there so existing
/// imports keep working.

/// Maps a person's full-resolution PIXEL box into the displayed photo
/// band (Review 04 F2). Pure geometry — unit-tested. [imageSize] is
/// the photo's intrinsic size (DetectionProposal.inputDimensions);
/// [bandSize] is the size the contain-fit photo actually paints into.
Rect scalePersonBoxToBand({
  required List<int> box,
  required Size imageSize,
  required Size bandSize,
}) {
  if (box.length < 4 || imageSize.isEmpty || bandSize.isEmpty) {
    return Rect.zero;
  }
  final scaleX = bandSize.width / imageSize.width;
  final scaleY = bandSize.height / imageSize.height;
  return Rect.fromLTRB(
    box[0] * scaleX,
    box[1] * scaleY,
    box[2] * scaleX,
    box[3] * scaleY,
  );
}

/// Hit-tests a tap point given in BAND coordinates against every
/// person's scaled box (Review 04 F2). On overlapping boxes the
/// SMALLEST containing box wins — a distant small person in front of
/// a large one stays tappable. Returns the person's id, or null.
int? personIdAtBandPoint({
  required List<DetectedPerson> persons,
  required Offset point,
  required Size imageSize,
  required Size bandSize,
}) {
  int? bestId;
  var bestArea = double.infinity;
  for (final person in persons) {
    final rect = scalePersonBoxToBand(
      box: person.box,
      imageSize: imageSize,
      bandSize: bandSize,
    );
    if (rect.isEmpty || !rect.contains(point)) continue;
    final area = rect.width * rect.height;
    if (area < bestArea) {
      bestArea = area;
      bestId = person.id;
    }
  }
  return bestId;
}

/// Same hit-test for belongings (Phase A). The canvas resolves tap
/// priority across kinds (design X7): people first, then attached
/// belongings, then ambiguous items — so this helper is called per
/// kind, in that order, and the first hit wins.
int? belongingIdAtBandPoint({
  required List<DetectedBelonging> items,
  required Offset point,
  required Size imageSize,
  required Size bandSize,
}) {
  int? bestId;
  var bestArea = double.infinity;
  for (final item in items) {
    final rect = scalePersonBoxToBand(
      box: item.box,
      imageSize: imageSize,
      bandSize: bandSize,
    );
    if (rect.isEmpty || !rect.contains(point)) continue;
    final area = rect.width * rect.height;
    if (area < bestArea) {
      bestArea = area;
      bestId = item.id;
    }
  }
  return bestId;
}

/// Same hit-test for distractions (Phase B). Called LAST in the
/// canvas's tap priority (X7): people > belongings > distractions —
/// a distraction under a person is reached only through its chip.
int? distractionIdAtBandPoint({
  required List<DetectedDistraction> distractions,
  required Offset point,
  required Size imageSize,
  required Size bandSize,
}) {
  int? bestId;
  var bestArea = double.infinity;
  for (final distraction in distractions) {
    final rect = scalePersonBoxToBand(
      box: distraction.box,
      imageSize: imageSize,
      bandSize: bandSize,
    );
    if (rect.isEmpty || !rect.contains(point)) continue;
    final area = rect.width * rect.height;
    if (area < bestArea) {
      bestArea = area;
      bestId = distraction.id;
    }
  }
  return bestId;
}
