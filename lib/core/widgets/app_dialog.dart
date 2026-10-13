import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';

/// The only dialog shell (Conventions §6.7). Feature code never calls
/// `Get.dialog` ad hoc (§7 rule 7).
abstract final class AppDialog {
  /// Confirmation dialog; resolves true when the user confirms.
  static Future<bool> confirm({
    required String titleKey,
    required String bodyKey,
    required String confirmLabelKey,
    required String cancelLabelKey,
    bool destructive = false,
  }) async {
    final context = Get.context;
    if (context == null) return false;
    final p = context.palette;
    final s = context.sizes;
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.radiusLg),
        ),
        title: Text(titleKey.tr, style: context.textStyles.titleLg),
        content: Text(bodyKey.tr, style: context.textStyles.bodyMd),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text(cancelLabelKey.tr),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? p.error : p.primary,
            ),
            child: Text(confirmLabelKey.tr),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
