import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';

/// Progress display with exactly the two sanctioned variants
/// (Design Direction §2.2 R3): [LoadingOverlay.determinate] (bar + real %,
/// upload only) and [LoadingOverlay.staged] (stage label + indeterminate
/// bar). No third variant may be invented per-screen.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay.staged({super.key, required this.labelKey})
    : progress = null;

  const LoadingOverlay.determinate({
    super.key,
    required this.labelKey,
    required double this.progress,
  });

  /// Stage label string key, e.g. "Finding people…".
  final String labelKey;

  /// 0.0–1.0 for the determinate variant; null = indeterminate.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final value = progress;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(s.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: value,
                color: p.primary,
                backgroundColor: p.surfaceVariant,
                minHeight: 4,
              ),
            ),
            SizedBox(height: s.lg),
            Text(
              value == null
                  ? labelKey.tr
                  : '${labelKey.tr} ${(value * 100).round()}%',
              style: context.textStyles.bodyMd,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
