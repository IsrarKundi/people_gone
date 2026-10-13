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
    this.actions,
  });

  final Widget body;
  final String? titleKey;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: titleKey == null
          ? null
          : AppBar(
              title: Text(titleKey!.tr),
              actions: actions,
            ),
      body: SafeArea(child: body),
    );
  }
}
