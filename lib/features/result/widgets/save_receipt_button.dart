import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/result_controller.dart';

/// The save button on Result (S7): shows loading while saving, then
/// turns immediately into the disabled grey "Saved" state upon success.
class SaveReceiptButton extends StatelessWidget {
  const SaveReceiptButton({super.key, required this.controller});
  final ResultController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final savedNow = controller.saved.value;
      return PrimaryButton(
        labelKey: savedNow ? AppStrings.resultSaved : AppStrings.resultSave,
        isLoading: controller.isSaving.value,
        onPressed: savedNow ? null : controller.save,
      );
    });
  }
}
