import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/person_thumbnail.dart';
import '../../../core/widgets/pressable_scale.dart';

import '../../../services/processing/processing_api.dart';
import '../model/belonging_label.dart';

/// Interactive person card displayed in the proposal tray.
/// Tapping toggles keep vs remove status.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    required this.imagePath,
    required this.onTap,
    this.belongings = const <DetectedBelonging>[],
    this.detachedIds = const <int>{},
    this.onToggleDetach,
  });

  final DetectedPerson person;
  final String imagePath;
  final VoidCallback onTap;

  /// This person's attached belongings (Phase A, X9): named on the
  /// "Includes:" line, each name tappable to detach/re-attach it.
  final List<DetectedBelonging> belongings;
  final Set<int> detachedIds;
  final void Function(int itemId)? onToggleDetach;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final isKeeper = person.isKeeper;
    final activeColor = isKeeper ? p.success : p.error;

    return PressableScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(s.radiusLg),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standardCurve,
          width: 104,
          padding: EdgeInsets.symmetric(vertical: s.sm, horizontal: s.xs),
          decoration: BoxDecoration(
            color: isKeeper ? p.success.withAlpha(20) : p.surfaceVariant.withAlpha(50),
            borderRadius: BorderRadius.circular(s.radiusLg),
            border: Border.all(
              color: activeColor.withAlpha(isKeeper ? 180 : 80),
              width: isKeeper ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[

            PersonThumbnail(
              imagePath: imagePath,
              box: person.box,
              isKeeper: isKeeper,
              size: 44,
            ),
            SizedBox(height: s.xs),
            Text(
              AppStrings.proposalPersonLabel.trParams(<String, String>{
                'n': '${person.id + 1}',
              }),
              style: context.textStyles.labelMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            AnimatedContainer(
              duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                  ? Duration.zero
                  : AppMotion.fast,
              curve: AppMotion.standardCurve,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withAlpha(30),
                borderRadius: BorderRadius.circular(s.radiusPill),
              ),
              child: Text(
                isKeeper
                    ? AppStrings.proposalSubjectKept.tr
                    : AppStrings.proposalPersonToRemove.tr,
                // One line, always: the pill must never grow the
                // card's height by wrapping (fixed-height tray).
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: activeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (belongings.isNotEmpty) ...<Widget>[
              SizedBox(height: s.xs),
              _includesLine(context),
            ],
          ],
        ),
      ),
    ),
    );
  }


  /// The "Includes:" line (X9): one flowing row — the caption plus
  /// each attached belonging's name as a small tappable chip that
  /// detaches (protects) the item or re-attaches it. A detached name
  /// reads struck-through and secondary — it no longer travels with
  /// the person.
  Widget _includesLine(BuildContext context) {
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: <Widget>[
        Text(
          AppStrings.proposalIncludesLead.tr,
          style: context.textStyles.caption.copyWith(
            color: p.textSecondary,
            fontSize: 10,
          ),
        ),
        for (final item in belongings) _nameChip(context, item),
      ],
    );
  }

  Widget _nameChip(BuildContext context, DetectedBelonging item) {
    final p = context.palette;
    final s = context.sizes;
    final detached = detachedIds.contains(item.id);
    final name = belongingClassLabelKey(item.detectedClass).tr;
    return Semantics(
      button: true,
      label: detached
          ? AppStrings.proposalBelongingReattach.trParams(<String, String>{
              'name': name,
            })
          : AppStrings.proposalBelongingDetach.trParams(<String, String>{
              'name': name,
            }),
      child: InkWell(
        onTap: onToggleDetach == null
            ? null
            : () => onToggleDetach!(item.id),
        borderRadius: BorderRadius.circular(s.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            name,
            style: context.textStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: detached ? p.textSecondary : p.textPrimary,
              decoration: detached ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}
