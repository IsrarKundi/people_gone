import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_ext.dart';

/// The only scaffold features use (Conventions §6.7): SafeArea + optional
/// standard app bar. Photo screens pass no [titleKey] and build their own
/// full-bleed layout (Design Direction §3).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.titleKey,
    this.titleWidget,
    this.titleStyle,
    this.actions,
  });

  final Widget body;
  final String? titleKey;
  final Widget? titleWidget;

  /// Optional override (e.g. the Home wordmark: Inter 800 — Design
  /// Direction R5 / Review 01). Defaults to the theme's app-bar style.
  final TextStyle? titleStyle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasAppBar = titleKey != null || titleWidget != null;
    return Scaffold(
      backgroundColor: p.background,
      appBar: !hasAppBar
          ? null
          : AppBar(
              centerTitle: false,
              title: titleWidget ?? Text(titleKey!.tr, style: titleStyle),
              actions: actions,
            ),
      body: SafeArea(child: body),
    );
  }
}
