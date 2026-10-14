import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';
import '../../../services/processing/processing_api.dart';
import '../model/belonging_label.dart';

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
    this.belongings = const <DetectedBelonging>[],
    this.detachedIds = const <int>{},
    this.includedItemIds = const <int>{},
    this.onToggleBelonging,
  });

  final String photoPath;
  final List<DetectedPerson> persons;

  /// The photo's intrinsic size; null until detection has supplied it
  /// (no overlays can be mapped before then, so none are painted).
  final Size? imageSize;
  final void Function(int id) onTogglePerson;

  /// Belongings (Phase A): attached items are drawn joined to their
  /// person's treatment (X9a); detached and kept ambiguous items take
  /// a thin neutral outline (X7); included ambiguous items read in
  /// the removal colour.
  final List<DetectedBelonging> belongings;
  final Set<int> detachedIds;
  final Set<int> includedItemIds;
  final void Function(int id)? onToggleBelonging;

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
                    // Tap priority (X7): people > attached
                    // belongings > ambiguous items. A tap toggles
                    // the winning item only.
                    final personId = personIdAtBandPoint(
                      persons: persons,
                      point: details.localPosition,
                      imageSize: imageSize!,
                      bandSize: band.size,
                    );
                    if (personId != null) {
                      onTogglePerson(personId);
                      return;
                    }
                    if (onToggleBelonging == null) return;
                    final attached = belongings
                        .where((b) => b.tier == BelongingTier.attached)
                        .toList();
                    final attachedId = belongingIdAtBandPoint(
                      items: attached,
                      point: details.localPosition,
                      imageSize: imageSize!,
                      bandSize: band.size,
                    );
                    if (attachedId != null) {
                      onToggleBelonging!(attachedId);
                      return;
                    }
                    final ambiguous = belongings
                        .where((b) => b.tier == BelongingTier.ambiguous)
                        .toList();
                    final itemId = belongingIdAtBandPoint(
                      items: ambiguous,
                      point: details.localPosition,
                      imageSize: imageSize!,
                      bandSize: band.size,
                    );
                    if (itemId != null) onToggleBelonging!(itemId);
                  },
                  child: CustomPaint(
                    painter: _OverlayPainter(
                      persons: persons,
                      belongings: belongings,
                      detachedIds: detachedIds,
                      includedItemIds: includedItemIds,
                      imageSize: imageSize!,
                      palette: p,
                      cornerRadius: s.radiusSm,
                      onTogglePerson: onTogglePerson,
                      onToggleBelonging: onToggleBelonging,
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
    required this.belongings,
    required this.detachedIds,
    required this.includedItemIds,
    required this.imageSize,
    required this.palette,
    required this.cornerRadius,
    required this.onTogglePerson,
    required this.onToggleBelonging,
  });

  final List<DetectedPerson> persons;
  final List<DetectedBelonging> belongings;
  final Set<int> detachedIds;
  final Set<int> includedItemIds;
  final Size imageSize;
  final AppPalette palette;
  final double cornerRadius;
  final void Function(int id) onTogglePerson;
  final void Function(int id)? onToggleBelonging;

  DetectedPerson? _ownerOf(DetectedBelonging item) {
    for (final person in persons) {
      if (person.id == item.personId) return person;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
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

    // Belongings (X7/X9a): an attached item reads as part of its
    // person (same token, same fill); a detached item and a kept
    // ambiguous item take a thin NEUTRAL outline only — emerald is
    // reserved for protected people, and "not selected" is not
    // "protected"; an included ambiguous item reads as removal.
    for (final item in belongings) {
      final rect = scalePersonBoxToBand(
        box: item.box,
        imageSize: imageSize,
        bandSize: size,
      );
      if (rect.isEmpty) continue;
      final rounded = RRect.fromRectAndRadius(
        rect,
        Radius.circular(cornerRadius),
      );

      Color? token;
      if (item.tier == BelongingTier.attached &&
          !detachedIds.contains(item.id)) {
        final owner = _ownerOf(item);
        token = (owner?.isKeeper ?? false)
            ? palette.overlayKept
            : palette.overlayRemoved;
      } else if (item.tier == BelongingTier.ambiguous &&
          includedItemIds.contains(item.id)) {
        token = palette.overlayRemoved;
      }

      if (token != null) {
        final fillPaint = Paint()
          ..color = token.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        final strokePaint = Paint()
          ..color = token.withValues(alpha: 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRRect(rounded, fillPaint);
        canvas.drawRRect(rounded, strokePaint);
      } else {
        final neutralPaint = Paint()
          ..color = palette.border.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(rounded, neutralPaint);
      }
    }
  }

  /// TalkBack (direction R2): every person is a focusable element
  /// whose activation toggles them, with the action named by outcome.
  /// Belongings are elements too (Phase A): an attached item names
  /// its detach/re-attach outcome; an ambiguous item names its
  /// include/keep outcome.
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
        if (onToggleBelonging != null)
          for (final item in belongings)
            CustomPainterSemantics(
              rect: scalePersonBoxToBand(
                box: item.box,
                imageSize: imageSize,
                bandSize: size,
              ),
              properties: SemanticsProperties(
                textDirection: TextDirection.ltr,
                label: _itemSemanticsLabel(item),
                button: true,
                onTap: () => onToggleBelonging!(item.id),
              ),
            ),
      ];
    };
  }

  String _itemSemanticsLabel(DetectedBelonging item) {
    final name = belongingClassLabelKey(item.detectedClass).tr;
    if (item.tier == BelongingTier.attached) {
      final params = <String, String>{
        'name': name,
        'n': '${(item.personId ?? 0) + 1}',
      };
      return detachedIds.contains(item.id)
          ? AppStrings.proposalBelongingDetachedSemantics.trParams(params)
          : AppStrings.proposalBelongingDetachSemantics.trParams(params);
    }
    final params = <String, String>{'name': name};
    return includedItemIds.contains(item.id)
        ? AppStrings.proposalItemMarkedRemove.trParams(params)
        : AppStrings.proposalItemKeptSemantics.trParams(params);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.persons != persons ||
      oldDelegate.belongings != belongings ||
      oldDelegate.detachedIds != detachedIds ||
      oldDelegate.includedItemIds != includedItemIds ||
      oldDelegate.imageSize != imageSize;
}
