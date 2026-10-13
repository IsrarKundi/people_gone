import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../controller/history_detail_controller.dart';

/// A saved clean at full quality, with its saved date, Share, and
/// Delete. (Sharing reuses the result file; nothing is re-processed.)
class HistoryDetailView extends GetView<HistoryDetailController> {
  const HistoryDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final entry = controller.entry;
    return AppScaffold(
      titleKey: AppStrings.historyTitle,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Image.file(
              File(entry.localPath),
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
                  Formatters.date(entry.savedAt),
                  style: context.textStyles.bodyMd,
                ),
                SizedBox(height: s.lg),
                SecondaryButton(
                  labelKey: AppStrings.resultShare,
                  onPressed: controller.share,
                ),
                SizedBox(height: s.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: controller.delete,
                    child: Text(
                      AppStrings.commonDelete.tr,
                      style: context.textStyles.labelLg.copyWith(
                        color: p.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
