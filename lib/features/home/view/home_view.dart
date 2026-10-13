import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../controller/home_controller.dart';

/// Home (S1) — Phase 1 Task 1.1 design-token placeholder: wordmark, saves
/// line, and the empty-state line. It deliberately has NO buttons yet —
/// placeholder screens never carry dead actions (Conventions §13); the
/// picker button arrives wired in Task 1.2.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    return AppScaffold(
      titleKey: AppStrings.homeTitle,
      body: Padding(
        padding: EdgeInsets.all(s.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppStrings.appName.tr,
              style: context.textStyles.titleLg.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: s.sm),
            Text(
              AppStrings.homeSavesLeft.trParams(<String, String>{'count': '10'}),
              style: context.textStyles.bodySm.copyWith(
                color: p.textSecondary,
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                AppStrings.homeEmptyLine.tr,
                style: context.textStyles.bodyMd.copyWith(
                  color: p.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
