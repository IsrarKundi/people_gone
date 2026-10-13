import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../controller/result_controller.dart';

/// Result (S7) — minimal real form for this milestone: the cleaned photo
/// full-bleed with the job summary and a way back. Compare, save, share
/// and keeper correction complete the screen in the next step.
class ResultView extends GetView<ResultController> {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final outcome = controller.outcome;
    return AppScaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            child: Image.file(
              File(
                controller.nobodyRemoved
                    ? outcome.originalPath
                    : outcome.resultPath,
              ),
              fit: BoxFit.contain,
              cacheWidth: MediaQuery.sizeOf(context).width.toInt(),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(s.screenPadding),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  controller.nobodyRemoved
                      ? AppStrings.errorNoPeople.tr
                      : AppStrings.resultSummary.trParams(<String, String>{
                          'removed': '${controller.removedCount}',
                          'total': '${controller.totalCount}',
                        }),
                  style: context.textStyles.bodyMd,
                ),
                SizedBox(height: s.lg),
                PrimaryButton(
                  labelKey: AppStrings.resultPickAnother,
                  onPressed: () => Get.offAllNamed<void>(Routes.home),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
