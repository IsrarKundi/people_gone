import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_view.dart';
import '../controller/history_controller.dart';
import '../widgets/history_grid.dart';

/// History screen: the on-device line, then the grid of saved cleans
/// (FR-19). Nothing here is ever uploaded or backed up off-device.
class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    return AppScaffold(
      titleKey: AppStrings.historyTitle,
      body: Obx(() {
        if (controller.entries.isEmpty) {
          return const EmptyView(
            messageKey: AppStrings.historyEmptyLine,
            icon: AppIcons.photoLibrary,
          );
        }
        return Padding(
          padding: EdgeInsets.all(s.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Text(
              //   AppStrings.historyOnDeviceLine.tr,
              //   style: context.textStyles.bodySm.copyWith(
              //     color: p.textSecondary,
              //   ),
              // ),
              // SizedBox(height: s.md),
              Expanded(
                child: HistoryGrid(
                  entries: controller.entries,
                  crossAxisCount: 2,
                  deletingId: controller.deletingId.value,
                  onTap: controller.openDetail,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
