import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';

/// The free-saves fact as a plain text line in the Home column
/// (Review 05 Supplement R4): no pill container and no status dot —
/// the dot mimicked a live status and there is no status; the fact
/// stays, with its reset date, in the column's own alignment.
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
    final label = resetDate != null
        ? '$savesLeft of $of free saves left · Resets ${Formatters.dayMonth(resetDate!)}'
        : AppStrings.homeSavesLeft.trParams(<String, String>{
            'count': '$savesLeft',
          });

    return Text(
      label,
      style: context.textStyles.caption.copyWith(
        color: p.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
