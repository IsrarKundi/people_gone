import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../services/processing/processing_api.dart';

import '../model/distraction_label.dart';
import 'item_card.dart';

/// Object chip for a distraction in the Distractions group (Phase B,
/// design X2/X3): mirrors the item chip — a real crop of the object
/// from the photo, its category label, and a Remove/Keep state pill.
/// Default state is Keep (X3); tapping flips it. State lives in the
/// card border and the pill; emerald stays reserved for protected
/// people (X7).
class DistractionCard extends StatelessWidget {
  const DistractionCard({
    super.key,
    required this.distraction,
    required this.imagePath,
    required this.included,
    required this.onTap,
  });

  final DetectedDistraction distraction;
  final String imagePath;
  final bool included;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final name = distractionCategoryLabelKey(distraction.category).tr;

    return Semantics(
      label: included
          ? AppStrings.proposalItemMarkedRemove.trParams(<String, String>{
              'name': name,
            })
          : AppStrings.proposalItemKeptSemantics.trParams(<String, String>{
              'name': name,
            }),
      button: true,
      child: PressableScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(s.radiusLg),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standardCurve,
            width: 104,
            padding: EdgeInsets.symmetric(vertical: s.sm, horizontal: s.xs),
            decoration: BoxDecoration(
              color: included
                  ? AppColors.crimson.withAlpha(16)
                  : p.surfaceVariant.withAlpha(50),
              borderRadius: BorderRadius.circular(s.radiusLg),
              border: Border.all(
                color: included ? AppColors.crimson.withAlpha(120) : p.border,
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ItemThumbnail(
                  imagePath: imagePath,
                  box: distraction.box,
                  size: 44,
                ),
                SizedBox(height: s.xs),
                Text(
                  name,
                  style: context.textStyles.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                AnimatedContainer(
                  duration:
                      MediaQuery.maybeOf(context)?.disableAnimations ?? false
                          ? Duration.zero
                          : AppMotion.fast,
                  curve: AppMotion.standardCurve,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: included
                        ? AppColors.crimson.withAlpha(30)
                        : p.surfaceVariant,
                    borderRadius: BorderRadius.circular(s.radiusPill),
                  ),
                  child: Text(
                    included
                        ? AppStrings.proposalItemRemove.tr
                        : AppStrings.proposalItemKeep.tr,
                    style: context.textStyles.caption.copyWith(
                      color: included ? AppColors.crimson : p.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

