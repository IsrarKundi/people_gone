import 'dart:async';

import 'package:flutter/services.dart';

/// Semantic haptic vocabulary (audit 2026-10-19, feel research): one
/// meaning per pattern, replacing the single `lightImpact` that used to
/// confirm everything from a toggle to a save. Call sites name the
/// MEANING (`AppHaptics.selection()`), never the raw feedback — the
/// physical pattern can be re-tuned here in one place.
///
/// - [selection] — a choice flipped (S4 person/item toggles).
/// - [confirm] — a committed action (Confirm proposal, Keep all).
/// - [success] — the save landed (double pulse; the screen's peak).
/// - [error] — an action failed and was not charged.
/// - [warning] — a caution surfaced (the reflection warning line).
/// - [boundary] — a drag reached its end (compare slider edges).
abstract final class AppHaptics {
  static void selection() {
    unawaited(HapticFeedback.selectionClick());
  }

  static void confirm() {
    unawaited(HapticFeedback.mediumImpact());
  }

  static void success() {
    unawaited(_success());
  }

  static Future<void> _success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  static void error() {
    unawaited(_error());
  }

  static Future<void> _error() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.heavyImpact();
  }

  static void warning() {
    unawaited(HapticFeedback.lightImpact());
  }

  static void boundary() {
    unawaited(HapticFeedback.selectionClick());
  }
}
