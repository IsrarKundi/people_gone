import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/history_detail_controller.dart';

/// The save button on History Detail: shows loading while saving, then
/// turns immediately into the disabled grey "Saved" state upon success.
class HistorySaveReceiptButton extends StatelessWidget {
  const HistorySaveReceiptButton({super.key, required this.controller});
  final HistoryDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final savedNow = controller.saved.value;
      return PrimaryButton(
        labelKey: savedNow ? AppStrings.resultSaved : AppStrings.resultSave,
        isLoading: controller.isSaving.value,
        onPressed: savedNow ? null : controller.saveToGallery,
      );
    });
  }
}
