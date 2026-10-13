import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';

/// Section title + optional trailing text action (Conventions §6.7).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.titleKey,
    this.actionLabelKey,
    this.onAction,
  });

  final String titleKey;
  final String? actionLabelKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(titleKey.tr, style: context.textStyles.titleMd),
        ),
        if (actionLabelKey != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabelKey!.tr,
              style: context.textStyles.labelMd.copyWith(color: p.secondary),
            ),
          ),
      ],
    );
  }
}
