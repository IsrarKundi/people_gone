import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The sanctioned bottom-sheet path for the app (like [AppDialog] for
/// dialogs): the framework's modal sheet, themed by the caller-supplied
/// child (which carries its own surface + sheet radius). Features never
/// call showModalBottomSheet/Get.bottomSheet directly.
abstract final class AppSheet {
  static Future<void> show(Widget child) async {
    final context = Get.context;
    if (context == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );
  }
}
