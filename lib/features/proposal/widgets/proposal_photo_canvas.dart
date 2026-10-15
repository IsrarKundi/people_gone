import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_motion.dart';
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
class ProposalPhotoCanvas extends StatefulWidget {
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
  State<ProposalPhotoCanvas> createState() => _ProposalPhotoCanvasState();
}

class _ProposalPhotoCanvasState extends State<ProposalPhotoCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _colorController;
  final Map<int, double> _startFractions = <int, double>{};
  final Map<int, double> _targetFractions = <int, double>{};

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );
    for (final person in widget.persons) {
      final f = person.isKeeper ? 1.0 : 0.0;
      _startFractions[person.id] = f;
      _targetFractions[person.id] = f;
    }
  }

  @override
  void didUpdateWidget(ProposalPhotoCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    var changed = false;
    final currentT = _colorController.value;
    for (final person in widget.persons) {
      final target = person.isKeeper ? 1.0 : 0.0;
      final prevStart = _startFractions[person.id] ?? target;
      final prevTarget = _targetFractions[person.id] ?? target;
      final currentFraction = prevStart + (prevTarget - prevStart) * currentT;
      if (prevTarget != target) {
        _startFractions[person.id] = currentFraction;
        _targetFractions[person.id] = target;
        changed = true;
      }
    }
    if (changed) {
      final disable =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disable) {
        _colorController.value = 1.0;
      } else {
        _colorController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  Map<int, double> _currentFractions() {
    final t = _colorController.value;
    final map = <int, double>{};
    for (final person in widget.persons) {
      final s =
          _startFractions[person.id] ?? (person.isKeeper ? 1.0 : 0.0);
      final end =
          _targetFractions[person.id] ?? (person.isKeeper ? 1.0 : 0.0);
      map[person.id] = s + (end - s) * t;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final file = File(widget.photoPath);

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
            if (widget.imageSize != null && band.width > 0 && band.height > 0)
              Positioned(
                left: band.left,
                top: band.top,
                width: band.width,
                height: band.height,
                child: TweenAnimationBuilder<double>(
                  duration:
                      MediaQuery.maybeOf(context)?.disableAnimations ?? false
                          ? Duration.zero
                          : AppMotion.standard,
                  curve: AppMotion.enterCurve,
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: child,
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      // Tap priority (X7): people > attached
                      // belongings > ambiguous items > distractions.
                      // A tap toggles the winning item only; each kind
                      // is checked independently of the others.
                      final point = details.localPosition;
                      final personId = personIdAtBandPoint(
                        persons: widget.persons,
                        point: point,
                        imageSize: widget.imageSize!,
                        bandSize: band.size,
                      );
                      if (personId != null) {
                        widget.onTogglePerson(personId);
                        return;
                      }
                      if (widget.onToggleBelonging != null) {
                        final attached = widget.belongings
                            .where((b) => b.tier == BelongingTier.attached)
                            .toList();
                        final attachedId = belongingIdAtBandPoint(
                          items: attached,
                          point: point,
                          imageSize: widget.imageSize!,
                          bandSize: band.size,
                        );
                        if (attachedId != null) {
                          widget.onToggleBelonging!(attachedId);
                          return;
                        }
                        final ambiguous = widget.belongings
                            .where((b) => b.tier == BelongingTier.ambiguous)
                            .toList();
                        final itemId = belongingIdAtBandPoint(
                          items: ambiguous,
                          point: point,
                          imageSize: widget.imageSize!,
                          bandSize: band.size,
                        );
                        if (itemId != null) {
                          widget.onToggleBelonging!(itemId);
                          return;
                        }
                      }
                      if (widget.onToggleDistraction != null) {
                        final distractionId = distractionIdAtBandPoint(
                          distractions: widget.distractions,
                          point: point,
                          imageSize: widget.imageSize!,
                          bandSize: band.size,
                        );
                        if (distractionId != null) {
                          widget.onToggleDistraction!(distractionId);
                        }
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _colorController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: ProposalOverlayPainter(
                            persons: widget.persons,
                            belongings: widget.belongings,
                            detachedIds: widget.detachedIds,
                            includedItemIds: widget.includedItemIds,
                            distractions: widget.distractions,
                            includedDistractionIds: widget.includedDistractionIds,
                            imageSize: widget.imageSize!,
                            palette: p,
                            cornerRadius: s.radiusSm,
                            onTogglePerson: widget.onTogglePerson,
                            onToggleBelonging: widget.onToggleBelonging,
                            onToggleDistraction: widget.onToggleDistraction,
                            keeperFractions: _currentFractions(),
                          ),
                        );
                      },
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
