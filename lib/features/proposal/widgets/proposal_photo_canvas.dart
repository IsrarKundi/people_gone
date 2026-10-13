import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';
import '../../../services/processing/processing_api.dart';

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

/// Renders the photo with per-person bounding-box outlines + low-alpha
/// fills in the removal/keeper overlay tokens (Review 04 F2). Boxes
/// arrive in full-resolution pixels and are scaled into the photo
/// band for BOTH painting and hit-testing; a tap inside a person's
/// box toggles them, and each box is a TalkBack element (direction R2).
class ProposalPhotoCanvas extends StatelessWidget {
  const ProposalPhotoCanvas({
    super.key,
    required this.photoPath,
    required this.persons,
    required this.imageSize,
    required this.onTogglePerson,
  });

  final String photoPath;
  final List<DetectedPerson> persons;

  /// The photo's intrinsic size; null until detection has supplied it
  /// (no overlays can be mapped before then, so none are painted).
  final Size? imageSize;
  final void Function(int id) onTogglePerson;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final file = File(photoPath);

    return PhotoSurface(
      imageProvider: ResizeImage(
        FileImage(file),
        width: MediaQuery.sizeOf(context).width.toInt(),
      ),
      builder: (context, band) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(
              file,
              fit: BoxFit.contain,
              cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            if (imageSize != null && band.width > 0 && band.height > 0)
              Positioned(
                left: band.left,
                top: band.top,
                width: band.width,
                height: band.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final id = personIdAtBandPoint(
                      persons: persons,
                      point: details.localPosition,
                      imageSize: imageSize!,
                      bandSize: band.size,
                    );
                    if (id != null) onTogglePerson(id);
                  },
                  child: CustomPaint(
                    painter: _OverlayPainter(
                      persons: persons,
                      imageSize: imageSize!,
                      palette: p,
                      cornerRadius: s.radiusSm,
                      onTogglePerson: onTogglePerson,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.persons,
    required this.imageSize,
    required this.palette,
    required this.cornerRadius,
    required this.onTogglePerson,
  });

  final List<DetectedPerson> persons;
  final Size imageSize;
  final AppPalette palette;
  final double cornerRadius;
  final void Function(int id) onTogglePerson;

  @override
  void paint(Canvas canvas, Size size) {
    if (persons.isEmpty) return;

    for (final person in persons) {
      final rect = scalePersonBoxToBand(
        box: person.box,
        imageSize: imageSize,
        bandSize: size,
      );
      if (rect.isEmpty) continue;

      // Overlay tokens only: a solid-token stroke and a low-alpha
      // fill of the same token (Conventions §6.1 overlay roles).
      final token = person.isKeeper
          ? palette.overlayKept
          : palette.overlayRemoved;
      final strokePaint = Paint()
        ..color = token.withValues(alpha: 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final fillPaint = Paint()
        ..color = token.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      final rounded = RRect.fromRectAndRadius(
        rect,
        Radius.circular(cornerRadius),
      );
      canvas.drawRRect(rounded, fillPaint);
      canvas.drawRRect(rounded, strokePaint);
    }
  }

  /// TalkBack (direction R2): every person is a focusable element
  /// whose activation toggles them, with the action named by outcome.
  @override
  SemanticsBuilderCallback get semanticsBuilder {
    return (Size size) {
      return <CustomPainterSemantics>[
        for (final person in persons)
          CustomPainterSemantics(
            rect: scalePersonBoxToBand(
              box: person.box,
              imageSize: imageSize,
              bandSize: size,
            ),
            properties: SemanticsProperties(
              textDirection: TextDirection.ltr,
              label: person.isKeeper
                  ? AppStrings.proposalPersonProtected.trParams(
                      <String, String>{'n': '${person.id + 1}'},
                    )
                  : AppStrings.proposalPersonMarkedRemove.trParams(
                      <String, String>{'n': '${person.id + 1}'},
                    ),
              button: true,
              onTap: () => onTogglePerson(person.id),
            ),
          ),
      ];
    };
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.persons != persons || oldDelegate.imageSize != imageSize;
}
