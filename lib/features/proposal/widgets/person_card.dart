import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/person_thumbnail.dart';
import '../../../services/processing/processing_api.dart';

/// Interactive person card displayed in the proposal tray.
/// Tapping toggles keep vs remove status.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    required this.imagePath,
    required this.onTap,
  });

  final DetectedPerson person;
  final String imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final isKeeper = person.isKeeper;
    final activeColor = isKeeper ? AppColors.emerald : AppColors.crimson;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(s.radiusLg),
      child: Container(
        width: 104,
        padding: EdgeInsets.symmetric(vertical: s.sm, horizontal: s.xs),
        decoration: BoxDecoration(
          color: isKeeper ? AppColors.emerald.withAlpha(20) : p.surfaceVariant.withAlpha(50),
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
              'Person ${person.id + 1}',
              style: context.textStyles.labelMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withAlpha(30),
                borderRadius: BorderRadius.circular(s.radiusPill),
              ),
              child: Text(
                isKeeper
                    ? AppStrings.proposalSubjectKept.tr
                    : AppStrings.proposalPersonToRemove.tr,
                style: context.textStyles.caption.copyWith(
                  color: activeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
