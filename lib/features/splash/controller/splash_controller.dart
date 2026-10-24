import 'dart:async';

import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/routes/app_routes.dart';

/// Controller for Splash screen lifecycle and navigation.
class SplashController extends GetxController {
  SplashController({
    Duration? holdDuration,
    void Function()? onComplete,
  })  : _holdDuration = holdDuration ?? AppMotion.splashHold,
        _onComplete = onComplete;

  final Duration _holdDuration;
  final void Function()? _onComplete;
  Timer? _timer;
  bool _navigated = false;

  @override
  void onInit() {
    super.onInit();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer(_holdDuration, complete);
  }

  /// Cancels the hold timer WITHOUT navigating. Used by the splash view
  /// once the logo animation starts playing, so navigation waits for the
  /// animation instead of the fixed hold; the timer stays as the fallback
  /// when the animation never loads.
  void cancelHoldTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Proceeds immediately to Home (on tap or timer expiry).
  void complete() {
    if (_navigated) return;
    _navigated = true;
    _timer?.cancel();
    final callback = _onComplete;
    if (callback != null) {
      callback();
    } else {
      Get.offNamed<dynamic>(Routes.home);
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
