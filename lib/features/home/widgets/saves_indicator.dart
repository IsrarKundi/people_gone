import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';

/// Quiet quota pill beneath the primary action (Home Option A).
/// Replaces the loud administrative progress bar with a discreet,
/// calm status pill showing the real saves left and reset date.
class SavesIndicator extends StatelessWidget {
  const SavesIndicator({
    super.key,
    required this.savesLeft,
    required this.of,
    this.resetDate,
  });

  final int savesLeft;
  final int of;
  final DateTime? resetDate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final label = resetDate != null
        ? '$savesLeft of $of free saves left · Resets ${Formatters.dayMonth(resetDate!)}'
        : AppStrings.homeSavesLeft.trParams(<String, String>{
            'count': '$savesLeft',
          });

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs + 2),
        decoration: BoxDecoration(
          color: p.surfaceVariant,
          borderRadius: BorderRadius.circular(s.radiusPill),
          border: Border.all(color: p.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: savesLeft > 0 ? p.primary : p.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: s.sm),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
