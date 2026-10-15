import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Wraps a button, card, or chip with a subtle 0.98 scale-down on press
/// and a calm spring-back on release (ANIMATION_RESEARCH_2026.md §3, #2).
///
/// Purely transform-only, 180 ms fast token.
/// Under reduced motion (`MediaQuery.disableAnimations`), scale remains 1.0.
/// Uses [Listener] to avoid blocking or interfering with child gesture recognizers.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.targetScale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final double targetScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pressed) setState(() => _pressed = false);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scale = (widget.enabled && _pressed && !disable)
        ? widget.targetScale
        : 1.0;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: scale,
        duration: disable ? Duration.zero : AppMotion.fast,
        curve: AppMotion.spring,
        child: widget.child,
      ),
    );
  }
}
