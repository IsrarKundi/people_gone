import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';

/// The free-saves fact presented as a surface pill that opens the paywall
/// (G3.1), with a thin progress bar of remaining saves and an upgrade chevron.
class SavesIndicator extends StatelessWidget {
  const SavesIndicator({
    super.key,
    required this.savesLeft,
    required this.of,
    this.resetDate,
    this.onTap,
  });

  final int savesLeft;
  final int of;
  final DateTime? resetDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final label = resetDate != null
        ? AppStrings.homeSavesLeftResets.trParams(<String, String>{
            'count': '$savesLeft',
            'of': '$of',
            'date': Formatters.dayMonth(resetDate!),
          })
        : AppStrings.homeSavesLeft.trParams(<String, String>{
            'count': '$savesLeft',
          });

    final fraction = of > 0 ? (savesLeft / of).clamp(0.0, 1.0) : 1.0;

    final pillContent = Container(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusPill),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: s.sm),
          SizedBox(
            width: 44,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: p.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  savesLeft > 0 ? p.primary : p.error,
                ),
              ),
            ),
          ),
          SizedBox(width: s.xs),
          Icon(
            AppIcons.caretRight,
            size: 13,
            color: p.textSecondary,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: pillContent,
      );
    }
    return pillContent;
  }
}
