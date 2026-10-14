import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/diagnostics/diagnostics_log.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';

/// Diagnostics (2026-10-14): shows the in-memory step log and lets the
/// user share or clear it. Exists so a failure on a real device can be
/// reported with evidence instead of a generic error message. The log
/// holds no photos, passwords, or sign-in details (see
/// DiagnosticsLog's privacy contract).
class DiagnosticsView extends StatefulWidget {
  const DiagnosticsView({super.key});

  @override
  State<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends State<DiagnosticsView> {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final log = DiagnosticsLog.instance;
    final hasEntries = log.length > 0;
    return AppScaffold(
      titleKey: AppStrings.diagnosticsTitle,
      body: Padding(
        padding: EdgeInsets.all(s.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              AppStrings.diagnosticsIntro.tr,
              style: context.textStyles.bodySm.copyWith(
                color: p.textSecondary,
              ),
            ),
            SizedBox(height: s.md),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(s.radiusMd),
                  border: Border.all(color: p.border),
                ),
                padding: EdgeInsets.all(s.md),
                child: SingleChildScrollView(
                  child: SelectableText(
                    hasEntries
                        ? log.export()
                        : AppStrings.diagnosticsEmpty.tr,
                    style: context.textStyles.caption.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: s.md),
            PrimaryButton(
              labelKey: AppStrings.diagnosticsShare,
              onPressed: hasEntries
                  ? () => Share.share(log.export())
                  : null,
            ),
            TextButton(
              onPressed: hasEntries
                  ? () => setState(log.clear)
                  : null,
              child: Text(AppStrings.diagnosticsClear.tr),
            ),
          ],
        ),
      ),
    );
  }
}
