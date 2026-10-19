import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/result_controller.dart';

/// The save button on Result (S7): turns into a green receipt state on save.
class SaveReceiptButton extends StatefulWidget {
  const SaveReceiptButton({super.key, required this.controller});
  final ResultController controller;

  @override
  State<SaveReceiptButton> createState() => _SaveReceiptButtonState();
}

class _SaveReceiptButtonState extends State<SaveReceiptButton> {
  bool _holdingReceipt = false;
  Timer? _timer;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever<bool>(widget.controller.saved, (saved) {
      if (!mounted) return;
      if (saved) {
        final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (disable) {
          setState(() => _holdingReceipt = false);
        } else {
          setState(() => _holdingReceipt = true);
          _timer?.cancel();
          _timer = Timer(AppMotion.saveHold, () {
            if (mounted) setState(() => _holdingReceipt = false);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final savedNow = widget.controller.saved.value;
      return PrimaryButton(
        labelKey: savedNow ? AppStrings.resultSaved : AppStrings.resultSave,
        icon: savedNow ? AppIcons.checkFill : null,
        isSuccess: savedNow && _holdingReceipt,
        isLoading: widget.controller.isSaving.value,
        onPressed: savedNow ? null : widget.controller.save,
      );
    });
  }
}
