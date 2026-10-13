import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';

/// The S7 disclosure line (§11.2B, verbatim) with "Report this result"
/// as its tappable segment (FR-23).
///
/// StatefulWidget only because a [TapGestureRecognizer] must be owned
/// and disposed (framework requirement, Conventions §7 rule 1).
class DisclosureLine extends StatefulWidget {
  const DisclosureLine({super.key, required this.onReport});

  final VoidCallback onReport;

  @override
  State<DisclosureLine> createState() => _DisclosureLineState();
}

class _DisclosureLineState extends State<DisclosureLine> {
  late final TapGestureRecognizer _reportTap;

  @override
  void initState() {
    super.initState();
    _reportTap = TapGestureRecognizer()..onTap = widget.onReport;
  }

  @override
  void dispose() {
    _reportTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = context.textStyles.bodySm.copyWith(color: p.textSecondary);
    return Text.rich(
      TextSpan(
        style: base,
        children: <TextSpan>[
          TextSpan(text: AppStrings.resultDisclosure.tr),
          const TextSpan(text: ' · '),
          TextSpan(
            text: AppStrings.resultReport.tr,
            style: base.copyWith(
              color: p.secondary,
              decoration: TextDecoration.underline,
            ),
            recognizer: _reportTap,
          ),
        ],
      ),
    );
  }
}
