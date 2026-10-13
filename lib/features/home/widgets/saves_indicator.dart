import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';

/// The Home saves indicator (Design Direction §4 S1): the plain count
/// line plus its thin bar — the pair together are the free tier's one
/// persistent piece of chrome.
class SavesIndicator extends StatelessWidget {
  const SavesIndicator({super.key, required this.savesLeft, required this.of});

  final int savesLeft;
  final int of;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final label = AppStrings.homeSavesLeft.trParams(<String, String>{
      'count': '$savesLeft',
    });
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm + 2),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(s.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                label,
                style: context.textStyles.labelLg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.shield_outlined,
                size: s.iconSm,
                color: p.textTertiary,
              ),
            ],
          ),
          SizedBox(height: s.xs + 2),
          Semantics(
            label: label,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(s.radiusSm),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: of == 0 ? 0 : savesLeft / of,
                color: p.primary,
                backgroundColor: p.surfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

