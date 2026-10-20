// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../theme/theme_ext.dart';

/// The only snackbar path (Conventions §6.7 / §7 rule 7) — for completed
/// background facts ("Saved to your photos"), never for errors that need a
/// decision (those are full states).
abstract final class AppSnackbar {
  static void success(String messageKey) => _show(messageKey, isError: false);

  static void info(String messageKey) => _show(messageKey, isError: false);

  static void error(String messageKey) => _show(messageKey, isError: true);

  static void _show(String messageKey, {required bool isError}) {
    // Snackbars commented out per user request.
    // final context = Get.context;
    // if (context == null) return;
    // final p = context.palette;
    // final s = context.sizes;
    // Get.snackbar(
    //   '',
    //   messageKey.tr,
    //   titleText: const SizedBox.shrink(),
    //   backgroundColor: isError ? p.errorBg : p.surfaceVariant,
    //   colorText: p.textPrimary,
    //   borderRadius: s.radiusMd,
    //   margin: EdgeInsets.all(s.screenPadding),
    //   snackPosition: SnackPosition.BOTTOM,
    //   duration: const Duration(seconds: 3),
    // );
  }
}
