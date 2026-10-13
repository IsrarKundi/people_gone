import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';
import 'primary_button.dart';

/// Empty state (Conventions §6.7): one line of text + optional action.
/// No stock illustration (Design Direction §2.3).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.messageKey,
    this.actionLabelKey,
    this.onAction,
    this.icon = Icons.photo_library_outlined,
  });

  final String messageKey;
  final String? actionLabelKey;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(s.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: p.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: s.iconLg, color: p.primary),
            ),
            SizedBox(height: s.md),
            Text(
              messageKey.tr,
              style: context.textStyles.bodyMd.copyWith(color: p.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabelKey != null && onAction != null) ...<Widget>[
              SizedBox(height: s.lg),
              PrimaryButton(labelKey: actionLabelKey!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
