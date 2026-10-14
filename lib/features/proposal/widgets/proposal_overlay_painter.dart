import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../services/processing/processing_api.dart';
import '../model/belonging_label.dart';
import '../model/distraction_label.dart';
import 'proposal_canvas_geometry.dart';

/// Paints the S4 canvas overlays (people, belongings, distractions)
/// and provides their TalkBack semantics (direction R2). Split out
/// of proposal_photo_canvas.dart to keep files under the ~400-line
/// convention cap.
class ProposalOverlayPainter extends CustomPainter {
  const ProposalOverlayPainter({
    required this.persons,
    required this.belongings,
    required this.detachedIds,
    required this.includedItemIds,
    required this.distractions,
    required this.includedDistractionIds,
    required this.imageSize,
    required this.palette,
    required this.cornerRadius,
    required this.onTogglePerson,
    required this.onToggleBelonging,
    required this.onToggleDistraction,
  });

  final List<DetectedPerson> persons;
  final List<DetectedBelonging> belongings;
  final Set<int> detachedIds;
  final Set<int> includedItemIds;
  final List<DetectedDistraction> distractions;
  final Set<int> includedDistractionIds;
  final Size imageSize;
  final AppPalette palette;
  final double cornerRadius;
  final void Function(int id) onTogglePerson;
  final void Function(int id)? onToggleBelonging;
  final void Function(int id)? onToggleDistraction;

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

    // Distractions (X7): included = the removal treatment (same
    // token/fill as a removal person); kept = the thin neutral
    // outline only. Painted after belongings so the lowest-priority
    // layer reads last; hit priority is the reverse (see onTapUp).
    for (final distraction in distractions) {
      final rect = scalePersonBoxToBand(
        box: distraction.box,
        imageSize: imageSize,
        bandSize: size,
      );
      if (rect.isEmpty) continue;
      final rounded = RRect.fromRectAndRadius(
        rect,
        Radius.circular(cornerRadius),
      );
      if (includedDistractionIds.contains(distraction.id)) {
        final token = palette.overlayRemoved;
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
        if (onToggleDistraction != null)
          for (final distraction in distractions)
            CustomPainterSemantics(
              rect: scalePersonBoxToBand(
                box: distraction.box,
                imageSize: imageSize,
                bandSize: size,
              ),
              properties: SemanticsProperties(
                textDirection: TextDirection.ltr,
                label: _distractionSemanticsLabel(distraction),
                button: true,
                onTap: () => onToggleDistraction!(distraction.id),
              ),
            ),
      ];
    };
  }

  String _distractionSemanticsLabel(DetectedDistraction distraction) {
    final name = distractionCategoryLabelKey(distraction.category).tr;
    final params = <String, String>{'name': name};
    return includedDistractionIds.contains(distraction.id)
        ? AppStrings.proposalItemMarkedRemove.trParams(params)
        : AppStrings.proposalItemKeptSemantics.trParams(params);
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
  bool shouldRepaint(covariant ProposalOverlayPainter oldDelegate) =>
      oldDelegate.persons != persons ||
      oldDelegate.belongings != belongings ||
      oldDelegate.detachedIds != detachedIds ||
      oldDelegate.includedItemIds != includedItemIds ||
      oldDelegate.distractions != distractions ||
      oldDelegate.includedDistractionIds != includedDistractionIds ||
      oldDelegate.imageSize != imageSize;
}
