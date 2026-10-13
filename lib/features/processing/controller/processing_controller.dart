import 'dart:async';

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../services/processing/processing_api.dart';
import '../../../services/storage/local_store.dart';
import '../model/processing_args.dart';

enum ProcessingStage { uploading, working }

/// Processing (S3/S6): uploads the picked photo to our server and waits
/// for the clean. Progress is honest (Design Direction §1.5/§6): the
/// upload percentage is real bytes; the server stage is indeterminate
/// with a live elapsed time — never a fake percentage.
class ProcessingController extends GetxController {
  ProcessingController({required this.processingApi, required this.localStore});

  final ProcessingApi processingApi;
  final LocalStore localStore;

  late final ProcessingArgs args;

  final stage = ProcessingStage.uploading.obs;
  final uploadFraction = 0.0.obs;
  final elapsed = Duration.zero.obs;
  final errorMessage = RxnString();
  final isRunning = false.obs;

  Timer? _timer;
  bool _left = false;

  String get photoPath => args.photoPath;

  @override
  void onInit() {
    super.onInit();
    args = Get.arguments as ProcessingArgs;
    unawaited(start());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> start() async {
    if (isRunning.value) return;
    isRunning.value = true;
    errorMessage.value = null;
    stage.value = ProcessingStage.uploading;
    uploadFraction.value = 0;
    elapsed.value = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed.value += const Duration(seconds: 1);
    });

    final result = await processingApi.processPhoto(
      localPath: args.photoPath,
      keepIds: args.keepIds,
      onUploadProgress: (fraction) {
        uploadFraction.value = fraction;
        if (fraction >= 1.0) stage.value = ProcessingStage.working;
      },
    );
    _timer?.cancel();
    isRunning.value = false;

    switch (result) {
      case Success<ProcessedPhoto>(:final value):
        await _deliver(value);
      case Failure<ProcessedPhoto>(:final failure):
        if (failure.code == 'cancelled') {
          _goHome();
        } else {
          errorMessage.value = failure.userMessageKey;
        }
    }
  }

  Future<void> _deliver(ProcessedPhoto photo) async {
    final written = await localStore.writeSessionResult(photo.resultBytes);
    switch (written) {
      case Success<String>(:final value):
        if (_left) return;
        Get.offNamed<void>(
          Routes.result,
          arguments: ProcessingOutcome(
            originalPath: args.photoPath,
            resultPath: value,
            personsDetected: photo.personsDetected,
            keeperIds: photo.keeperIds,
            removedIds: photo.removedIds,
            totalSeconds: photo.totalSeconds,
            engineUsed: photo.engineUsed,
            persons: photo.persons,
          ),
        );
      case Failure<String>():
        errorMessage.value = AppStrings.errorGeneric;
    }
  }

  /// Cancel (S6): the confirm dialog states the no-charge guarantee;
  /// cancelling consumes nothing (FR-07).
  Future<void> cancel() async {
    if (!isRunning.value) {
      _goHome();
      return;
    }
    final confirmed = await AppDialog.confirm(
      titleKey: AppStrings.processingCancelTitle,
      bodyKey: AppStrings.processingCancelBody,
      confirmLabelKey: AppStrings.processingCancelConfirm,
      cancelLabelKey: AppStrings.commonCancel,
    );
    if (confirmed) processingApi.cancelOngoing();
  }

  void _goHome() {
    if (_left) return;
    _left = true;
    Get.offAllNamed<void>(Routes.home);
  }
}
