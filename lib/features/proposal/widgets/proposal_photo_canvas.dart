import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/photo_surface.dart';
import '../../../services/processing/processing_api.dart';
import 'proposal_canvas_geometry.dart';
import 'proposal_overlay_painter.dart';

export 'proposal_canvas_geometry.dart';

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
    this.distractions = const <DetectedDistraction>[],
    this.includedDistractionIds = const <int>{},
    this.onToggleDistraction,
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

  /// Distractions (Phase B): an included distraction takes the
  /// removal treatment; a kept one takes the thin neutral outline
  /// (X7). Emerald is never used here — it is reserved for people.
  final List<DetectedDistraction> distractions;
  final Set<int> includedDistractionIds;
  final void Function(int id)? onToggleDistraction;

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
                    // belongings > ambiguous items > distractions.
                    // A tap toggles the winning item only; each kind
                    // is checked independently of the others.
                    final point = details.localPosition;
                    final personId = personIdAtBandPoint(
                      persons: persons,
                      point: point,
                      imageSize: imageSize!,
                      bandSize: band.size,
                    );
                    if (personId != null) {
                      onTogglePerson(personId);
                      return;
                    }
                    if (onToggleBelonging != null) {
                      final attached = belongings
                          .where((b) => b.tier == BelongingTier.attached)
                          .toList();
                      final attachedId = belongingIdAtBandPoint(
                        items: attached,
                        point: point,
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
                        point: point,
                        imageSize: imageSize!,
                        bandSize: band.size,
                      );
                      if (itemId != null) {
                        onToggleBelonging!(itemId);
                        return;
                      }
                    }
                    if (onToggleDistraction != null) {
                      final distractionId = distractionIdAtBandPoint(
                        distractions: distractions,
                        point: point,
                        imageSize: imageSize!,
                        bandSize: band.size,
                      );
                      if (distractionId != null) {
                        onToggleDistraction!(distractionId);
                      }
                    }
                  },
                  child: CustomPaint(
                    painter: ProposalOverlayPainter(
                      persons: persons,
                      belongings: belongings,
                      detachedIds: detachedIds,
                      includedItemIds: includedItemIds,
                      distractions: distractions,
                      includedDistractionIds: includedDistractionIds,
                      imageSize: imageSize!,
                      palette: p,
                      cornerRadius: s.radiusSm,
                      onTogglePerson: onTogglePerson,
                      onToggleBelonging: onToggleBelonging,
                      onToggleDistraction: onToggleDistraction,
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
