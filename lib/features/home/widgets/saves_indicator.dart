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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: context.textStyles.labelLg),
        SizedBox(height: s.sm),
        Semantics(
          label: label,
          child: LinearProgressIndicator(
            value: of == 0 ? 0 : savesLeft / of,
            color: p.primary,
            backgroundColor: p.surfaceVariant,
          ),
        ),
      ],
    );
  }
}
