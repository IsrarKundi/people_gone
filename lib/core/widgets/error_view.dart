import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';
import 'primary_button.dart';

/// Full-state error (Conventions §6.7): icon + message (by string key) +
/// one recovery action. Errors that need a decision are full states like
/// this, never snackbars (Design Direction §3).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.messageKey,
    this.onRetry,
    this.actionLabelKey = AppStrings.commonRetry,
  });

  final String messageKey;
  final VoidCallback? onRetry;

  /// Label for the single recovery action (§4.3: Retry / Pick another
  /// photo / Go Home — the label names the actual recovery).
  final String actionLabelKey;

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
            Icon(Icons.error_outline, size: s.iconLg, color: p.error),
            SizedBox(height: s.md),
            Text(
              messageKey.tr,
              style: context.textStyles.bodyMd,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              SizedBox(height: s.lg),
              PrimaryButton(labelKey: actionLabelKey, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
